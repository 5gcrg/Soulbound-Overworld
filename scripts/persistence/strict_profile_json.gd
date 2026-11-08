class_name StrictProfileJson
extends RefCounted

## StrictProfileJson
## Validates JSON text syntax strictly per RFC 8259 before native JSON.parse.
## Rejects duplicate decoded member names, non-finite values, unsafe integers
## (abs >= 9007199254740992 for integer-valued numbers), nonzero numeric underflow,
## raw control characters, escaped U+0000, and non-canonical whitespace.

const SAFE_INT_LIMIT: float = 9007199254740992.0
const SAFE_INT_LIMIT_STR: String = "9007199254740992"

var _text: String = ""
var _length: int = 0
var _pos: int = 0
var _max_depth: int = 64
## Exact source text of the top-level "schema_version" value ("" when absent).
var _schema_version_token: String = ""
## False when any syntactically valid number violates the schema-1 numeric rules.
## Such numbers do not stop the syntax scan.
var _numbers_valid: bool = true


static func accepts(text: String, max_depth: int = 64) -> bool:
	return inspect(text, max_depth)["accepted"]


## Strictly validates text and also reports the exact raw token of the top-level
## "schema_version" member, since native JSON rounds e.g. 1.00000000000000001 to 1.
## Returns {"accepted": bool, "schema_version_token": String, "numbers_valid": bool}.
## "accepted" reflects syntax only; "numbers_valid" is false when a well-formed number
## fails the schema-1 numeric rules (unsafe integer, non-finite, nonzero underflow).
static func inspect(text: String, max_depth: int = 64) -> Dictionary:
	if text == null:
		return {"accepted": false, "schema_version_token": "", "numbers_valid": false}
	var parser := StrictProfileJson.new()
	var accepted: bool = parser._validate(text, max_depth)
	return {
		"accepted": accepted,
		"schema_version_token": parser._schema_version_token if accepted else "",
		"numbers_valid": parser._numbers_valid if accepted else false,
	}


func _validate(text: String, max_depth: int) -> bool:
	if max_depth < 1:
		return false
	_text = text
	_length = text.length()
	_pos = 0
	_max_depth = max_depth
	_schema_version_token = ""
	_numbers_valid = true

	_skip_whitespace()
	if _pos >= _length:
		return false

	if not _parse_value(1):
		return false

	_skip_whitespace()
	return _pos == _length


func _skip_whitespace() -> void:
	while _pos < _length:
		var c := _text.unicode_at(_pos)
		if c == 0x20 or c == 0x09 or c == 0x0A or c == 0x0D:
			_pos += 1
		else:
			break


func _parse_value(depth: int) -> bool:
	if depth > _max_depth:
		return false
	_skip_whitespace()
	if _pos >= _length:
		return false

	var c := _text.unicode_at(_pos)
	if c == 0x7B: # '{'
		return _parse_object(depth)
	elif c == 0x5B: # '['
		return _parse_array(depth)
	elif c == 0x22: # '"'
		return _scan_string()
	elif c == 0x2D or (c >= 0x30 and c <= 0x39): # '-' or '0'..'9'
		return _scan_number()
	elif c == 0x74: # 't' (true)
		if _pos + 4 <= _length and _text.substr(_pos, 4) == "true":
			_pos += 4
			return true
		return false
	elif c == 0x66: # 'f' (false)
		if _pos + 5 <= _length and _text.substr(_pos, 5) == "false":
			_pos += 5
			return true
		return false
	elif c == 0x6E: # 'n' (null)
		if _pos + 4 <= _length and _text.substr(_pos, 4) == "null":
			_pos += 4
			return true
		return false

	return false


func _parse_object(depth: int) -> bool:
	_pos += 1 # Skip '{'
	_skip_whitespace()
	if _pos >= _length:
		return false
	if _text.unicode_at(_pos) == 0x7D: # '}'
		_pos += 1
		return true

	var seen_keys: Dictionary = {}

	while _pos < _length:
		_skip_whitespace()
		if _pos >= _length or _text.unicode_at(_pos) != 0x22: # '"'
			return false

		var key_start := _pos
		if not _scan_string():
			return false
		var key_len := _pos - key_start
		var key_slice := _text.substr(key_start, key_len)

		var decoded = JSON.parse_string(key_slice)
		if typeof(decoded) != TYPE_STRING:
			return false
		if seen_keys.has(decoded):
			return false
		seen_keys[decoded] = true

		_skip_whitespace()
		if _pos >= _length or _text.unicode_at(_pos) != 0x3A: # ':'
			return false
		_pos += 1 # Skip ':'
		_skip_whitespace()
		var value_start := _pos

		if depth >= _max_depth:
			return false
		if not _parse_value(depth + 1):
			return false
		if depth == 1 and decoded == "schema_version":
			_schema_version_token = _text.substr(value_start, _pos - value_start)

		_skip_whitespace()
		if _pos >= _length:
			return false
		var next_c := _text.unicode_at(_pos)
		if next_c == 0x7D: # '}'
			_pos += 1
			return true
		elif next_c == 0x2C: # ','
			_pos += 1
		else:
			return false

	return false


func _parse_array(depth: int) -> bool:
	_pos += 1 # Skip '['
	_skip_whitespace()
	if _pos >= _length:
		return false
	if _text.unicode_at(_pos) == 0x5D: # ']'
		_pos += 1
		return true

	while _pos < _length:
		if depth >= _max_depth:
			return false
		if not _parse_value(depth + 1):
			return false

		_skip_whitespace()
		if _pos >= _length:
			return false
		var next_c := _text.unicode_at(_pos)
		if next_c == 0x5D: # ']'
			_pos += 1
			return true
		elif next_c == 0x2C: # ','
			_pos += 1
		else:
			return false

	return false


