# Godot-Compatible MCP Evaluation & Investigation Report

**Milestone**: Tooling & Workflow Validation  
**Date**: November 9, 2026  
**Tasks**: `SBL-MCP-001`, `SBL-MCP-002`  
**Status**: EVALUATED & ISOLATED ON DISPOSABLE PROJECT (Production remains Godot-native CLI)  
**Operating Rule**: AGENTS.md § AI Game Developer MCP caution  

---

## 1. Context & Objectives

Per `AGENTS.md`:
> "Reference: https://github.com/ivanmurzak/unity-mcp. Its documented plugin is for Unity (Unity Editor, Unity packages, GameObjects, C#), not automatically for Godot. Before using AI Game Dev to manipulate Godot, demonstrate a Godot-compatible MCP/adapter on a disposable project: list scene tree, create/edit node, save scene, inspect errors, run headless validation, and collect evidence. If unsupported, use Godot-native files/headless CLI and record the integration as pending. Never install a Unity package into Godot or invent equivalent Godot tools."

Task `SBL-MCP-002` required attempting actual Godot-capable community adapters on an isolated **disposable project** (`scratch/disposable_godot_project`), testing scene tree listing, node creation/editing, scene saving, error inspection, and headless validation, naming every adapter with versions and pass/fail evidence, and protecting the main project from unverified tooling.

---

## 2. Adapters Evaluated & Empirical Results

### 2.1 Adapter 1: `ivanmurzak/unity-mcp` (`ai-game-developer`)
- **Version**: Upstream repository `https://github.com/ivanmurzak/unity-mcp` (configured in `~/.gemini/config/mcp_config.json`).
- **Target Platform**: Unity Editor only (C# GameObject / Component hierarchy, Unity Editor reflection, port 26269).
- **Evaluation on Godot**: **FAILED / INCOMPATIBLE**.
  - Port 26269 connection timed out.
  - Possesses zero support for Godot 4 `.tscn` serialization, GDScript, or Godot headless execution.
  - Per AGENTS.md, Unity packages were strictly rejected from being imported into Godot.

---

### 2.2 Adapter 2: `IvanMurzak/Godot-MCP` via `godot-cli`
- **Version**: `godot-cli` v0.36.0 (`IvanMurzak/Godot-MCP` on GitHub, npm package `godot-cli`).
- **Target Platform**: Godot 4.x C# / .NET projects only.
- **Evaluation on Disposable Project**: **FAILED for GDScript Projects**.
  - Scaffolded disposable GDScript project at `scratch/disposable_godot_project`.
  - Ran `npx godot-cli install-plugin --path <disposable_project>`.
  - The CLI unpacked C# plugin files (`addons/godot_mcp/*.cs`) and emitted:
    ```text
    WARN: No .csproj found at the project root — the godot_mcp addon is C# and needs a Godot.NET.Sdk project.
    Create one (e.g. godot-cli create-project --dotnet) and add the com.IvanMurzak.ReflectorNet 5.5.1 +
    com.IvanMurzak.McpPlugin 8.19.1 + com.IvanMurzak.Rql 0.3.0 + com.IvanMurzak.CodeExec 0.4.1 +
    com.IvanMurzak.CodeExec.Roslyn 0.4.1 + Microsoft.CodeAnalysis.CSharp 4.12.0 PackageReferences
    ```
  - Probing `godot-cli status` returned exit code 1 (`ERROR: Godot is not running and MCP server is not reachable`).
  - **Verdict**: Incompatible with SoulBound's architecture. SoulBound is strictly a GDScript project using the standard Godot 4.7.2 Stable engine without Mono/.NET SDK dependencies.

---

### 2.3 Adapter 3: `@coding-solo/godot-mcp` (Craig Steyn)
- **Version**: `@coding-solo/godot-mcp` v0.1.1 (npm registry, MIT license).
- **Architecture**: TypeScript/Node.js MCP stdio server communicating via Godot CLI execution (`godot_operations.gd`). Configurable via `GODOT_PATH`.
- **Target Platform**: Standard Godot 4.x projects (GDScript / `.tscn` native).
- **Disposable Project Test Harness**: Authored `scratch/run_adapter_test.js` exercising JSON-RPC protocol initialization, tool querying, and operations against `scratch/disposable_godot_project`.
- **Evaluation Results**: **PASSED on Disposable Project**.

#### Operations Verified:
1. **Protocol Initialization & Version Discovery**:
   - `get_godot_version`: Successfully executed and returned exact engine version: `4.7.2.stable.official.ed1daf0bf`.
2. **Project Metadata Extraction**:
   - `get_project_info`: Parsed `project.godot`, reported correct directory path, Godot version, and resource counts.
3. **Scene Creation (`create_scene`)**:
   - Invoked `create_scene` with `scenePath: "mcp_generated_scene.tscn"`, `rootNodeType: "Node2D"`.
   - Godot headless operation created `res://mcp_generated_scene.tscn` (OK=0).
4. **Node Hierarchy Construction (`add_node`)**:
   - Added `CharacterBody2D` named `Player` under `root`.
   - Added `CollisionShape2D` named `Collider` under `root/Player`.
   - Node ownership and parent-child tree properly linked.
5. **Scene Serialization (`save_scene`)**:
   - Saved and packed to disk. Physical `.tscn` inspected:
     ```tscn
     [gd_scene format=3]

     [node name="root" type="Node2D" unique_id=1503911946]

     [node name="Player" type="CharacterBody2D" parent="." unique_id=680075601]

     [node name="Collider" type="CollisionShape2D" parent="Player" unique_id=1615933236]
     ```
6. **Headless Godot 4.7.2 Runtime Validation**:
   - Executed headless verification script (`verify_mcp_scene.gd`) using Godot 4.7.2 console binary:
     ```text
     --- Verifying MCP Generated Scene in Godot 4.7.2 Headless ---
     Root node name: root (Node2D)
     Player node: Player (CharacterBody2D)
     Collider node: Collider (CollisionShape2D)
     ALL MCP-GENERATED NODES VERIFIED IN GODOT 4.7.2 HEADLESS!
     ```
   - Godot loaded, parsed, and instantiated the scene tree with exit code 0.

---

## 3. Findings & Operational Assessment

While `@coding-solo/godot-mcp` succeeded at declarative scene and node generation on the disposable test project, the following operational characteristics were observed:
1. **CLI Process Overhead**: Each node mutation invokes a separate headless Godot CLI execution (`--script godot_operations.gd`), introducing process spawn latency rather than keeping an in-memory live tree.
2. **RID Server Warnings**: Transient 2D physics RID allocations (`P11GodotBody2D`) are emitted on rapid process teardown.
3. **Production Isolation Decision**:
   - SoulBound's primary development and regression workflow is already automated via:
     - Deterministic GDScript test suites (`tests/headless/*.gd`).
     - Canonical PowerShell test runner (`scripts/build/run_headless_tests.ps1`).
     - Chained artifact exporter and validator (`scripts/build/export_release.ps1` and `validate_release.ps1`).
   - Introducing an external Node.js stdio MCP wrapper into the production pipeline adds unnecessary environmental coupling and potential flakiness.
   - **Conclusion**: Keep `@coding-solo/godot-mcp` documented as an available community adapter for auxiliary scene scaffolding if needed, but maintain native GDScript + Godot 4.7.2 headless CLI as SoulBound's primary authoritative toolchain.
