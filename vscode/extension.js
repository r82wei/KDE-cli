const vscode = require('vscode');
const cp = require('child_process');
const fs = require('fs');
const path = require('path');

function getWorkspacePath() {
  return vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || process.cwd();
}

function runInTerminal(command) {
  if (!runInTerminal.terminal || runInTerminal.terminal.exitStatus) {
    runInTerminal.terminal = vscode.window.createTerminal('KDE');
  }
  runInTerminal.terminal.show();
  runInTerminal.terminal.sendText(command);
}

function execCommand(command) {
  return new Promise((resolve, reject) => {
    cp.exec(command, { cwd: getWorkspacePath() }, (err, stdout, stderr) => {
      if (err) {
        reject(stderr || err.message);
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

function getCurrentEnv() {
  try {
    const content = fs.readFileSync(path.join(getWorkspacePath(), 'current.env'), 'utf8');
    const match = content.match(/CUR_ENV=(.*)/);
    return match ? match[1].trim() : undefined;
  } catch {
    return undefined;
  }
}

class EnvironmentItem extends vscode.TreeItem {
  constructor(name, isCurrent) {
    super(`${name}${isCurrent ? ' (使用中)' : ''}`, vscode.TreeItemCollapsibleState.Collapsed);
    this.contextValue = 'environment';
    this.envName = name;
  }
}

class ProjectItem extends vscode.TreeItem {
  constructor(envName, name) {
    super(name, vscode.TreeItemCollapsibleState.None);
    this.contextValue = 'project';
    this.envName = envName;
    this.projectName = name;
  }
}

class KDETreeProvider {
  constructor() {
    this._onDidChangeTreeData = new vscode.EventEmitter();
    this.onDidChangeTreeData = this._onDidChangeTreeData.event;
  }

  refresh() {
    this._onDidChangeTreeData.fire();
  }

  async getChildren(element) {
    const workspace = getWorkspacePath();
    if (!element) {
      try {
        const output = await execCommand('kde ls');
        const envs = output.split(/\r?\n/).filter(Boolean);
        const current = getCurrentEnv();
        return envs.map(e => new EnvironmentItem(e, e === current));
      } catch {
        return [];
      }
    }
    if (element instanceof EnvironmentItem) {
      const dir = path.join(workspace, 'environments', element.envName, 'namespaces');
      try {
        const names = fs.readdirSync(dir, { withFileTypes: true })
          .filter(d => d.isDirectory())
          .map(d => d.name);
        return names.map(name => new ProjectItem(element.envName, name));
      } catch {
        return [];
      }
    }
    return [];
  }

  getTreeItem(element) {
    return element;
  }
}

function activate(context) {
  const provider = new KDETreeProvider();
  context.subscriptions.push(
    vscode.window.registerTreeDataProvider('kdeEnvView', provider),
    vscode.commands.registerCommand('kde.startEnv', item => runInTerminal(`kde start ${item.envName}`)),
    vscode.commands.registerCommand('kde.useEnv', item => { runInTerminal(`kde use ${item.envName}`); provider.refresh(); }),
    vscode.commands.registerCommand('kde.k9s', item => runInTerminal(`kde use ${item.envName} && kde k9s`)),
    vscode.commands.registerCommand('kde.headlamp', item => runInTerminal(`kde use ${item.envName} && kde headlamp`)),
    vscode.commands.registerCommand('kde.project.deploy', item => runInTerminal(`kde use ${item.envName} && kde project deploy ${item.projectName}`)),
    vscode.commands.registerCommand('kde.project.undeploy', item => runInTerminal(`kde use ${item.envName} && kde project undeploy ${item.projectName}`)),
    vscode.commands.registerCommand('kde.project.redeploy', item => runInTerminal(`kde use ${item.envName} && kde project redeploy ${item.projectName}`))
  );
}

function deactivate() {}

module.exports = { activate, deactivate };

