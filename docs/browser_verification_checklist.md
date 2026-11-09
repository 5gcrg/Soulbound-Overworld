# Web & Browser Verification Checklist — Soulbound (SBL-VER-002)

**Milestone**: M6 & Release Hardening  
**Target Engine**: Godot 4.7.2 Stable (Compatibility Renderer, WebGL 2)  
**Execution Mode**: Single-Threaded WebAssembly (`variant/thread_support = false`)  
**Status**: PENDING HUMAN EXECUTION (No automated headless browser environment available)  

---

## 1. Single-Thread Configuration & Header Audit

### 1.1 Export Preset Flags (`export_presets.cfg`)

The Web export preset `[preset.1]` is audited and verified with the following configuration flags:

| Config Option | Configured Value | Verification / Invariant Requirement | Status |
|---|---|---|---|
| `platform` | `"Web"` | Web platform export target | VERIFIED |
| `export_path` | `"builds/web/index.html"` | Dedicated web build destination directory | VERIFIED |
| `variant/thread_support` | `false` | **Single-threaded WebAssembly build**. Never enable threads for web distribution per AGENTS.md invariant. | VERIFIED |
| `variant/extensions_support` | `false` | GDExtension binaries disabled for minimal binary footprint | VERIFIED |
| `html/canvas_resize_policy` | `2` | Adaptive canvas resize policy matching browser viewport | VERIFIED |
| `html/focus_canvas_on_start` | `true` | Auto-focus canvas upon user interaction | VERIFIED |
| `renderer/rendering_method.web` | `"gl_compatibility"` | WebGL 2 / OpenGL ES 3.0 Compatibility backend | VERIFIED |

### 1.2 Cross-Origin Isolation & COOP / COEP Header Analysis

In Godot 4.x:
- **Multi-threaded builds (`thread_support = true`)**: Require `SharedArrayBuffer` and `Atomics`, which browsers strictly gate behind Cross-Origin Isolation headers:
  - `Cross-Origin-Opener-Policy: same-origin`
  - `Cross-Origin-Embedder-Policy: require-corp`
- **Single-threaded builds (`thread_support = false`)**: Soulbound uses single-threaded WebAssembly execution. **`SharedArrayBuffer` is NOT used**.
  - **Header Requirement**: COOP and COEP headers are **NOT strictly required** for the game loop, canvas rendering, or audio processing.
  - **Deployment Compatibility**: Soulbound single-threaded web builds run cleanly on standard web servers, static hosts (GitHub Pages, GitLab Pages), and iframe-embedded platforms (itch.io) without cross-origin isolation restrictions.
  - **Optional Best-Practice Headers**: When hosting on dedicated servers, serving `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: credentialless` (or `require-corp`) is recommended for defense-in-depth, but failure to serve them does not inhibit the engine.

---

## 2. Browser Smoke Test Checklist

### 2.1 Test Cases

| Case ID | Test Item | Verification Procedure | Expected Outcome |
|---|---|---|---|
| **WEB-SMK-01** | Canvas Load & Engine Init | Navigate to `index.html` in browser. Observe splash and canvas loading progress bar. | Engine loads without WASM compilation errors, WebGL context is initialized, and canvas displays at 960x540 logical resolution. |
| **WEB-SMK-02** | Title Screen & Audio Activation | Wait for Title Screen. Click anywhere or press a key to satisfy browser AudioContext autoplay policy. | Title screen displays "New Game", "Continue", "Settings", "Quit". Procedural audio plays pleasant chime on initial user gesture without console audio exceptions. |
| **WEB-SMK-03** | Profile Selection & IndexedDB Storage | Select "New Game" or choose Profile 1/2/3 from profile selector. | Profile initializes; `user://` data persists to browser IndexedDB/LocalStorage. Refreshing the browser retains saved profile state. |
| **WEB-SMK-04** | Overworld Movement & Keyboard Focus | Move player using WASD and Arrow keys. | Player moves smoothly at 60 FPS across physical frames. Canvas maintains focus without window scrolling. |
| **WEB-SMK-05** | Region Transition | Walk through marked portal from Alpha to Beta region. | Portal signal fires once, transition executes seamlessly, player spawns at valid marker in target region without position desync. |
| **WEB-SMK-06** | Dimension Shift | Press 'Q' to execute dimension shift between Lumina and Umbra. | Dimension swaps synchronously; background palette shifts; collision masks update instantly. |
| **WEB-SMK-07** | Accessibility & Settings | Press 'O' or click Settings button. Toggle Text Scale (1.0x to 1.25x), High Contrast, and Volume sliders. | Text scales dynamically; High Contrast applies pure white text and black shadows; keyboard Tab/Shift-Tab navigates controls in circular order with visible gold focus outline. |
| **WEB-SMK-08** | Backup Export/Import via Text Box | In Settings, click "Export Backup". Copy generated base64 string. Modify state, then paste string into "Import Backup" text field. | String is exported and imported cleanly via browser text input without requiring native desktop file dialogues. |
| **WEB-SMK-09** | CSV Download Stream | Navigate to Assessment / Educator View and click "Export CSV". | Browser triggers file download of `assessment_metrics.csv` via JavaScript blob URL or data URI fallback without popup blocker rejection. |
| **WEB-SMK-10** | Single-Thread Execution Audit | Open browser DevTools (F12) -> Performance / Sources tab. Profile engine frame loop. | Zero Web Workers are spawned for the engine frame cycle. All logic, rendering, and audio execute on the main thread without `SharedArrayBuffer`. |

---

## 3. Browser Execution Evidence Matrix

Per AGENTS.md, results cannot be represented as passed without actual execution evidence. Since headless browser automation (Playwright/Puppeteer) is not provisioned in this CLI environment, execution is recorded as **PENDING HUMAN EXECUTION**.

| Environment | Platform | Test Cases | Execution Status | Notes / Evidence |
|---|---|---|---|---|
| **Google Chrome / Chromium** (Latest Stable) | Windows 10/11 | WEB-SMK-01 through WEB-SMK-10 | **PENDING human execution** | Manual verification required using exported package `dist/Soulbound-Web.zip` or `builds/web/index.html`. |
| **Mozilla Firefox** (Latest Stable) | Windows 10/11 | WEB-SMK-01 through WEB-SMK-10 | **PENDING human execution** | Manual verification required using exported package `dist/Soulbound-Web.zip` or `builds/web/index.html`. |
| **Microsoft Edge** (Chromium) | Windows 10/11 | WEB-SMK-01 through WEB-SMK-10 | **PENDING human execution** | Manual verification required using exported package `dist/Soulbound-Web.zip` or `builds/web/index.html`. |

---

## 4. Instructions for Human Evaluator Verification

1. Unzip `dist/Soulbound-Web.zip` into a local directory.
2. Launch a local HTTP server (browsers restrict WebAssembly and WebGL when run from raw `file://` URIs):
   ```powershell
   # Python HTTP server
   python -m http.server 8000 --directory builds/web
   
   # Or Node.js serve
   # npx serve builds/web
   ```
3. Open `http://localhost:8000` in Google Chrome and Mozilla Firefox.
4. Execute steps `WEB-SMK-01` through `WEB-SMK-10` above and record confirmation.
