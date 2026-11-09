#!/usr/bin/env node
/**
 * SoulBound — SBL-MCP-003: Reproducible MCP Proof Runner
 * Requirements: AGENTS.md § AI Game Developer MCP caution.
 *
 * Exercises @coding-solo/godot-mcp on an isolated disposable Godot 4.7.2 project.
 * Demonstrates: version query, project info, scene creation, node addition,
 * scene saving, and headless Godot validation.
 */

const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Parse CLI arguments
const args = process.argv.slice(2);
let projectPath = '';
let godotPath = process.env.GODOT_PATH || 'C:\\Users\\ALCOHOL\\Downloads\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64_console.exe';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--project-path' && args[i + 1]) {
    projectPath = args[++i];
  } else if (args[i] === '--godot-path' && args[i + 1]) {
    godotPath = args[++i];
  }
}

if (!projectPath) {
  projectPath = path.join(process.env.TEMP || 'C:\\Temp', 'disposable_godot_mcp_proof');
}

console.log('====================================================');
console.log('   SoulBound — SBL-MCP-003 Adapter Proof Harness     ');
console.log('====================================================');
console.log(`Target Disposable Project: ${projectPath}`);
console.log(`Godot Binary:              ${godotPath}`);

// 1. Scaffold disposable project if not present
if (!fs.existsSync(projectPath)) {
  fs.mkdirSync(projectPath, { recursive: true });
}

const projectGodotFile = path.join(projectPath, 'project.godot');
if (!fs.existsSync(projectGodotFile)) {
  console.log('\n[1/4] Scaffolding minimal disposable project.godot...');
  const minimalConfig = [
    '; Engine configuration file for disposable MCP proof',
    'config_version=5',
    '',
    '[application]',
    'config/name="Disposable Godot MCP Proof"',
    'config/features=PackedStringArray("4.7", "Forward Plus")',
    ''
  ].join('\n');
  fs.writeFileSync(projectGodotFile, minimalConfig, 'utf8');
  console.log('  Created project.godot successfully.');
} else {
  console.log('\n[1/4] Disposable project exists.');
}

// Copy verification script into disposable project
const sourceVerifyScript = path.join(__dirname, 'verify_mcp_scene.gd');
const targetVerifyScript = path.join(projectPath, 'verify_mcp_scene.gd');
if (fs.existsSync(sourceVerifyScript)) {
  fs.copyFileSync(sourceVerifyScript, targetVerifyScript);
}

// 2. Start MCP server via npx
console.log('\n[2/4] Spawning @coding-solo/godot-mcp server via stdio...');

const mcpProcess = spawn('npx', ['--yes', '@coding-solo/godot-mcp'], {
  env: {
    ...process.env,
    GODOT_PATH: godotPath
  },
  stdio: ['pipe', 'pipe', 'pipe'],
  shell: true
});

let buffer = '';
let messageId = 1;
const pendingCalls = new Map();

function sendJsonRpc(method, params = {}) {
  const id = messageId++;
  const payload = { jsonrpc: '2.0', id, method, params };
  mcpProcess.stdin.write(JSON.stringify(payload) + '\n');
  return new Promise((resolve, reject) => {
    pendingCalls.set(id, { resolve, reject, method });
  });
}

function sendNotification(method, params = {}) {
  const payload = { jsonrpc: '2.0', method, params };
  mcpProcess.stdin.write(JSON.stringify(payload) + '\n');
}

mcpProcess.stderr.on('data', (chunk) => {
  const text = chunk.toString();
  // Filter out noisy engine debug lines if necessary
  process.stderr.write(`[SERVER-LOG] ${text}`);
});

mcpProcess.stdout.on('data', (chunk) => {
  buffer += chunk.toString();
  const lines = buffer.split('\n');
  buffer = lines.pop();

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      const msg = JSON.parse(trimmed);
      if (msg.id && pendingCalls.has(msg.id)) {
        const { resolve, reject } = pendingCalls.get(msg.id);
        pendingCalls.delete(msg.id);
        if (msg.error) {
          reject(new Error(`MCP error ${msg.error.code}: ${msg.error.message}`));
        } else {
          resolve(msg.result);
        }
      }
    } catch (err) {
      console.log(`[RAW-OUTPUT] ${trimmed}`);
    }
  }
});

