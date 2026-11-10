# Soulbound Release Manifest & Archive Verification Library (PowerShell)
# SBL-BLD-005: archive-contained JSON provenance manifests (schema version 1).
#
# This file is a library: dot-source it from export/validate/test scripts.
# It defines functions only and performs no work when loaded.
#
# Manifest model (per approved plan, report/codex_next_plan_extract.md "Batch 3"):
#   - Every release ZIP contains exactly one root `release-manifest.json`.
#   - An external companion `<archive>.manifest.sha256` records the lowercase
#     SHA-256 of the exact archived manifest bytes (integrity reference, not a
#     digital signature).
#   - Payload lists every regular ZIP entry except the manifest itself,
#     sorted by ordinal normalized path, with raw-byte size and lowercase
#     SHA-256 over uncompressed bytes.
#   - Configuration snapshots (effective tier-mutated project.godot and the
#     actual export_presets.cfg) are carried inside the archive under
#     provenance/ so validation never trusts local builds/ or local
#     configuration as archive evidence.
#
# Requirements: GDD-093, GDD-095, GDD-107, GDD-108, GDD-109, GDD-110,
# GDD-124, GDD-129, GDD-131, FR-REL-001, TC-REL-001,
# NFR-BUILD-001, NFR-SEC-001, NFR-MAINT-001.

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

$script:SblManifestEntryName = "release-manifest.json"
$script:SblManifestSchemaVersion = 1
$script:SblRequiredGodotVersionPrefix = "4.7.2.stable"
$script:SblProjectSnapshotPath = "provenance/project.godot"
$script:SblPresetsSnapshotPath = "provenance/export_presets.cfg"
$script:SblCompatibleRenderer = "gl_compatibility"
$script:SblUtf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$script:SblUtf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---------------------------------------------------------------------------
# Hashing helpers
# ---------------------------------------------------------------------------

function Get-SblSha256LowerFromBytes {
    # [AllowEmptyCollection] is required: a clean Git status hashes the UTF-8
    # bytes of an empty string, and SHA-256 of empty input is well-defined.
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Bytes)
    } finally {
        $sha.Dispose()
    }
    return ([System.BitConverter]::ToString($hash) -replace "-", "").ToLowerInvariant()
}

function Get-SblSha256LowerFromFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    } catch {
        # Destination paths beyond MAX_PATH (deep seeded shader-cache hash
        # directories inside a disposable user-data root) cannot be opened
        # without the Win32 long-path prefix; retry with \\?\ before failing.
        $longPath = '\\?\' + $Path
        if (-not [System.IO.File]::Exists($longPath)) { throw }
        $stream = [System.IO.File]::Open($longPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    }
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hash = $sha.ComputeHash($stream)
        } finally {
            $sha.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
    return ([System.BitConverter]::ToString($hash) -replace "-", "").ToLowerInvariant()
}

function ConvertFrom-SblUtf8Strict {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    return $script:SblUtf8Strict.GetString($Bytes)
}