func _scan_string() -> bool:
	_pos += 1 # Skip opening '"'

	while _pos < _length:
		var c := _text.unicode_at(_pos)

		if c < 0x20:
			# Raw control characters are forbidden
			return false
		elif c == 0x22: # '"'
			_pos += 1
			return true
		elif c == 0x5C: # '\'
			_pos += 1
			if _pos >= _length:
				return false
			var esc := _text.unicode_at(_pos)
			_pos += 1

			if esc == 0x22 or esc == 0x5C or esc == 0x2F or esc == 0x62 or esc == 0x66 or esc == 0x6E or esc == 0x72 or esc == 0x74:
				# ", \, /, b, f, n, r, t
				continue
			elif esc == 0x75: # 'u'
				var code_unit := _parse_hex4()
				if code_unit < 0:
					return false
				if code_unit == 0:
					# Reject escaped U+0000
					return false

				if code_unit >= 0xD800 and code_unit <= 0xDBFF:
					# High surrogate, must be immediately followed by '\u' and low surrogate
					if _pos + 2 > _length:
						return false
					if _text.unicode_at(_pos) != 0x5C or _text.unicode_at(_pos + 1) != 0x75:
						return false
					_pos += 2
					var low_unit := _parse_hex4()
					if low_unit < 0:
						return false
					if low_unit < 0xDC00 or low_unit > 0xDFFF:
						return false
				elif code_unit >= 0xDC00 and code_unit <= 0xDFFF:
					# Unpaired low surrogate
					return false
			else:
				return false
		elif c >= 0xD800 and c <= 0xDFFF:
			# Raw unescaped surrogate code points are invalid
			return false
		else:
			_pos += 1

	return false


func _parse_hex4() -> int:
	if _pos + 4 > _length:
		return -1
	var val := 0
	for i in range(4):
		var hc := _text.unicode_at(_pos + i)
		var digit := -1
		if hc >= 0x30 and hc <= 0x39: # 0-9
			digit = hc - 0x30
		elif hc >= 0x41 and hc <= 0x46: # A-F
			digit = hc - 0x41 + 10
		elif hc >= 0x61 and hc <= 0x66: # a-f
			digit = hc - 0x61 + 10
		else:
			return -1
		val = (val << 4) | digit
	_pos += 4
	return val


func _scan_number() -> bool:
	var start_pos := _pos

	# Optional minus sign
	if _pos < _length and _text.unicode_at(_pos) == 0x2D: # '-'
		_pos += 1

	if _pos >= _length:
		return false

	var c := _text.unicode_at(_pos)
	if c == 0x30: # '0'
		_pos += 1
		# Reject leading zero followed by digit
		if _pos < _length:
			var next_c := _text.unicode_at(_pos)
			if next_c >= 0x30 and next_c <= 0x39:
				return false
	elif c >= 0x31 and c <= 0x39: # '1'..'9'
		_pos += 1
		while _pos < _length:
			var digit_c := _text.unicode_at(_pos)
			if digit_c >= 0x30 and digit_c <= 0x39:
				_pos += 1
			else:
				break
	else:
		return false

	# Optional fractional part
	if _pos < _length and _text.unicode_at(_pos) == 0x2E: # '.'
		_pos += 1
		if _pos >= _length:
			return false
		var fc := _text.unicode_at(_pos)
		if fc < 0x30 or fc > 0x39:
			return false
		_pos += 1
		while _pos < _length:
			var frac_c := _text.unicode_at(_pos)
			if frac_c >= 0x30 and frac_c <= 0x39:
				_pos += 1
			else:
				break

	# Optional exponent part
	if _pos < _length:
		var exp_char := _text.unicode_at(_pos)
		if exp_char == 0x65 or exp_char == 0x45: # 'e' or 'E'
			_pos += 1
			if _pos < _length:
				var sign_char := _text.unicode_at(_pos)
				if sign_char == 0x2B or sign_char == 0x2D: # '+' or '-'
					_pos += 1
			if _pos >= _length:
				return false
			var ec := _text.unicode_at(_pos)
			if ec < 0x30 or ec > 0x39:
				return false
			_pos += 1
			while _pos < _length:
				var exp_digit := _text.unicode_at(_pos)
				if exp_digit >= 0x30 and exp_digit <= 0x39:
					_pos += 1
				else:
					break

	var num_str := _text.substr(start_pos, _pos - start_pos)
	if not _validate_number(num_str):
		_numbers_valid = false
	return true


func _validate_number(num_str: String) -> bool:
	var f := num_str.to_float()
	if not is_finite(f) or is_nan(f) or is_inf(f):
		return false

	# Underflow check: mantissa contains non-zero digit but parsed float is 0.0
	var exp_pos := num_str.find("e")
	if exp_pos == -1:
		exp_pos = num_str.find("E")
	var mantissa := num_str if exp_pos == -1 else num_str.substr(0, exp_pos)

	var mantissa_has_nonzero := false
	for i in range(mantissa.length()):
		var mc := mantissa.unicode_at(i)
		if mc >= 0x31 and mc <= 0x39: # '1'..'9'
			mantissa_has_nonzero = true
			break

	if mantissa_has_nonzero and f == 0.0:
		return false

	# Integer-valued numbers safe range check: reject abs >= 9007199254740992
	var has_dot := num_str.find(".") != -1
	var has_exp := exp_pos != -1

	if not has_dot and not has_exp:
		# Syntactic integer
		var digits := num_str
		if digits.begins_with("-"):
			digits = digits.substr(1)
		if digits.length() > 16:
			return false
		if digits.length() == 16 and digits >= SAFE_INT_LIMIT_STR:
			return false

	if f == floor(f) and abs(f) >= SAFE_INT_LIMIT:
		return false

	return true
