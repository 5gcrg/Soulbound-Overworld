# AI Game Developer Godot Integration Evaluation

**Date:** 9 November 2026  
**Requested by:** project owner  
**Source:** <https://ai-game.dev/engines/godot>

## Result

**Not installed into SoulBound. Integration is incompatible with the project constraints.**

The published integration requires:

- Godot .NET/Mono rather than the standard build.
- C# and .NET 8.
- Godot 4.3–4.5 according to the engine page.
- `.csproj` edits, NuGet packages, an embedded extension catalog, and an enabled C# editor plugin.

SoulBound requires:

- Godot 4.7.2 Stable.
- GDScript.
- Compatibility renderer.
- Windows portable and single-threaded Web output.
- No unapproved Unity/C#/.NET integration in the project.

Installing `godot_mcp` into the production project would therefore be an
unsupported project mutation and was correctly blocked. No image or other
asset generation was performed.

## Workflow disposition

- Continue implementation with Godot-native files and the Godot 4.7.2
  headless CLI.
- Continue using the existing disposable MCP proof only for adapter evidence;
  it must not become a production dependency.
- A future Godot 4.7.2 standard/GDScript-compatible adapter would require a
  fresh disposable-project proof: list scene tree, create/edit node, save
  scene, inspect errors, run headless validation, and collect evidence before
  any production installation.
- No open decision is resolved by this evaluation. Human release gates remain
  unchanged.

## Evidence

- Existing adapter evaluation: `docs/godot-mcp-evaluation.md`.
- Existing disposable proof: `tools/mcp-proof/run_adapter_proof.js`.
- Project contract: `AGENTS.md` AI Game Developer MCP caution and platform
  invariants.