function Get-SblEntryBytes {
    param([Parameter(Mandatory = $true)]$Entry)
    $stream = $Entry.Open()
    try {
        $ms = New-Object System.IO.MemoryStream
        try {
            $stream.CopyTo($ms)
            return $ms.ToArray()
        } finally {
            $ms.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-SblEntryDigestAndLength {
    # Hashes the raw uncompressed bytes of a ZIP entry while counting the
    # actual streamed length (never trusts the declared central-directory
    # size on its own).
    param([Parameter(Mandatory = $true)]$Entry)
    $stream = $Entry.Open()
    try {
        $incremental = [System.Security.Cryptography.IncrementalHash]::CreateHash([System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $buffer = New-Object byte[] 65536
        $total = [long]0
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $incremental.AppendData($buffer, 0, $read)
            $total += $read
        }
        $hash = ([System.BitConverter]::ToString($incremental.GetHashAndReset()) -replace "-", "").ToLowerInvariant()
        return [pscustomobject]@{ Sha256 = $hash; Length = $total }
    } finally {
        $stream.Dispose()
    }
}

# ---------------------------------------------------------------------------
# Strict JSON parser (RFC 8259 subset) with duplicate-member detection
# ---------------------------------------------------------------------------

function Get-SblJsonError {
    param($State, [string]$Message)
    $line = 1
    $column = 1
    $limit = [Math]::Min($State.Pos, $State.Text.Length)
    for ($i = 0; $i -lt $limit; $i++) {
        if ($State.Text[$i] -eq "`n") { $line++; $column = 1 } else { $column++ }
    }
    return "Malformed JSON in $($State.Source) at line $line column ${column}: $Message"
}

function Skip-SblJsonWhitespace {
    param($State)
    while ($State.Pos -lt $State.Text.Length) {
        $c = $State.Text[$State.Pos]
        if ($c -eq ' ' -or $c -eq "`t" -or $c -eq "`r" -or $c -eq "`n") { $State.Pos++ } else { break }
    }
}

function Read-SblJsonString {
    param($State)
    # Current character must be '"'.
    $State.Pos++
    $sb = New-Object System.Text.StringBuilder
    while ($true) {
        if ($State.Pos -ge $State.Text.Length) { throw (Get-SblJsonError $State "unterminated string") }
        $c = $State.Text[$State.Pos]
        $code = [int]$c
        if ($code -eq 34) { $State.Pos++; return $sb.ToString() }
        if ($code -lt 32) { throw (Get-SblJsonError $State "unescaped control character in string") }
        if ($code -eq 92) {
            $State.Pos++
            if ($State.Pos -ge $State.Text.Length) { throw (Get-SblJsonError $State "unterminated escape sequence") }
            $e = $State.Text[$State.Pos]
            $State.Pos++
            $ecode = [int]$e
            if ($ecode -eq 34) { [void]$sb.Append('"') }
            elseif ($ecode -eq 92) { [void]$sb.Append('\') }
            elseif ($ecode -eq 47) { [void]$sb.Append('/') }
            elseif ($ecode -eq 98) { [void]$sb.Append([char]8) }
            elseif ($ecode -eq 102) { [void]$sb.Append([char]12) }
            elseif ($ecode -eq 110) { [void]$sb.Append("`n") }
            elseif ($ecode -eq 114) { [void]$sb.Append("`r") }
            elseif ($ecode -eq 116) { [void]$sb.Append("`t") }
            elseif ($ecode -eq 117) {
                if ($State.Pos + 4 -gt $State.Text.Length) { throw (Get-SblJsonError $State "truncated \u escape") }
                $hex = $State.Text.Substring($State.Pos, 4)
                if ($hex -notmatch '^[0-9a-fA-F]{4}$') { throw (Get-SblJsonError $State "invalid \u escape '$hex'") }
                [void]$sb.Append([char][Convert]::ToInt32($hex, 16))
                $State.Pos += 4
            } else {
                throw (Get-SblJsonError $State "invalid escape character '\$e'")
            }
        } else {
            [void]$sb.Append($c)
            $State.Pos++
        }
    }
}

function Read-SblJsonNumber {
    param($State)
    $start = $State.Pos
    $text = $State.Text
    $len = $text.Length
    if ($State.Pos -lt $len -and $text[$State.Pos] -eq '-') { $State.Pos++ }
    if ($State.Pos -ge $len -or -not [char]::IsDigit($text[$State.Pos])) {
        throw (Get-SblJsonError $State "invalid number")
    }
    if ($text[$State.Pos] -eq '0') {
        $State.Pos++
    } else {
        while ($State.Pos -lt $len -and [char]::IsDigit($text[$State.Pos])) { $State.Pos++ }
    }
    if ($State.Pos -lt $len -and $text[$State.Pos] -eq '.') {
        $State.Pos++
        if ($State.Pos -ge $len -or -not [char]::IsDigit($text[$State.Pos])) { throw (Get-SblJsonError $State "invalid number: missing fractional digits") }
        while ($State.Pos -lt $len -and [char]::IsDigit($text[$State.Pos])) { $State.Pos++ }
    }
    if ($State.Pos -lt $len -and ($text[$State.Pos] -eq 'e' -or $text[$State.Pos] -eq 'E')) {
        $State.Pos++
        if ($State.Pos -lt $len -and ($text[$State.Pos] -eq '+' -or $text[$State.Pos] -eq '-')) { $State.Pos++ }
        if ($State.Pos -ge $len -or -not [char]::IsDigit($text[$State.Pos])) { throw (Get-SblJsonError $State "invalid number: bad exponent") }
        while ($State.Pos -lt $len -and [char]::IsDigit($text[$State.Pos])) { $State.Pos++ }
    }
    $raw = $text.Substring($start, $State.Pos - $start)
    $isFloating = $raw.Contains('.') -or $raw.Contains('e') -or $raw.Contains('E')
    if (-not $isFloating) {
        $parsedLong = [long]0
        if (-not [long]::TryParse($raw, [System.Globalization.NumberStyles]::Integer, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedLong)) {
            throw (Get-SblJsonError $State "integer '$raw' is out of range")
        }
        return $parsedLong
    }
    $parsedDouble = [double]0
    if (-not [double]::TryParse($raw, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedDouble)) {
        throw (Get-SblJsonError $State "invalid number '$raw'")
    }
    return $parsedDouble
}

function Read-SblJsonValue {
    param($State)
    if ($State.Pos -ge $State.Text.Length) { throw (Get-SblJsonError $State "unexpected end of input") }
    $c = $State.Text[$State.Pos]
    $code = [int]$c
    # Collection results are comma-wrapped so the pipeline never unrolls them
    # (an unrolled array would become a fixed-size Object[] and break callers
    # that mutate the parsed value, and would collapse 1-element/empty arrays).
    if ($code -eq 123) { return ,(Read-SblJsonObject $State) }      # {
    if ($code -eq 91) { return ,(Read-SblJsonArray $State) }        # [
    if ($code -eq 34) { return (Read-SblJsonString $State) }        # "
    if ($code -eq 116) {                                             # true
        if ($State.Text.Substring($State.Pos, [Math]::Min(4, $State.Text.Length - $State.Pos)) -ceq "true") { $State.Pos += 4; return $true }
        throw (Get-SblJsonError $State "invalid literal")
    }
    if ($code -eq 102) {                                             # false
        if ($State.Text.Substring($State.Pos, [Math]::Min(5, $State.Text.Length - $State.Pos)) -ceq "false") { $State.Pos += 5; return $false }
        throw (Get-SblJsonError $State "invalid literal")
    }
    if ($code -eq 110) {                                             # null
        if ($State.Text.Substring($State.Pos, [Math]::Min(4, $State.Text.Length - $State.Pos)) -ceq "null") { $State.Pos += 4; return $null }
        throw (Get-SblJsonError $State "invalid literal")
    }
    if ($code -eq 45 -or ($code -ge 48 -and $code -le 57)) { return (Read-SblJsonNumber $State) }
    throw (Get-SblJsonError $State "unexpected character '$c'")
}

function Read-SblJsonObject {
    param($State)
    $State.Pos++ # consume '{'
    $obj = [ordered]@{}
    Skip-SblJsonWhitespace $State
    if ($State.Pos -ge $State.Text.Length) { throw (Get-SblJsonError $State "unterminated object") }
    if ($State.Text[$State.Pos] -eq '}') { $State.Pos++; return $obj }
    while ($true) {
        Skip-SblJsonWhitespace $State
        if ($State.Pos -ge $State.Text.Length) { throw (Get-SblJsonError $State "unterminated object") }
        if ($State.Text[$State.Pos] -ne '"') { throw (Get-SblJsonError $State "object member names must be double-quoted strings") }
        $key = Read-SblJsonString $State
        if ($obj.Contains($key)) { throw (Get-SblJsonError $State "duplicate object member name '$key'") }
        Skip-SblJsonWhitespace $State
        if ($State.Pos -ge $State.Text.Length -or $State.Text[$State.Pos] -ne ':') { throw (Get-SblJsonError $State "expected ':' after object member name '$key'") }
        $State.Pos++
        Skip-SblJsonWhitespace $State
        $value = Read-SblJsonValue $State
        $obj[$key] = $value
        Skip-SblJsonWhitespace $State
        if ($State.Pos -ge $State.Text.Length) { throw (Get-SblJsonError $State "unterminated object") }
        $c = $State.Text[$State.Pos]
        if ($c -eq ',') { $State.Pos++; continue }
        if ($c -eq '}') { $State.Pos++; return $obj }
        throw (Get-SblJsonError $State "expected ',' or '}' in object")
    }
}

function Read-SblJsonArray {
    param($State)
    $State.Pos++ # consume '['
    $list = New-Object System.Collections.ArrayList
    Skip-SblJsonWhitespace $State
    if ($State.Pos -ge $State.Text.Length) { throw (Get-SblJsonError $State "unterminated array") }
    if ($State.Text[$State.Pos] -eq ']') { $State.Pos++; return ,$list }
    while ($true) {
        Skip-SblJsonWhitespace $State
        $value = Read-SblJsonValue $State
        [void]$list.Add($value)
        Skip-SblJsonWhitespace $State
        if ($State.Pos -ge $State.Text.Length) { throw (Get-SblJsonError $State "unterminated array") }
        $c = $State.Text[$State.Pos]
        if ($c -eq ',') { $State.Pos++; continue }
        if ($c -eq ']') { $State.Pos++; return ,$list }
        throw (Get-SblJsonError $State "expected ',' or ']' in array")
    }
}

function ConvertFrom-SblStrictJson {
    # Strict recursive-descent JSON parse. Rejects trailing content, comments,
    # single quotes, trailing commas, NaN/Infinity, unescaped control
    # characters, and duplicate object member names.
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$Source = "json"
    )
    $state = [pscustomobject]@{ Text = $Text; Pos = 0; Source = $Source }
    # Tolerate a single leading UTF-8 BOM character (we write manifests
    # without one, but a re-encoded copy must not fail on it).
    if ($Text.Length -gt 0 -and [int]$Text[0] -eq 0xFEFF) { $state.Pos = 1 }
    Skip-SblJsonWhitespace $state
    if ($state.Pos -ge $state.Text.Length) { throw (Get-SblJsonError $state "empty document") }
    $value = Read-SblJsonValue $state
    Skip-SblJsonWhitespace $state
    if ($state.Pos -lt $state.Text.Length) { throw (Get-SblJsonError $state "trailing content after JSON value") }
    return ,$value
}

# ---------------------------------------------------------------------------
# JSON type helpers and schema validation
# ---------------------------------------------------------------------------

function Test-SblIsJsonObject { param($Value) return ($Value -is [System.Collections.IDictionary]) }
function Test-SblIsJsonArray { param($Value) return (($Value -is [System.Collections.IList]) -and -not ($Value -is [string])) }
function Test-SblIsJsonString { param($Value) return ($Value -is [string]) }
function Test-SblIsJsonBool { param($Value) return ($Value -is [bool]) }
function Test-SblIsJsonInt { param($Value) return (($Value -is [long]) -or ($Value -is [int]) -or ($Value -is [int16])) }
function Test-SblIsJsonNullOrBool { param($Value) return (($null -eq $Value) -or ($Value -is [bool])) }
function Test-SblIsSha256Lower { param($Value) return (($Value -is [string]) -and ($Value -cmatch '^[0-9a-f]{64}$')) }
function Test-SblIsCommitSha { param($Value) return (($Value -is [string]) -and ($Value -cmatch '^[0-9a-f]{40}$')) }

function Add-SblMemberSetErrors {
    param(
        $Object,
        [string[]]$Expected,
        [string]$Where,
        $ErrorList
    )
    foreach ($name in $Expected) {
        if (-not $Object.Contains($name)) { [void]$ErrorList.Add("$Where is missing required member '$name'.") }
    }
    foreach ($key in @($Object.Keys)) {
        if ($Expected -notcontains $key) { [void]$ErrorList.Add("$Where contains unsupported member '$key'.") }
    }
}

function Test-SblManifestSchema {
    # Validates schema version, member sets, types, enumerations and digest
    # formats. Returns a string array of diagnostics (empty when valid).
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [string]$ArchiveName = "archive"
    )
    $errors = New-Object System.Collections.ArrayList
    $where = "release-manifest.json in '$ArchiveName'"

    if (-not (Test-SblIsJsonObject $Manifest)) {
        [void]$errors.Add("$where must be a JSON object.")
        return ,([string[]]$errors.ToArray())
    }

    $topMembers = @('manifest_schema_version', 'package', 'source', 'godot', 'configuration', 'payload')
    Add-SblMemberSetErrors -Object $Manifest -Expected $topMembers -Where $where -ErrorList $errors

    if ($Manifest.Contains('manifest_schema_version')) {
        $version = $Manifest['manifest_schema_version']
        if (-not (Test-SblIsJsonInt $version)) {
            [void]$errors.Add("${where}: 'manifest_schema_version' must be an integer.")
        } elseif ($version -ne $script:SblManifestSchemaVersion) {
            [void]$errors.Add("${where}: unsupported manifest schema version '$version'; only version $script:SblManifestSchemaVersion is supported.")
        }
    }

    if ($Manifest.Contains('package')) {
        $package = $Manifest['package']
        if (-not (Test-SblIsJsonObject $package)) {
            [void]$errors.Add("${where}: 'package' must be a JSON object.")
        } else {
            Add-SblMemberSetErrors -Object $package -Expected @('archive_name', 'platform', 'tier') -Where "${where}: 'package'" -ErrorList $errors
            if ($package.Contains('archive_name')) {
                $archiveNameValue = $package['archive_name']
                if ((-not (Test-SblIsJsonString $archiveNameValue)) -or [string]::IsNullOrEmpty($archiveNameValue)) {
                    [void]$errors.Add("${where}: 'package.archive_name' must be a non-empty string.")
                }
            }
            if ($package.Contains('platform')) {
                $platformValue = $package['platform']
                if ((-not (Test-SblIsJsonString $platformValue)) -or (@('web', 'windows') -notcontains $platformValue)) {
                    [void]$errors.Add("${where}: 'package.platform' must be 'web' or 'windows'.")
                }
            }
            if ($package.Contains('tier')) {
                $tierValue = $package['tier']
                if ((-not (Test-SblIsJsonString $tierValue)) -or (@('academic_mvp', 'full_release') -notcontains $tierValue)) {
                    [void]$errors.Add("${where}: 'package.tier' must be 'academic_mvp' or 'full_release'.")
                }
            }
        }
    }

    if ($Manifest.Contains('source')) {
        $source = $Manifest['source']
        if (-not (Test-SblIsJsonObject $source)) {
            [void]$errors.Add("${where}: 'source' must be a JSON object.")
        } else {
            Add-SblMemberSetErrors -Object $source -Expected @('commit', 'dirty', 'status_porcelain_sha256') -Where "${where}: 'source'" -ErrorList $errors
            if ($source.Contains('commit') -and -not (Test-SblIsCommitSha $source['commit'])) {
                [void]$errors.Add("${where}: 'source.commit' must be a full lowercase 40-character Git commit SHA.")
            }
            if ($source.Contains('dirty') -and -not (Test-SblIsJsonBool $source['dirty'])) {
                [void]$errors.Add("${where}: 'source.dirty' must be a JSON boolean.")
            }
            if ($source.Contains('status_porcelain_sha256') -and -not (Test-SblIsSha256Lower $source['status_porcelain_sha256'])) {
                [void]$errors.Add("${where}: 'source.status_porcelain_sha256' must be a lowercase SHA-256 digest.")
            }
        }
    }

    if ($Manifest.Contains('godot')) {
        $godot = $Manifest['godot']
        if (-not (Test-SblIsJsonObject $godot)) {
            [void]$errors.Add("${where}: 'godot' must be a JSON object.")
        } else {
            Add-SblMemberSetErrors -Object $godot -Expected @('version', 'executable_sha256') -Where "${where}: 'godot'" -ErrorList $errors
            if ($godot.Contains('version')) {
                $versionValue = $godot['version']
                if ((-not (Test-SblIsJsonString $versionValue)) -or ($versionValue -notmatch ('^' + [regex]::Escape($script:SblRequiredGodotVersionPrefix) + '\.[A-Za-z0-9.]+$'))) {
                    [void]$errors.Add("${where}: 'godot.version' must record the actual Godot $script:SblRequiredGodotVersionPrefix version output.")
                }
            }
            if ($godot.Contains('executable_sha256') -and -not (Test-SblIsSha256Lower $godot['executable_sha256'])) {
                [void]$errors.Add("${where}: 'godot.executable_sha256' must be a lowercase SHA-256 digest.")
            }
        }
    }

    if ($Manifest.Contains('configuration')) {
        $configuration = $Manifest['configuration']
        if (-not (Test-SblIsJsonObject $configuration)) {
            [void]$errors.Add("${where}: 'configuration' must be a JSON object.")
        } else {
            Add-SblMemberSetErrors -Object $configuration -Expected @('preset_name', 'renderer', 'web_thread_support', 'project_snapshot', 'presets_snapshot') -Where "${where}: 'configuration'" -ErrorList $errors
            if ($configuration.Contains('preset_name')) {
                $presetValue = $configuration['preset_name']
                if ((-not (Test-SblIsJsonString $presetValue)) -or (@('Web', 'Windows Desktop') -notcontains $presetValue)) {
                    [void]$errors.Add("${where}: 'configuration.preset_name' must be 'Web' or 'Windows Desktop'.")
                }
            }
            if ($configuration.Contains('renderer')) {
                $rendererValue = $configuration['renderer']
                if ((-not (Test-SblIsJsonString $rendererValue)) -or ($rendererValue -ne $script:SblCompatibleRenderer)) {
                    [void]$errors.Add("${where}: 'configuration.renderer' must be '$script:SblCompatibleRenderer'.")
                }
            }
            if ($configuration.Contains('web_thread_support') -and -not (Test-SblIsJsonNullOrBool $configuration['web_thread_support'])) {
                [void]$errors.Add("${where}: 'configuration.web_thread_support' must be a boolean or null.")
            }
            if ($configuration.Contains('project_snapshot')) {
                $snapshotValue = $configuration['project_snapshot']
                if ((-not (Test-SblIsJsonString $snapshotValue)) -or ($snapshotValue -cne $script:SblProjectSnapshotPath)) {
                    [void]$errors.Add("${where}: 'configuration.project_snapshot' must be '$script:SblProjectSnapshotPath'.")
                }
            }
            if ($configuration.Contains('presets_snapshot')) {
                $snapshotValue = $configuration['presets_snapshot']
                if ((-not (Test-SblIsJsonString $snapshotValue)) -or ($snapshotValue -cne $script:SblPresetsSnapshotPath)) {
                    [void]$errors.Add("${where}: 'configuration.presets_snapshot' must be '$script:SblPresetsSnapshotPath'.")
                }
            }
        }
    }

    if ($Manifest.Contains('payload')) {
        $payload = $Manifest['payload']
        if (-not (Test-SblIsJsonArray $payload)) {
            [void]$errors.Add("${where}: 'payload' must be a JSON array.")
        } else {
            # Ordinal, case-sensitive exact tracking so a case-only variant is
            # reported as a case collision, not an exact duplicate.
            $seenExact = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
            $seenLower = @{}
            for ($i = 0; $i -lt $payload.Count; $i++) {
                $element = $payload[$i]
                $elementWhere = "${where}: 'payload[$i]'"
                if (-not (Test-SblIsJsonObject $element)) {
                    [void]$errors.Add("$elementWhere must be a JSON object.")
                    continue
                }
                Add-SblMemberSetErrors -Object $element -Expected @('path', 'size_bytes', 'sha256') -Where $elementWhere -ErrorList $errors
                $pathValue = $null
                if ($element.Contains('path')) {
                    $pathValue = $element['path']
                    if (-not (Test-SblIsJsonString $pathValue)) {
                        [void]$errors.Add("${elementWhere}: 'path' must be a string.")
                        $pathValue = $null
                    } else {
                        $pathError = Get-SblEntryPathError -RawPath $pathValue -Context "manifest payload path"
                        if ($null -ne $pathError) { [void]$errors.Add("${elementWhere}: $pathError") }
                        if ($pathValue -ieq $script:SblManifestEntryName) {
                            [void]$errors.Add("${elementWhere}: the manifest must not list itself as payload.")
                        }
                        if ($seenExact.Contains($pathValue)) {
                            [void]$errors.Add("${where}: duplicate payload path '$pathValue'.")
                        } else {
                            [void]$seenExact.Add($pathValue)
                            $lower = $pathValue.ToLowerInvariant()
                            if ($seenLower.ContainsKey($lower)) {
                                [void]$errors.Add("${where}: case-colliding payload paths '$($seenLower[$lower])' and '$pathValue'.")
                            } else {
                                $seenLower[$lower] = $pathValue
                            }
                        }
                    }
                }
                if ($element.Contains('size_bytes')) {
                    $sizeValue = $element['size_bytes']
                    if (-not (Test-SblIsJsonInt $sizeValue) -or $sizeValue -lt 0) {
                        [void]$errors.Add("${elementWhere}: 'size_bytes' must be a non-negative integer.")
                    }
                }
                if ($element.Contains('sha256') -and -not (Test-SblIsSha256Lower $element['sha256'])) {
                    [void]$errors.Add("${elementWhere}: 'sha256' must be a lowercase SHA-256 digest.")
                }
            }
        }
    }

    return ,([string[]]$errors.ToArray())
}

# ---------------------------------------------------------------------------
# ZIP entry path safety and entry type classification
# ---------------------------------------------------------------------------

function Get-SblEntryPathError {
    # Rejects absolute, drive-qualified, UNC/backslash, empty, '.' and '..'
    # component paths. Returns $null when the path is acceptable.
    param(
        [string]$RawPath,
        [string]$Context = "ZIP entry"
    )
    if ([string]::IsNullOrEmpty($RawPath)) { return "$Context has an empty path." }
    if ($RawPath -match '[\x00-\x1F]') { return "$Context path contains control characters." }
    if ($RawPath -match '^[A-Za-z]:') { return "$Context path is drive-qualified: '$RawPath'." }
    if ($RawPath.Contains('\')) { return "$Context path contains a backslash: '$RawPath'." }
    if ($RawPath.StartsWith('/')) { return "$Context path is absolute: '$RawPath'." }
    if ($RawPath.Contains(':')) { return "$Context path contains a colon: '$RawPath'." }
    foreach ($segment in ($RawPath -split '/')) {
        if ($segment -eq '') { return "$Context path contains an empty component: '$RawPath'." }
        if ($segment -eq '.') { return "$Context path contains a '.' component: '$RawPath'." }
        if ($segment -eq '..') { return "$Context path contains a '..' traversal component: '$RawPath'." }
    }
    return $null
}

function Get-SblEntryKind {
    # Classifies a ZIP entry from its raw name and external attributes.
    # Returns 'regular', 'directory', 'symlink', 'reparse' or 'unsupported'.
    param([Parameter(Mandatory = $true)]$Entry)
    $raw = $Entry.FullName
    $ea = [System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes([int]$Entry.ExternalAttributes), 0)
    $unixMode = ($ea -shr 16) -band 0xFFFF
    $unixType = $unixMode -band 0xF000
    $dosAttrs = $ea -band 0xFFFF
    if ($unixType -eq 0xA000) { return "symlink" }
    if ($unixType -eq 0x4000) { return "directory" }
    if ($unixType -ne 0 -and $unixType -ne 0x8000) { return "unsupported" }
    if (($dosAttrs -band 0x400) -ne 0) { return "reparse" }
    if (($dosAttrs -band 0x10) -ne 0) { return "directory" }
    if ($raw.EndsWith('/')) { return "directory" }
    return "regular"
}

# ---------------------------------------------------------------------------
# Source / engine / configuration provenance capture
# ---------------------------------------------------------------------------

function Invoke-SblProcessCapture {
    # Runs a process with redirected stdout/stderr and returns exit code and
    # captured text. Used for `git` and `godot --version` capture.
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$TimeoutMs = 300000
    )
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $quoted = foreach ($arg in $ArgumentList) {
        if ($null -eq $arg) { '""' }
        elseif ($arg -match '[\s"]') { '"' + ($arg -replace '"', '\"') + '"' }
        else { $arg }
    }
    $startInfo.Arguments = ($quoted -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        if (-not $process.WaitForExit($TimeoutMs)) {
            try { $process.Kill() } catch { }
            throw "Process '$FilePath' did not exit within $TimeoutMs ms."
        }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr }
    } finally {
        $process.Dispose()
    }
}

function Get-SblSourceProvenance {
    # Captures source provenance BEFORE any exporter staging or configuration
    # mutation. Fails hard when Git is unavailable or errors; never
    # substitutes "unknown". The status digest is the SHA-256 of the UTF-8
    # bytes of `git status --porcelain=v1 --untracked-files=all` output after
    # documented LF normalization (CRLF/CR -> LF).
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) { throw "Git executable not found on PATH; source provenance cannot be captured." }
    $root = (Resolve-Path -LiteralPath $RepoRoot).Path

    $revision = Invoke-SblProcessCapture -FilePath $gitCommand.Source -ArgumentList @("-C", $root, "rev-parse", "HEAD")
    if ($revision.ExitCode -ne 0) { throw "git rev-parse HEAD failed (exit $($revision.ExitCode)): $($revision.StdErr.Trim())" }
    $commit = $revision.StdOut.Trim()
    if ($commit -notmatch '^[0-9a-f]{40}$') { throw "git rev-parse HEAD returned unexpected value '$commit'." }

    $status = Invoke-SblProcessCapture -FilePath $gitCommand.Source -ArgumentList @("-C", $root, "status", "--porcelain=v1", "--untracked-files=all")
    if ($status.ExitCode -ne 0) { throw "git status --porcelain=v1 --untracked-files=all failed (exit $($status.ExitCode)): $($status.StdErr.Trim())" }
    $normalized = $status.StdOut -replace "`r`n", "`n" -replace "`r", "`n"
    $dirty = ($normalized.Length -gt 0)
    $digest = Get-SblSha256LowerFromBytes -Bytes ([System.Text.Encoding]::UTF8.GetBytes($normalized))

    return [pscustomobject]@{
        commit                   = $commit
        dirty                    = $dirty
        status_porcelain_sha256  = $digest
    }
}

function Get-SblEngineProvenance {
    # Runs the resolved executable with --version, requires Godot 4.7.2
    # Stable, and hashes the executable. Fails rather than substituting.
    param(
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [string]$RequiredVersionPrefix = $script:SblRequiredGodotVersionPrefix
    )
    if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable not found at '$GodotPath'." }
    $resolved = (Resolve-Path -LiteralPath $GodotPath).Path

    $versionRun = Invoke-SblProcessCapture -FilePath $resolved -ArgumentList @("--version")
    if ($versionRun.ExitCode -ne 0) { throw "Godot --version failed (exit $($versionRun.ExitCode)): $($versionRun.StdErr.Trim())" }
    $version = $null
    foreach ($line in ($versionRun.StdOut -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match ('^' + [regex]::Escape($RequiredVersionPrefix) + '\.')) { $version = $trimmed; break }
    }
    if ($null -eq $version) {
        $firstLine = (($versionRun.StdOut -split "`r?`n") | Where-Object { $_ -match '\S' } | Select-Object -First 1)
        throw "Godot at '$resolved' reports version '$($firstLine.Trim())'; required Godot $RequiredVersionPrefix Stable."
    }

    $executableSha = Get-SblSha256LowerFromFile -Path $resolved
    return [pscustomobject]@{
        version            = $version
        executable_sha256  = $executableSha
    }
}

function Get-SblProjectSettingValue {
    # Reads a `key="value"` project setting from project.godot text.
    param([Parameter(Mandatory = $true)][string]$Text, [Parameter(Mandatory = $true)][string]$Key)
    $body = $Text
    if ($body.Length -gt 0 -and [int]$body[0] -eq 0xFEFF) { $body = $body.Substring(1) }
    $pattern = '(?m)^' + [regex]::Escape($Key) + '="([^"]*)"'
    $match = [regex]::Match($body, $pattern)
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Get-SblPresetThreadSupport {
    # Reads variant/thread_support for the named preset out of
    # export_presets.cfg text. Returns @{ Found; Value } where Value is
    # $true/$false when present and $null when the preset defines no such
    # option (the Windows Desktop preset has none).
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$PresetName
    )
    $body = $Text
    if ($body.Length -gt 0 -and [int]$body[0] -eq 0xFEFF) { $body = $body.Substring(1) }
    $presetBlocks = [regex]::Matches($body, '(?ms)^\[preset\.(?<n>\d+)\]\s*$(?<body>.*?)(?=^\[|\z)')
    foreach ($block in $presetBlocks) {
        $blockBody = $block.Groups['body'].Value
        $nameMatch = [regex]::Match($blockBody, '(?m)^name="([^"]*)"')
        if (-not $nameMatch.Success) { continue }
        if ($nameMatch.Groups[1].Value -cne $PresetName) { continue }
        $index = $block.Groups['n'].Value
        $optionsPattern = '(?ms)^\[preset\.' + [regex]::Escape($index) + '\.options\]\s*$(?<body>.*?)(?=^\[|\z)'
        $optionsMatch = [regex]::Match($body, $optionsPattern)
        $value = $null
        if ($optionsMatch.Success) {
            $threadMatch = [regex]::Match($optionsMatch.Groups['body'].Value, '(?m)^variant/thread_support=(?<v>true|false)\s*$')
            if ($threadMatch.Success) { $value = ($threadMatch.Groups['v'].Value -eq 'true') }
        }
        return @{ Found = $true; Value = $value }
    }
    return @{ Found = $false; Value = $null }
}

# ---------------------------------------------------------------------------
# Package specifications (single source of truth for archive expectations)
# ---------------------------------------------------------------------------

function Get-SblPackageSpec {
    # Returns the fixed specification for a known release archive, or $null
    # when the name is not a recognized Soulbound release package.
    param([Parameter(Mandatory = $true)][string]$ArchiveName)
    switch ($ArchiveName) {
        "Soulbound-AcademicMVP-Web.zip" {
            return [pscustomobject]@{
                ArchiveName     = "Soulbound-AcademicMVP-Web.zip"
                Platform        = "web"
                Tier            = "academic_mvp"
                PresetName      = "Web"
                Label           = "AcademicMVP-Web"
                PckEntry        = "index.pck"
                RequiredEntries = @("index.html", "index.wasm", "index.pck", "build_tier.txt")
            }
        }
        "Soulbound-Web.zip" {
            return [pscustomobject]@{
                ArchiveName     = "Soulbound-Web.zip"
                Platform        = "web"
                Tier            = "full_release"
                PresetName      = "Web"
                Label           = "FullRelease-Web"
                PckEntry        = "index.pck"
                RequiredEntries = @("index.html", "index.wasm", "index.pck", "build_tier.txt")
            }
        }
        "Soulbound-Windows-Portable.zip" {
            return [pscustomobject]@{
                ArchiveName     = "Soulbound-Windows-Portable.zip"
                Platform        = "windows"
                Tier            = "full_release"
                PresetName      = "Windows Desktop"
                Label           = "FullRelease-Windows"
                PckEntry        = "Soulbound.pck"
                RequiredEntries = @("Soulbound.exe", "Soulbound.pck", "build_tier.txt")
            }
        }
        default { return $null }
    }
}

# ---------------------------------------------------------------------------
# Manifest creation, packaging and receipt writing
# ---------------------------------------------------------------------------

function New-SblReleaseManifest {
    # Stages configuration snapshots under provenance/, enumerates staged
    # payload bytes (every file except the manifest itself), sorts by ordinal
    # path, and writes schema-version-1 release-manifest.json into the
    # staging directory. Returns the manifest object.
    param(
        [Parameter(Mandatory = $true)][string]$StagingDir,
        [Parameter(Mandatory = $true)][string]$ArchiveName,
        [Parameter(Mandatory = $true)][string]$Platform,
        [Parameter(Mandatory = $true)][string]$Tier,
        [Parameter(Mandatory = $true)][string]$PresetName,
        [Parameter(Mandatory = $true)]$SourceProvenance,
        [Parameter(Mandatory = $true)]$EngineProvenance,
        [Parameter(Mandatory = $true)][byte[]]$ProjectGodotBytes,
        [Parameter(Mandatory = $true)][byte[]]$PresetsBytes
    )
    if (-not (Test-Path -LiteralPath $StagingDir)) { throw "Staging directory not found: $StagingDir" }

    # 1. Stage configuration snapshots (actual bytes, never rewritten).
    $provenanceDir = Join-Path $StagingDir "provenance"
    if (-not (Test-Path -LiteralPath $provenanceDir)) {
        New-Item -ItemType Directory -Path $provenanceDir -Force | Out-Null
    }
    [System.IO.File]::WriteAllBytes((Join-Path $provenanceDir "project.godot"), $ProjectGodotBytes)
    [System.IO.File]::WriteAllBytes((Join-Path $provenanceDir "export_presets.cfg"), $PresetsBytes)

    # 2. Derive configuration semantics from the staged snapshot bytes.
    $projectText = ConvertFrom-SblUtf8Strict -Bytes $ProjectGodotBytes
    $presetsText = ConvertFrom-SblUtf8Strict -Bytes $PresetsBytes
    $renderer = Get-SblProjectSettingValue -Text $projectText -Key "renderer/rendering_method"
    if ($null -eq $renderer) { throw "Staged project snapshot for '$ArchiveName' has no renderer/rendering_method setting." }
    $threadResult = Get-SblPresetThreadSupport -Text $presetsText -PresetName $PresetName
    if (-not $threadResult.Found) { throw "export_presets.cfg does not define preset '$PresetName'." }
    $webThreadSupport = $threadResult.Value

    # 3. Enumerate staged payload bytes (ordinal sort by normalized path).
    $stagingRoot = (Resolve-Path -LiteralPath $StagingDir).Path
    $files = @(Get-ChildItem -LiteralPath $stagingRoot -Recurse -File -Force)
    $relativePaths = [string[]]@(
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($stagingRoot.Length).TrimStart('\', '/').Replace('\', '/')
            if ($relative -cne $script:SblManifestEntryName) { $relative }
        }
    )
    [Array]::Sort($relativePaths, [System.StringComparer]::Ordinal)

    $payload = foreach ($relative in $relativePaths) {
        $filePath = Join-Path $stagingRoot ($relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        [ordered]@{
            path       = $relative
            size_bytes = [long](Get-Item -LiteralPath $filePath).Length
            sha256     = Get-SblSha256LowerFromFile -Path $filePath
        }
    }

    # 4. Assemble the manifest exactly per the approved schema.
    $manifest = [ordered]@{
        manifest_schema_version = $script:SblManifestSchemaVersion
        package                 = [ordered]@{
            archive_name = $ArchiveName
            platform     = $Platform
            tier         = $Tier
        }
        source                  = [ordered]@{
            commit                   = $SourceProvenance.commit
            dirty                    = [bool]$SourceProvenance.dirty
            status_porcelain_sha256  = $SourceProvenance.status_porcelain_sha256
        }
        godot                   = [ordered]@{
            version           = $EngineProvenance.version
            executable_sha256 = $EngineProvenance.executable_sha256
        }
        configuration           = [ordered]@{
            preset_name         = $PresetName
            renderer            = $renderer
            web_thread_support  = $webThreadSupport
            project_snapshot    = $script:SblProjectSnapshotPath
            presets_snapshot    = $script:SblPresetsSnapshotPath
        }
        payload                 = @($payload)
    }

    # 5. Serialize deterministically (UTF-8 without BOM).
    $json = ConvertTo-Json -InputObject $manifest -Depth 8
    $manifestPath = Join-Path $stagingRoot $script:SblManifestEntryName
    [System.IO.File]::WriteAllText($manifestPath, $json, $script:SblUtf8NoBom)
    return $manifest
}

function New-SblArchiveFromDirectory {
    # Creates a ZIP from a directory tree using forward-slash entry names
    # relative to the source directory. Optional extra entries are appended
    # verbatim (used by disposable negative controls to plant duplicate,
    # colliding, traversal or unsupported-type entries).
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [object[]]$ExtraEntries = @()
    )
    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
    $archiveDir = Split-Path -Parent $ArchivePath
    if ($archiveDir -and -not (Test-Path -LiteralPath $archiveDir)) {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    }
    $files = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force)
    $ordered = [string[]]@(
        foreach ($file in $files) { $file.FullName }
    )
    [Array]::Sort($ordered, [System.StringComparer]::Ordinal)

    $fileStream = [System.IO.File]::Open($ArchivePath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($fileStream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($fullPath in $ordered) {
                $relative = $fullPath.Substring($sourceRoot.Length).TrimStart('\', '/').Replace('\', '/')
                $entry = $zip.CreateEntry($relative, [System.IO.Compression.CompressionLevel]::Optimal)
                $entryStream = $entry.Open()
                try {
                    $input = [System.IO.File]::Open($fullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
                    try { $input.CopyTo($entryStream) } finally { $input.Dispose() }
                } finally {
                    $entryStream.Dispose()
                }
            }
            foreach ($extra in @($ExtraEntries)) {
                $entry = $zip.CreateEntry($extra.Name, [System.IO.Compression.CompressionLevel]::Optimal)
                if ($null -ne $extra.ExternalAttributes) { $entry.ExternalAttributes = [int]$extra.ExternalAttributes }
                $entryStream = $entry.Open()
                try {
                    $bytes = [byte[]]$extra.Bytes
                    if ($bytes.Length -gt 0) { $entryStream.Write($bytes, 0, $bytes.Length) }
                } finally {
                    $entryStream.Dispose()
                }
            }
        } finally {
            $zip.Dispose()
        }
    } finally {
        $fileStream.Dispose()
    }
}

function Expand-SblArchiveToDirectory {
    # Extracts a ZIP into a destination directory, refusing unsafe entry
    # paths so nothing can ever be written outside the destination root.
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestinationDir
    )
    if (-not (Test-Path -LiteralPath $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }
    $destRoot = (Resolve-Path -LiteralPath $DestinationDir).Path
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName
            $pathError = Get-SblEntryPathError -RawPath $name -Context "ZIP entry"
            if ($null -ne $pathError) { throw "Refusing to extract from '$ArchivePath': $pathError" }
            if ($name.EndsWith('/')) { continue }
            $target = Join-Path $destRoot ($name.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            $targetFull = [System.IO.Path]::GetFullPath($target)
            $rootPrefix = $destRoot.TrimEnd('\') + '\'
            if (-not $targetFull.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to extract '$name' outside destination root '$destRoot'."
            }
            $targetDir = Split-Path -Parent $targetFull
            if (-not (Test-Path -LiteralPath $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetFull, $true)
        }
    } finally {
        $zip.Dispose()
    }
}

function Write-SblManifestReceipt {
    # Writes <archive>.manifest.sha256 next to the archive containing the
    # lowercase SHA-256 of the EXACT archived manifest entry bytes.
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [string]$ReceiptPath
    )
    if ([string]::IsNullOrEmpty($ReceiptPath)) { $ReceiptPath = $ArchivePath + ".manifest.sha256" }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $manifestEntries = @($zip.Entries | Where-Object { $_.FullName -ceq $script:SblManifestEntryName })
        if ($manifestEntries.Count -ne 1) {
            throw "Cannot write receipt for '$ArchivePath': expected exactly one root '$script:SblManifestEntryName', found $($manifestEntries.Count)."
        }
        $bytes = Get-SblEntryBytes -Entry $manifestEntries[0]
    } finally {
        $zip.Dispose()
    }
    $digest = Get-SblSha256LowerFromBytes -Bytes $bytes
    [System.IO.File]::WriteAllText($ReceiptPath, $digest + "`n", $script:SblUtf8NoBom)
    return $digest
}

# ---------------------------------------------------------------------------
# Archive verification (shared by production validation and tests)
# ---------------------------------------------------------------------------

function Test-SblReleaseArchive {
    # Strictly verifies a release archive using only archive bytes and its
    # external receipt - never local builds/ payloads or local configuration.
    # Returns [string[]] diagnostics; an empty array means the archive is
    # valid. Checks, in order:
    #   1. ZIP readability; entry type classification (rejects symlink,
    #      reparse, directory and other unsupported types).
    #   2. Path safety (absolute/drive/UNC/backslash/empty/dot/dotdot).
    #   3. Duplicate and case-colliding ZIP entry paths (before any hash
    #      lookup, so extraction/lookup can never be ambiguous).
    #   4. Exactly one root release-manifest.json.
    #   5. External receipt presence, format and digest match.
    #   6. Strict JSON parse (duplicate member names rejected) and schema
    #      version/type/enum/digest validation.
    #   7. Archive identity: manifest package name, platform, tier and
    #      preset against the fixed package spec and caller expectations.
    #   8. Exact payload-to-entry correspondence plus per-entry raw-byte
    #      size and SHA-256 verification.
    #   9. Archived configuration semantics read from provenance/ snapshots
    #      inside the archive (effective tier, Compatibility renderer,
    #      Web single-thread flag).
    #  10. build_tier.txt marker, required entry points, forbidden files
    #      and optional size constraints.
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [string]$ExpectedTier,
        [string]$ExpectedPlatform,
        [string]$ExpectedPreset,
        [string]$ReceiptPath,
        [hashtable]$SizeConstraints
    )
    $errors = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($ReceiptPath)) { $ReceiptPath = $ArchivePath + ".manifest.sha256" }
    $archiveName = [System.IO.Path]::GetFileName($ArchivePath)

    if (-not (Test-Path -LiteralPath $ArchivePath)) {
        [void]$errors.Add("Archive not found: $ArchivePath")
        return ,([string[]]$errors.ToArray())
    }

    $zip = $null
    try {
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        } catch {
            [void]$errors.Add("Archive '$archiveName' cannot be read as a ZIP package: $($_.Exception.Message)")
            return ,([string[]]$errors.ToArray())
        }

        $entries = @($zip.Entries)
        if ($entries.Count -eq 0) {
            [void]$errors.Add("Archive '$archiveName' contains no entries.")
            return ,([string[]]$errors.ToArray())
        }

        # --- 1-4: structure, types, path safety, duplicates, manifest presence
        # Exact-name tracking is ORDINAL and case-sensitive (a PowerShell @{}
        # hashtable is case-insensitive and would misclassify case-colliding
        # paths as exact duplicates); case-collision tracking is separate.
        $seenExact = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        $seenLower = @{}
        $regularEntries = New-Object System.Collections.ArrayList
        $manifestEntries = New-Object System.Collections.ArrayList

        foreach ($entry in $entries) {
            $raw = $entry.FullName
            $kind = Get-SblEntryKind -Entry $entry
            if ($kind -eq "symlink") {
                [void]$errors.Add("Archive '$archiveName' contains an unsupported symlink entry: '$raw'.")
                continue
            }
            if ($kind -eq "reparse") {
                [void]$errors.Add("Archive '$archiveName' contains an unsupported reparse-point entry: '$raw'.")
                continue
            }
            if ($kind -eq "directory") {
                [void]$errors.Add("Archive '$archiveName' contains an unsupported directory entry: '$raw'.")
                continue
            }
            if ($kind -ne "regular") {
                [void]$errors.Add("Archive '$archiveName' contains an unsupported entry type: '$raw'.")
                continue
            }

            $pathError = Get-SblEntryPathError -RawPath $raw -Context "ZIP entry"
            if ($null -ne $pathError) {
                [void]$errors.Add("Archive '$archiveName': $pathError")
                continue
            }

            if ($seenExact.Contains($raw)) {
                [void]$errors.Add("Archive '$archiveName' contains duplicate ZIP entry path: '$raw'.")
                continue
            }
            [void]$seenExact.Add($raw)
            $lower = $raw.ToLowerInvariant()
            if ($seenLower.ContainsKey($lower)) {
                [void]$errors.Add("Archive '$archiveName' contains case-colliding ZIP entry paths: '$($seenLower[$lower])' and '$raw'.")
                continue
            }
            $seenLower[$lower] = $raw

            if ($raw -ceq $script:SblManifestEntryName) {
                [void]$manifestEntries.Add($entry)
            } elseif ($raw -ieq $script:SblManifestEntryName) {
                [void]$errors.Add("Archive '$archiveName' contains a case-variant manifest entry '$raw'; exactly one root '$script:SblManifestEntryName' is allowed.")
            } elseif ((($raw -split '/')[-1]) -ieq $script:SblManifestEntryName) {
                [void]$errors.Add("Archive '$archiveName' contains a nested manifest-named entry '$raw'; the manifest must be the single root entry.")
            } else {
                [void]$regularEntries.Add($entry)
            }
        }

        if ($manifestEntries.Count -eq 0) {
            [void]$errors.Add("Missing required root '$script:SblManifestEntryName' entry in archive '$archiveName'.")
        } elseif ($manifestEntries.Count -gt 1) {
            [void]$errors.Add("Archive '$archiveName' contains $($manifestEntries.Count) root '$script:SblManifestEntryName' entries; exactly one is required.")
        }

        # --- 5: manifest bytes and external receipt
        $manifestBytes = $null
        if ($manifestEntries.Count -eq 1) {
            try {
                $manifestBytes = Get-SblEntryBytes -Entry $manifestEntries[0]
            } catch {
                [void]$errors.Add("Archive '$archiveName': failed reading '$script:SblManifestEntryName': $($_.Exception.Message)")
            }
        }

        $receiptExists = Test-Path -LiteralPath $ReceiptPath
        if (-not $receiptExists) {
            [void]$errors.Add("Missing required manifest receipt file: $ReceiptPath")
        }
        if ($null -ne $manifestBytes -and $receiptExists) {
            $manifestDigest = Get-SblSha256LowerFromBytes -Bytes $manifestBytes
            try {
                $receiptValue = ([System.IO.File]::ReadAllText($ReceiptPath)).Trim()
                if ($receiptValue -notmatch '^[0-9a-f]{64}$') {
                    [void]$errors.Add("Manifest receipt '$ReceiptPath' does not contain a single lowercase SHA-256 digest.")
                } elseif ($receiptValue -cne $manifestDigest) {
                    [void]$errors.Add("Manifest receipt mismatch for archive '$archiveName': receipt records '$receiptValue' but the archived '$script:SblManifestEntryName' hashes to '$manifestDigest'.")
                }
            } catch {
                [void]$errors.Add("Failed reading manifest receipt '$ReceiptPath': $($_.Exception.Message)")
            }
        }

        # --- 6: strict parse and schema validation
        $manifest = $null
        if ($null -ne $manifestBytes) {
            try {
                $jsonText = ConvertFrom-SblUtf8Strict -Bytes $manifestBytes
                $manifest = ConvertFrom-SblStrictJson -Text $jsonText -Source "'$script:SblManifestEntryName' in '$archiveName'"
            } catch {
                [void]$errors.Add("Malformed release manifest in archive '$archiveName': $($_.Exception.Message)")
            }
        }

        if ($null -eq $manifest) {
            return ,([string[]]$errors.ToArray())
        }

        $schemaErrors = Test-SblManifestSchema -Manifest $manifest -ArchiveName $archiveName
        foreach ($schemaError in $schemaErrors) { [void]$errors.Add($schemaError) }
        if ($schemaErrors.Count -gt 0) {
            return ,([string[]]$errors.ToArray())
        }

        # --- 7: identity against the fixed package spec and expectations
        $actualSpec = Get-SblPackageSpec -ArchiveName $archiveName
        if ($null -eq $actualSpec) {
            [void]$errors.Add("Archive '$archiveName' is not a recognized Soulbound release package.")
        }
        $manifestSpec = Get-SblPackageSpec -ArchiveName $manifest.package.archive_name
        if ($manifest.package.archive_name -cne $archiveName) {
            [void]$errors.Add("Manifest package.archive_name '$($manifest.package.archive_name)' does not match archive file name '$archiveName'.")
        }
        if ($null -eq $manifestSpec) {
            [void]$errors.Add("Manifest package.archive_name '$($manifest.package.archive_name)' is not a recognized Soulbound release package.")
        }
        if ($null -ne $actualSpec -and $null -ne $manifestSpec) {
            if ($manifest.package.tier -cne $actualSpec.Tier) {
                [void]$errors.Add("Manifest package.tier '$($manifest.package.tier)' does not match package specification tier '$($actualSpec.Tier)' for '$archiveName'.")
            }
            if ($manifest.package.platform -cne $actualSpec.Platform) {
                [void]$errors.Add("Manifest package.platform '$($manifest.package.platform)' does not match package specification platform '$($actualSpec.Platform)' for '$archiveName'.")
            }
            if ($manifest.configuration.preset_name -cne $actualSpec.PresetName) {
                [void]$errors.Add("Manifest configuration.preset_name '$($manifest.configuration.preset_name)' does not match package specification preset '$($actualSpec.PresetName)' for '$archiveName'.")
            }
        }
        if (-not [string]::IsNullOrEmpty($ExpectedTier) -and $manifest.package.tier -cne $ExpectedTier) {
            [void]$errors.Add("Manifest package.tier '$($manifest.package.tier)' does not match expected tier '$ExpectedTier'.")
        }
        if (-not [string]::IsNullOrEmpty($ExpectedPlatform) -and $manifest.package.platform -cne $ExpectedPlatform) {
            [void]$errors.Add("Manifest package.platform '$($manifest.package.platform)' does not match expected platform '$ExpectedPlatform'.")
        }
        if (-not [string]::IsNullOrEmpty($ExpectedPreset) -and $manifest.configuration.preset_name -cne $ExpectedPreset) {
            [void]$errors.Add("Manifest configuration.preset_name '$($manifest.configuration.preset_name)' does not match expected preset '$ExpectedPreset'.")
        }

        # --- 8: exact payload correspondence and raw-byte hashes/sizes
        $entryByPath = @{}
        foreach ($regularEntry in $regularEntries) { $entryByPath[$regularEntry.FullName] = $regularEntry }
        $manifestPathSet = @{}
        foreach ($payloadRecord in $manifest.payload) {
            $manifestPathSet[$payloadRecord.path] = $true
            if (-not $entryByPath.ContainsKey($payloadRecord.path)) {
                [void]$errors.Add("Manifest payload entry '$($payloadRecord.path)' has no matching ZIP entry (missing file) in archive '$archiveName'.")
                continue
            }
            $zipEntry = $entryByPath[$payloadRecord.path]
            if ([long]$zipEntry.Length -ne [long]$payloadRecord.size_bytes) {
                [void]$errors.Add("Payload '$($payloadRecord.path)' size mismatch: manifest declares $($payloadRecord.size_bytes) bytes, ZIP entry declares $($zipEntry.Length) bytes.")
            }
            $digestInfo = $null
            try {
                $digestInfo = Get-SblEntryDigestAndLength -Entry $zipEntry
            } catch {
                [void]$errors.Add("Payload '$($payloadRecord.path)' could not be read from archive '$archiveName': $($_.Exception.Message)")
            }
            if ($null -ne $digestInfo) {
                if ($digestInfo.Length -ne [long]$payloadRecord.size_bytes) {
                    [void]$errors.Add("Payload '$($payloadRecord.path)' raw-byte length mismatch: hashed $($digestInfo.Length) bytes, manifest declares $($payloadRecord.size_bytes).")
                }
                if ($digestInfo.Sha256 -cne $payloadRecord.sha256) {
                    [void]$errors.Add("Payload '$($payloadRecord.path)' SHA-256 mismatch: manifest declares $($payloadRecord.sha256), archive bytes hash to $($digestInfo.Sha256).")
                }
                if ($null -ne $SizeConstraints -and $SizeConstraints.ContainsKey($payloadRecord.path)) {
                    $constraint = $SizeConstraints[$payloadRecord.path]
                    if ($null -ne $constraint.Min -and $digestInfo.Length -lt $constraint.Min) {
                        [void]$errors.Add("'$($payloadRecord.path)' size $($digestInfo.Length) bytes is below minimum threshold of $($constraint.Min) bytes.")
                    }
                    if ($null -ne $constraint.Max -and $digestInfo.Length -gt $constraint.Max) {
                        [void]$errors.Add("'$($payloadRecord.path)' size $($digestInfo.Length) bytes exceeds maximum threshold of $($constraint.Max) bytes.")
                    }
                }
            }
        }
        foreach ($zipPath in $entryByPath.Keys) {
            if (-not $manifestPathSet.ContainsKey($zipPath)) {
                [void]$errors.Add("ZIP entry '$zipPath' is not listed in the manifest payload (unlisted file) in archive '$archiveName'.")
            }
        }

        # --- 9-10: archived configuration semantics, marker, entry points,
        # forbidden files.
        $forbiddenExtensions = @(".uid", ".import", ".tmp", ".bak", ".swp", ".log", ".err")
        $forbiddenPrefixes = @(".godot/", ".git/", "tests/", "report/")
        foreach ($zipPath in @($entryByPath.Keys)) {
            foreach ($extension in $forbiddenExtensions) {
                if ($zipPath.EndsWith($extension, [System.StringComparison]::OrdinalIgnoreCase)) {
                    [void]$errors.Add("Archive '$archiveName' contains forbidden editor/build artifact: '$zipPath'")
                }
            }
            foreach ($prefix in $forbiddenPrefixes) {
                if ($zipPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    [void]$errors.Add("Archive '$archiveName' contains forbidden debug/test path: '$zipPath'")
                }
            }
        }

        if ($null -ne $actualSpec) {
            foreach ($required in $actualSpec.RequiredEntries) {
                if (-not $entryByPath.ContainsKey($required)) {
                    [void]$errors.Add("[$($actualSpec.Label)] Missing required entry point: '$required'")
                }
            }
        }

        # build_tier.txt marker must equal the manifest tier (archive bytes).
        if ($entryByPath.ContainsKey("build_tier.txt")) {
            try {
                $markerBytes = Get-SblEntryBytes -Entry $entryByPath["build_tier.txt"]
                $markerText = ConvertFrom-SblUtf8Strict -Bytes $markerBytes
                if ($markerText.Length -gt 0 -and [int]$markerText[0] -eq 0xFEFF) { $markerText = $markerText.Substring(1) }
                $markerText = $markerText.Trim()
                if ($markerText -cne $manifest.package.tier) {
                    [void]$errors.Add("[$archiveName] build_tier.txt marker '$markerText' does not match manifest tier '$($manifest.package.tier)'.")
                }
                if ($null -ne $actualSpec -and $markerText -cne $actualSpec.Tier) {
                    [void]$errors.Add("[$archiveName] build_tier.txt marker '$markerText' does not match expected tier '$($actualSpec.Tier)'.")
                }
            } catch {
                [void]$errors.Add("[$archiveName] failed reading build_tier.txt marker: $($_.Exception.Message)")
            }
        }

        # Configuration snapshots are read from ARCHIVE bytes only.
        $projectSnapshotPath = $manifest.configuration.project_snapshot
        if ($entryByPath.ContainsKey($projectSnapshotPath)) {
            try {
                $projectText = ConvertFrom-SblUtf8Strict -Bytes (Get-SblEntryBytes -Entry $entryByPath[$projectSnapshotPath])
                $snapshotTier = Get-SblProjectSettingValue -Text $projectText -Key "release_tier"
                if ($snapshotTier -cne $manifest.package.tier) {
                    [void]$errors.Add("[$archiveName] archived project snapshot release_tier '$snapshotTier' does not match manifest tier '$($manifest.package.tier)'.")
                }
                $snapshotRenderer = Get-SblProjectSettingValue -Text $projectText -Key "renderer/rendering_method"
                if ($snapshotRenderer -cne $manifest.configuration.renderer) {
                    [void]$errors.Add("[$archiveName] archived project snapshot renderer '$snapshotRenderer' does not match manifest configuration.renderer '$($manifest.configuration.renderer)'.")
                }
                if ($snapshotRenderer -cne $script:SblCompatibleRenderer) {
                    [void]$errors.Add("[$archiveName] archived project snapshot must use $script:SblCompatibleRenderer rendering, found '$snapshotRenderer'.")
                }
                $snapshotWebRenderer = Get-SblProjectSettingValue -Text $projectText -Key "renderer/rendering_method.web"
                if ($snapshotWebRenderer -cne $script:SblCompatibleRenderer) {
                    [void]$errors.Add("[$archiveName] archived project snapshot web rendering override must be $script:SblCompatibleRenderer, found '$snapshotWebRenderer'.")
                }
            } catch {
                [void]$errors.Add("[$archiveName] failed reading archived project snapshot: $($_.Exception.Message)")
            }
        } else {
            [void]$errors.Add("[$archiveName] manifest configuration.project_snapshot '$projectSnapshotPath' is not present in the archive.")
        }

        $presetsSnapshotPath = $manifest.configuration.presets_snapshot
        if ($entryByPath.ContainsKey($presetsSnapshotPath)) {
            try {
                $presetsText = ConvertFrom-SblUtf8Strict -Bytes (Get-SblEntryBytes -Entry $entryByPath[$presetsSnapshotPath])
                $threadResult = Get-SblPresetThreadSupport -Text $presetsText -PresetName $manifest.configuration.preset_name
                if (-not $threadResult.Found) {
                    [void]$errors.Add("[$archiveName] archived export preset snapshot does not define preset '$($manifest.configuration.preset_name)'.")
                } else {
                    $snapshotThread = $threadResult.Value
                    $manifestThread = $manifest.configuration.web_thread_support
                    if ($snapshotThread -ne $manifestThread) {
                        [void]$errors.Add("[$archiveName] manifest configuration.web_thread_support '$manifestThread' disagrees with the archived export preset snapshot value '$snapshotThread'.")
                    }
                    if ($manifest.package.platform -eq "web" -and $manifestThread -ne $false) {
                        [void]$errors.Add("[$archiveName] web packages must record configuration.web_thread_support=false (single-threaded web invariant), found '$manifestThread'.")
                    }
                    if ($manifest.package.platform -eq "windows" -and $null -ne $manifestThread) {
                        [void]$errors.Add("[$archiveName] windows packages must record configuration.web_thread_support=null, found '$manifestThread'.")
                    }
                }
            } catch {
                [void]$errors.Add("[$archiveName] failed reading archived export preset snapshot: $($_.Exception.Message)")
            }
        } else {
            [void]$errors.Add("[$archiveName] manifest configuration.presets_snapshot '$presetsSnapshotPath' is not present in the archive.")
        }

        return ,([string[]]$errors.ToArray())
    } finally {
        if ($null -ne $zip) { $zip.Dispose() }
    }
}