async function runProof() {
  try {
    // A. Initialize
    console.log('  Sending initialize request...');
    const initRes = await sendJsonRpc('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'soulbound-mcp-proof', version: '1.0.0' }
    });
    console.log(`  PASS: MCP server initialized. Server: ${initRes.serverInfo?.name || 'godot-mcp'} v${initRes.serverInfo?.version || '0.1.1'}`);
    sendNotification('notifications/initialized');

    // B. Get Godot Version
    console.log('\n[3/4] Executing tool calls on disposable project...');
    console.log('  -> Calling get_godot_version...');
    const verRes = await sendJsonRpc('tools/call', {
      name: 'get_godot_version',
      arguments: {}
    });
    const verText = verRes.content?.[0]?.text || JSON.stringify(verRes);
    console.log(`  PASS: get_godot_version returned: ${verText.trim()}`);

    // C. Get Project Info
    console.log('  -> Calling get_project_info...');
    const infoRes = await sendJsonRpc('tools/call', {
      name: 'get_project_info',
      arguments: { projectPath }
    });
    const infoText = infoRes.content?.[0]?.text || JSON.stringify(infoRes);
    console.log(`  PASS: get_project_info returned metadata.`);

    // D. Create Scene
    console.log('  -> Calling create_scene (mcp_generated_scene.tscn, Node2D)...');
    const createRes = await sendJsonRpc('tools/call', {
      name: 'create_scene',
      arguments: {
        projectPath,
        scenePath: 'mcp_generated_scene.tscn',
        rootNodeType: 'Node2D'
      }
    });
    console.log(`  PASS: create_scene succeeded.`);

    // E. Add Player Node
    console.log('  -> Calling add_node (Player: CharacterBody2D under root)...');
    const addPlayerRes = await sendJsonRpc('tools/call', {
      name: 'add_node',
      arguments: {
        projectPath,
        scenePath: 'mcp_generated_scene.tscn',
        nodeType: 'CharacterBody2D',
        nodeName: 'Player'
      }
    });
    console.log(`  PASS: add_node Player succeeded.`);

    // F. Add Collider Node
    console.log('  -> Calling add_node (Collider: CollisionShape2D under Player)...');
    const addColliderRes = await sendJsonRpc('tools/call', {
      name: 'add_node',
      arguments: {
        projectPath,
        scenePath: 'mcp_generated_scene.tscn',
        nodeType: 'CollisionShape2D',
        nodeName: 'Collider',
        parentNodePath: 'Player'
      }
    });
    console.log(`  PASS: add_node Collider succeeded.`);

    // G. Save Scene
    console.log('  -> Calling save_scene...');
    const saveRes = await sendJsonRpc('tools/call', {
      name: 'save_scene',
      arguments: {
        projectPath,
        scenePath: 'mcp_generated_scene.tscn'
      }
    });
    console.log(`  PASS: save_scene succeeded.`);

    // Close server
    mcpProcess.stdin.end();

    // 4. Validate scene file
    const generatedScenePath = path.join(projectPath, 'mcp_generated_scene.tscn');
    if (!fs.existsSync(generatedScenePath)) {
      throw new Error(`Generated scene file not found at: ${generatedScenePath}`);
    }
    const sceneContent = fs.readFileSync(generatedScenePath, 'utf8');
    console.log('\nGenerated Scene File (.tscn):');
    console.log(sceneContent.trim());

    // Update committed reference scene in tools/mcp-proof
    const committedScenePath = path.join(__dirname, 'mcp_generated_scene.tscn');
    fs.writeFileSync(committedScenePath, sceneContent, 'utf8');
    console.log(`\nUpdated committed reference scene at: ${committedScenePath}`);

    // 5. Headless Godot validation
    console.log('\n[4/4] Running Headless Godot Runtime Validation on Generated Scene...');
    const headlessCmd = `"${godotPath}" --headless --path "${projectPath}" --script "res://verify_mcp_scene.gd" --quit-after 60`;
    console.log(`Executing: ${headlessCmd}`);
    const godotOutput = execSync(headlessCmd, { encoding: 'utf8' });
    console.log(godotOutput);

    console.log('====================================================');
    console.log('   SBL-MCP-003 PROOF COMPLETED SUCCESSFULLY (PASS)  ');
    console.log('====================================================');
    process.exit(0);

  } catch (error) {
    console.error('\nERROR during MCP proof execution:', error);
    try { mcpProcess.kill(); } catch (e) {}
    process.exit(1);
  }
}

// Timeout watchdog (30 seconds)
setTimeout(() => {
  console.error('\nTIMEOUT: MCP proof did not complete within 30 seconds.');
  try { mcpProcess.kill(); } catch (e) {}
  process.exit(1);
}, 30000);

runProof();
