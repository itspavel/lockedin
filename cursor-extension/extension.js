// LockedIn Sensor — runs inside Cursor/VS Code and writes a precise activity
// heartbeat the native LockedIn app reads. Gives exact project + file + keystroke
// signal with zero OS permissions, fixing the native app's attribution guesswork.
//
// Privacy: writes paths, language, counters, and timestamps only. Never file content.

const vscode = require('vscode');
const fs = require('fs');
const os = require('os');
const path = require('path');

const HEARTBEAT_DIR = path.join(os.homedir(), 'Library', 'Application Support', 'LockedIn');
const HEARTBEAT_FILE = path.join(HEARTBEAT_DIR, 'editor-heartbeat.json');
const WRITE_INTERVAL_MS = 5000;

let typedTotal = 0;          // characters you actually typed (small edits)
let generatedTotal = 0;      // characters pasted or written by the AI (large inserts)
let lastEditAt = 0;          // epoch ms of last edit
let statusItem;

function activate(context) {
  try { fs.mkdirSync(HEARTBEAT_DIR, { recursive: true }); } catch (_) {}

  statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusItem.text = '$(lock) LockedIn';
  statusItem.tooltip = 'LockedIn is sensing your work';
  statusItem.show();
  context.subscriptions.push(statusItem);

  // Split edits into typed vs generated. A genuine keystroke is a single tiny change,
  // in the file you're actively looking at, while the window is focused. Anything else
  // (multi-change bursts, edits to background files, large inserts) = paste / AI / agent.
  // Lengths only, no content stored.
  context.subscriptions.push(
    vscode.workspace.onDidChangeTextDocument((e) => {
      if (e.document.uri.scheme !== 'file') return;
      const active = vscode.window.activeTextEditor;
      const onActiveDoc = active && e.document === active.document && vscode.window.state.focused;
      const singleChange = e.contentChanges.length === 1;
      let touched = false;
      for (const c of e.contentChanges) {
        const len = c.text.length;
        if (len === 0) continue;
        touched = true;
        if (onActiveDoc && singleChange && len <= 2 && !c.text.includes('\n')) {
          typedTotal += len;          // a real keystroke
        } else {
          generatedTotal += len;      // paste / AI / agent edit
        }
      }
      if (touched) lastEditAt = Date.now();
    })
  );

  // Selection / focus changes also count as "present", just not as keystrokes.
  context.subscriptions.push(
    vscode.window.onDidChangeTextEditorSelection((e) => {
      if (e.textEditor.document.uri.scheme === 'file') lastEditAt = Date.now();
    })
  );

  const timer = setInterval(writeHeartbeat, WRITE_INTERVAL_MS);
  context.subscriptions.push({ dispose: () => clearInterval(timer) });
  writeHeartbeat();
}

function currentProject() {
  const editor = vscode.window.activeTextEditor;
  const doc = editor && editor.document.uri.scheme === 'file' ? editor.document : null;

  // Prefer the workspace folder that owns the active file; fall back to the first folder.
  let folder;
  if (doc) folder = vscode.workspace.getWorkspaceFolder(doc.uri);
  if (!folder && vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length) {
    folder = vscode.workspace.workspaceFolders[0];
  }
  return {
    projectPath: folder ? folder.uri.fsPath : null,
    file: doc ? path.basename(doc.fileName) : null,
    language: doc ? doc.languageId : null,
  };
}

function writeHeartbeat() {
  const idleMs = lastEditAt ? Date.now() - lastEditAt : Infinity;
  const cfg = vscode.workspace.getConfiguration('lockedin');
  const idleCutoff = (cfg.get('idleSeconds') || 120) * 1000;
  const { projectPath, file, language } = currentProject();

  const payload = {
    editor: vscode.env.appName || 'editor',  // "Cursor" / "Visual Studio Code"
    projectPath,
    file,
    language,
    keystrokes: typedTotal,        // back-compat: "keystrokes" == characters you typed
    typed: typedTotal,
    generated: generatedTotal,
    editing: idleMs < idleCutoff && vscode.window.state.focused,
    focused: vscode.window.state.focused,
    ts: new Date().toISOString(),
  };

  const tmp = HEARTBEAT_FILE + '.tmp';
  try {
    fs.writeFileSync(tmp, JSON.stringify(payload));
    fs.renameSync(tmp, HEARTBEAT_FILE);   // atomic swap so the app never reads a half file
  } catch (_) {}
}

function deactivate() {
  try { fs.unlinkSync(HEARTBEAT_FILE); } catch (_) {}
}

module.exports = { activate, deactivate };