# ---------------------------------------------------------------------------
# Archive-contained PCK gate (extracts the archive's OWN .pck)
# ---------------------------------------------------------------------------

function Invoke-SblArchivePckGate {
    # Extracts the package's own PCK from the archive into a fresh temporary
    # directory and runs tests/headless/verify_exported_tier.gd against it.
    # Callers must have entered disposable user-data isolation first.
    # Returns $null on success or an error string.
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)]$Spec,
        [string]$ReportDir,
        [string]$VerifyScript = "res://tests/headless/verify_exported_tier.gd",
        [string]$TempRoot
    )
    if ([string]::IsNullOrEmpty($TempRoot)) { $TempRoot = [System.IO.Path]::GetTempPath() }
    if (-not (Test-Path -LiteralPath $GodotPath)) {
        return "[$($Spec.Label)] Godot executable not found at '$GodotPath'; the required archive-contained PCK gate cannot run."
    }
    $gateDir = Join-Path $TempRoot ("sbl_pck_gate_" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $gateDir -Force | Out-Null
    try {
        $pckPath = Join-Path $gateDir ($Spec.PckEntry -replace '/', '_')
        $zip = $null
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
            $pckEntry = $null
            foreach ($entry in $zip.Entries) {
                if ($entry.FullName -ceq $Spec.PckEntry) { $pckEntry = $entry; break }
            }
            if ($null -eq $pckEntry) { return "[$($Spec.Label)] Missing '$($Spec.PckEntry)' in $ArchivePath" }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($pckEntry, $pckPath, $true)
        } catch {
            return "[$($Spec.Label)] Failed extracting '$($Spec.PckEntry)' from $ArchivePath : $($_.Exception.Message)"
        } finally {
            if ($null -ne $zip) { $zip.Dispose() }
        }

        $logPath = $null
        $errPath = $null
        if (-not [string]::IsNullOrEmpty($ReportDir)) {
            if (-not (Test-Path -LiteralPath $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null }
            $logPath = Join-Path $ReportDir "verify_pck_$($Spec.Label).log"
            $errPath = Join-Path $ReportDir "verify_pck_$($Spec.Label).err"
        }

        $run = Invoke-SblProcessCapture -FilePath $GodotPath -ArgumentList @(
            "--headless",
            "--main-pack", $pckPath,
            "--script", $VerifyScript,
            "--quit-after", "600",
            "--", $Spec.Tier
        )
        if ($null -ne $logPath) { [System.IO.File]::WriteAllText($logPath, $run.StdOut, $script:SblUtf8NoBom) }
        if ($null -ne $errPath) { [System.IO.File]::WriteAllText($errPath, $run.StdErr, $script:SblUtf8NoBom) }

        if ($run.ExitCode -ne 0) {
            $stderrTail = ($run.StdErr -split "`r?`n" | Select-Object -Last 8) -join " | "
            return "Headless gate verification failed for '$($Spec.Tier)' on $($Spec.Label) ($pckPath) (Exit $($run.ExitCode)): $stderrTail"
        }
        return $null
    } finally {
        Remove-SblDirectoryWithinRoot -Path $gateDir -Root $TempRoot
    }
}

