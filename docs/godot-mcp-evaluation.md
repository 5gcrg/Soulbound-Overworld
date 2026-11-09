# Godot-Compatible MCP Evaluation & Investigation Report (SBL-MCP-001)

**Milestone**: Tooling & Workflow Validation  
**Date**: November 9, 2026  
**Status**: PENDING (No Godot-compatible MCP adapter available)  
**Operating Rule**: AGENTS.md § AI Game Developer MCP caution  

---

## 1. Context & Objective

Per AGENTS.md:
> "Reference: https://github.com/ivanmurzak/unity-mcp. Its documented plugin is for Unity (Unity Editor, Unity packages, GameObjects, C#), not automatically for Godot. Before using AI Game Dev to manipulate Godot, demonstrate a Godot-compatible MCP/adapter on a disposable project: list scene tree, create/edit node, save scene, inspect errors, run headless validation, and collect evidence. If unsupported, use Godot-native files/headless CLI and record the integration as pending. Never install a Unity package into Godot or invent equivalent Godot tools."

Task `SBL-MCP-001` evaluated the current MCP environment to determine whether a Godot-compatible adapter exists for scene inspection, node creation, scene saving, and error diagnosis, or whether the workflow must remain Godot-native files with headless CLI execution.

---

## 2. Environment Audit & Attempted Adapters

### 2.1 Configured MCP Server: `ai-game-developer`
- **Configuration**: Evaluated `~/.gemini/config/mcp_config.json`:
  ```json
  {
    "mcpServers": {
      "ai-game-developer": {
        "disabled": false,
        "serverUrl": "http://localhost:26269/p/2d78f1e9"
      }
    }
  }
  ```
- **Upstream Repository**: https://github.com/ivanmurzak/unity-mcp
- **Adapter Target**: Unity Editor (requires Unity package `com.ivanmurzak.unity-mcp` loaded into a running Unity project, interacting via C# runtime Reflection and Unity Editor APIs).
- **Endpoint Reachability Check**:
  - Probe to `http://localhost:26269/p/2d78f1e9` timed out (port 26269 is not listening; no Unity editor instance active).
- **Godot Compatibility**: Incompatible. The adapter communicates with Unity C# GameObjects, Components, and Prefabs. It possesses zero support for Godot 4 `res://` scene trees, GDScript, `.tscn` serialization, or Godot headless execution.
- **Rule Adherence**: Per AGENTS.md, Unity packages were not installed into Godot, and no pseudo-adapter was synthesized.

### 2.2 Survey for Godot-Native MCP Adapters
- **System / Repository Check**: Searched system configuration and workspace for alternative Godot MCP bridges (e.g. Godot EditorPlugins exposing MCP over WebSocket or stdio).
- **Result**: No Godot-compatible MCP bridge is currently provisioned, installed, or standardized for Godot 4.7.2 Stable in this development environment.

---

## 3. Decision & Operational Fallback

1. **Integration Status**: Marked as **PENDING** pending development or discovery of a genuine Godot 4.7.2 EditorPlugin / MCP adapter.
2. **Operational Workflow**: As mandated by AGENTS.md, development continues using:
   - **Godot-native declarative scene files (`.tscn`)** and strictly-typed **GDScript (`.gd`)**.
   - **Godot 4.7.2 Stable headless CLI (`--headless --script ...`)** executed via detached PowerShell process management with redirected stdout/stderr for all automated verification.
   - **Automated PowerShell export pipelines (`scripts/build/export_release.ps1`)** for multi-platform releases.