# ---------------------------------------------------------------------------
# Disposable user-data isolation for Godot tests and PCK gates
# ---------------------------------------------------------------------------

function Get-SblDirectoryDigest {
    # Ordinal, content-addressed digest of a directory tree. Returns the
    # sentinel "ABSENT" when the directory does not exist.
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path) -or -not (Test-Path -LiteralPath $Path)) { return "ABSENT" }
    $root = (Resolve-Path -LiteralPath $Path).Path
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue)
    $lines = [string[]]@(
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
            "$relative|$($file.Length)|$(Get-SblSha256LowerFromFile -Path $file.FullName)"
        }
    )
    [Array]::Sort($lines, [System.StringComparer]::Ordinal)
    return (Get-SblSha256LowerFromBytes -Bytes ([System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))
}

function Remove-SblDirectoryWithinRoot {
    # Refuses to recursively delete anything that does not resolve inside the
    # expected root (staging/temporary containment invariant). Falls back to a
    # \\?\-prefixed Win32 recursive delete when Remove-Item cannot reach
    # destination paths beyond MAX_PATH (deep seeded shader-cache hash dirs).
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
    if ($resolvedPath -ieq $resolvedRoot) {
        throw "Refusing to remove '$resolvedPath': it equals the protected root."
    }
    $prefix = $resolvedRoot + '\'
    if (-not ($resolvedPath + '\').StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove '$resolvedPath': outside expected root '$resolvedRoot'."
    }
    try {
        Remove-Item -LiteralPath $resolvedPath -Recurse -Force -ErrorAction Stop
    } catch {
        $longPath = '\\?\' + $resolvedPath
        if (-not [System.IO.Directory]::Exists($longPath)) {
            throw "Failed to remove '$resolvedPath' (long-path retry unavailable): $($_.Exception.Message)"
        }
        [System.IO.Directory]::Delete($longPath, $true)
        if (Test-Path -LiteralPath $resolvedPath) {
            throw "Failed to remove '$resolvedPath': long-path delete left residue."
        }
    }
}

function Enter-SblGodotUserDataIsolation {
    # Redirects APPDATA and LOCALAPPDATA for the current process to a fresh
    # disposable root, then PROVES the redirection with a headless Godot probe
    # that prints OS.get_user_data_dir() before any test or gate runs. Snapshots
    # the real roaming/local Godot directories for byte-identity comparison on
    # exit. Returns a state object for Exit-SblGodotUserDataIsolation.
    #
    # -SeedFrom copies an existing Godot data directory (real %APPDATA%\Godot)
    # into the disposable root before the probe. This preserves the historical
    # baseline state that some suites depend on (pre-existing profile_01) and
    # makes export templates available to chained exporters, while every write
    # still lands in the disposable copy and the real directory stays
    # byte-identical (verified on exit). The copy is verified by file count.
    param(
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [string]$Label = "run",
        [string]$SeedFrom = ""
    )
    if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable not found at '$GodotPath'." }

    $oldAppData = $env:APPDATA
    $oldLocalAppData = $env:LOCALAPPDATA
    $tempRoot = [System.IO.Path]::GetTempPath()
    $root = Join-Path $tempRoot ("soulbound_userdata_" + $Label + "_" + [System.Guid]::NewGuid().ToString("N"))
    $roamingDir = Join-Path $root "roaming"
    $localDir = Join-Path $root "local"
    New-Item -ItemType Directory -Path $roamingDir -Force | Out-Null
    New-Item -ItemType Directory -Path $localDir -Force | Out-Null

    if (-not [string]::IsNullOrEmpty($SeedFrom)) {
        if (-not (Test-Path -LiteralPath $SeedFrom)) { throw "Disposable user-data seed source not found: $SeedFrom" }
        $seedTarget = Join-Path $roamingDir "Godot"
        # robocopy is used because Copy-Item cannot write destination paths
        # beyond the 260-char MAX_PATH (deep shader-cache hash directories
        # exceed it under the longer disposable prefix). Exit codes 0-7 are
        # success; 8+ is a failure.
        & robocopy.exe $SeedFrom $seedTarget /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        $robocopyExit = $LASTEXITCODE
        if ($robocopyExit -ge 8) {
            throw "Disposable user-data seeding failed: robocopy exit code $robocopyExit."
        }
        $sourceCount = @(Get-ChildItem -LiteralPath $SeedFrom -Recurse -File -Force -ErrorAction SilentlyContinue).Count
        $seedCount = @(Get-ChildItem -LiteralPath $seedTarget -Recurse -File -Force -ErrorAction SilentlyContinue).Count
        if ($sourceCount -eq 0 -or $sourceCount -ne $seedCount) {
            throw "Disposable user-data seeding incomplete: $sourceCount source file(s) vs $seedCount copied."
        }
    }

    $realRoaming = if (-not [string]::IsNullOrEmpty($oldAppData)) { Join-Path $oldAppData "Godot" } else { $null }
    $realLocal = if (-not [string]::IsNullOrEmpty($oldLocalAppData)) { Join-Path $oldLocalAppData "Godot" } else { $null }
    $roamingDigest = Get-SblDirectoryDigest -Path $realRoaming
    $localDigest = Get-SblDirectoryDigest -Path $realLocal

    $env:APPDATA = $roamingDir
    $env:LOCALAPPDATA = $localDir

    $probePath = Join-Path $tempRoot ("sbl_user_data_probe_" + [System.Guid]::NewGuid().ToString("N") + ".gd")
    try {
        $probeSource = "extends SceneTree`nfunc _init() -> void:`n    print(`"SBL_USER_DATA_DIR=`", OS.get_user_data_dir())`n    quit(0)`n"
        [System.IO.File]::WriteAllText($probePath, $probeSource, $script:SblUtf8NoBom)
        $probeRun = Invoke-SblProcessCapture -FilePath $GodotPath -ArgumentList @("--headless", "--path", $ProjectRoot, "--script", $probePath)
        if ($probeRun.ExitCode -ne 0) {
            throw "Disposable user-data probe failed (exit $($probeRun.ExitCode)): $($probeRun.StdErr.Trim())"
        }
        $probeLine = ($probeRun.StdOut -split "`r?`n" | Where-Object { $_ -like "SBL_USER_DATA_DIR=*" } | Select-Object -First 1)
        if ($null -eq $probeLine) { throw "Disposable user-data probe produced no SBL_USER_DATA_DIR output." }
        $resolvedUserDir = $probeLine.Substring("SBL_USER_DATA_DIR=".Length).Trim().Replace('/', '\')
        $expectedPrefix = $root.TrimEnd('\') + '\'
        if (-not $resolvedUserDir.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Disposable user-data proof failed: Godot resolved '$resolvedUserDir', expected under '$expectedPrefix'."
        }
    } catch {
        $env:APPDATA = $oldAppData
        $env:LOCALAPPDATA = $oldLocalAppData
        if (Test-Path -LiteralPath $root) { Remove-SblDirectoryWithinRoot -Path $root -Root $tempRoot }
        throw
    } finally {
        if (Test-Path -LiteralPath $probePath) { Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue }
    }

    return [pscustomobject]@{
        Root               = $root
        ProbeUserDir       = $resolvedUserDir
        OldAppData         = $oldAppData
        OldLocalAppData    = $oldLocalAppData
        RealRoamingPath    = $realRoaming
        RealLocalPath      = $realLocal
        RealRoamingDigest  = $roamingDigest
        RealLocalDigest    = $localDigest
        Label              = $Label
    }
}

function Exit-SblGodotUserDataIsolation {
    # Restores the environment, verifies the real user-data directories are
    # byte-identical to the pre-run snapshots, reports disposable usage, and
    # removes the disposable root (unless -KeepRoot).
    param(
        [Parameter(Mandatory = $true)]$State,
        [switch]$KeepRoot
    )
    $env:APPDATA = $State.OldAppData
    $env:LOCALAPPDATA = $State.OldLocalAppData

    $postRoaming = Get-SblDirectoryDigest -Path $State.RealRoamingPath
    $postLocal = Get-SblDirectoryDigest -Path $State.RealLocalPath
    $realDataUnchanged = ($postRoaming -eq $State.RealRoamingDigest) -and ($postLocal -eq $State.RealLocalDigest)

    $disposableFileCount = 0
    if (Test-Path -LiteralPath $State.Root) {
        $disposableFileCount = @(Get-ChildItem -LiteralPath $State.Root -Recurse -File -Force -ErrorAction SilentlyContinue).Count
    }

    if (-not $KeepRoot -and (Test-Path -LiteralPath $State.Root)) {
        Remove-SblDirectoryWithinRoot -Path $State.Root -Root ([System.IO.Path]::GetTempPath())
    }

    return [pscustomobject]@{
        Label               = $State.Label
        ProbeUserDir        = $State.ProbeUserDir
        RealDataUnchanged   = $realDataUnchanged
        DisposableFileCount = $disposableFileCount
        RootRemoved         = (-not (Test-Path -LiteralPath $State.Root))
    }
}
