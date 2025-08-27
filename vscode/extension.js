const vscode = require("vscode");
const cp = require("child_process");
const fs = require("fs");
const path = require("path");

let outputChannel;
function getOutputChannel() {
  if (!outputChannel) {
    outputChannel = vscode.window.createOutputChannel("KDE Helper");
  }
  return outputChannel;
}

function runInLoginTerminal(command, title = "KDE") {
  const oc = getOutputChannel();
  oc.appendLine("");
  oc.appendLine(`[terminal:new] ${title}`);
  oc.appendLine(`[terminal:cmd] ${command}`);
  const terminal = vscode.window.createTerminal({
    name: title,
    cwd: getWorkspacePath(),
    shellPath: process.env.SHELL || "/bin/bash",
    shellArgs: ["-l"],
  });
  terminal.show();
  terminal.sendText(command);
}

function getWorkspacePath() {
  return vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || process.cwd();
}

function runInTerminal(command) {
  // 檢查是否有同名的終端機存在，若有則重新使用，否則建立新的
  const oc = getOutputChannel();
  let terminal = vscode.window.terminals.find((t) => t.name === "KDE");
  if (!terminal) {
    terminal = vscode.window.createTerminal("KDE");
    oc.appendLine(`[terminal:new] KDE`);
    oc.appendLine(`[terminal:cmd] ${command}`);
  }
  oc.appendLine(`[terminal:show] ${terminal.name}`);

  // 顯示終端機視窗
  terminal.show();
  // 將要執行的指令文字發送到終端機
  terminal.sendText(command);
}

function execCommand(command) {
  return new Promise((resolve, reject) => {
    const cwd = getWorkspacePath();
    const oc = getOutputChannel();
    oc.appendLine("");
    oc.appendLine(`$ ${command}`);
    oc.appendLine(`cwd: ${cwd}`);
    cp.exec(command, { cwd }, (err, stdout, stderr) => {
      if (err) {
        const message = (stderr && stderr.toString().trim()) || err.message;
        oc.appendLine(`[error] ${message}`);
        reject(message);
      } else {
        const out = stdout ? stdout.toString().trim() : "";
        if (out) {
          oc.appendLine(out);
        }
        resolve(out);
      }
    });
  });
}

function getCurrentEnv() {
  try {
    const content = fs.readFileSync(
      path.join(getWorkspacePath(), "current.env"),
      "utf8"
    );
    const match = content.match(/CUR_ENV=(.*)/);
    return match ? match[1].trim() : undefined;
  } catch {
    return undefined;
  }
}

class EnvironmentItem extends vscode.TreeItem {
  constructor(name, isCurrent) {
    super(
      `${name}${isCurrent ? " (使用中)" : ""}`,
      vscode.TreeItemCollapsibleState.Collapsed
    );
    this.contextValue = "environment";
    this.envName = name;
  }
}

class ProjectItem extends vscode.TreeItem {
  constructor(envName, name) {
    super(name, vscode.TreeItemCollapsibleState.None);
    this.contextValue = "project";
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
    const oc = getOutputChannel();
    if (!element) {
      try {
        const output = await execCommand("kde ls");
        const envs = output.split(/\r?\n/).filter(Boolean);
        const current = getCurrentEnv();
        return envs.map((e) => new EnvironmentItem(e, e === current));
      } catch {
        return [];
      }
    }
    oc.appendLine(`[getChildren] ${element?.envName ?? "<undefined>"}`);
    if (element instanceof EnvironmentItem) {
      oc.appendLine(`[getChildren] ${element.envName}`);
      return vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Window,
          title: `載入專案 (${element.envName})`,
        },
        async () => {
          // 先嘗試使用可能存在的 --env 旗標，不行則退回先切換環境再列出
          try {
            oc.appendLine(`[getChildren] ${element.envName} --env`);
            const output = await execCommand(
              `kde project ls --env ${element.envName}`
            );
            const names = output.split(/\r?\n/).filter(Boolean);
            return names.map((name) => new ProjectItem(element.envName, name));
          } catch (err1) {
            try {
              oc.appendLine(`[getChildren] ${element.envName} --use`);
              const output = await execCommand(
                `kde use ${element.envName} && kde project ls`
              );
              const names = output.split(/\r?\n/).filter(Boolean);
              return names.map(
                (name) => new ProjectItem(element.envName, name)
              );
            } catch (err2) {
              vscode.window.showErrorMessage(
                `無法載入專案 (${element.envName})：${err2}`
              );
              return [];
            }
          }
        }
      );
    }
    return [];
  }

  getTreeItem(element) {
    return element;
  }
}

function activate(context) {
  const oc = getOutputChannel();
  oc.appendLine("KDE Helper activated");
  const provider = new KDETreeProvider();
  const treeView = vscode.window.createTreeView("kdeEnvView", {
    treeDataProvider: provider,
  });
  context.subscriptions.push(
    treeView,
    vscode.commands.registerCommand("kde.startEnv", (item) => {
      oc.appendLine(`[invoke] kde.startEnv ${item?.envName ?? "<undefined>"}`);
      runInTerminal(`kde start ${item.envName}`);
    }),
    vscode.commands.registerCommand("kde.useEnv", (item) => {
      oc.appendLine(`[invoke] kde.useEnv ${item?.envName ?? "<undefined>"}`);
      runInTerminal(`kde use ${item.envName}`);
      provider.refresh();
    }),
    vscode.commands.registerCommand("kde.k9s", async (item) => {
      let envName = item && item.envName;
      if (!envName && treeView.selection && treeView.selection[0]) {
        envName = treeView.selection[0].envName;
      }
      oc.appendLine(`[invoke] kde.k9s ${envName || "<undefined>"}`);
      if (!envName) {
        try {
          const output = await execCommand("kde ls");
          const envs = output.split(/\r?\n/).filter(Boolean);
          envName = await vscode.window.showQuickPick(envs, {
            placeHolder: "選擇要開啟 K9s 的環境",
          });
        } catch (e) {
          vscode.window.showErrorMessage(`讀取環境清單失敗：${e}`);
          return;
        }
      }
      if (!envName) {
        return;
      }
      vscode.window.showInformationMessage(`啟動 K9s：${envName}`);
      runInLoginTerminal(
        `kde use ${envName} && kde k9s`,
        `KDE: k9s (${envName})`
      );
    }),
    vscode.commands.registerCommand("kde.headlamp", async (item) => {
      let envName = item && item.envName;
      if (!envName && treeView.selection && treeView.selection[0]) {
        envName = treeView.selection[0].envName;
      }
      oc.appendLine(`[invoke] kde.headlamp ${envName || "<undefined>"}`);
      if (!envName) {
        try {
          const output = await execCommand("kde ls");
          const envs = output.split(/\r?\n/).filter(Boolean);
          envName = await vscode.window.showQuickPick(envs, {
            placeHolder: "選擇要開啟 Headlamp 的環境",
          });
        } catch (e) {
          vscode.window.showErrorMessage(`讀取環境清單失敗：${e}`);
          return;
        }
      }
      if (!envName) {
        return;
      }
      vscode.window.showInformationMessage(`啟動 Headlamp：${envName}`);
      runInLoginTerminal(
        `kde use ${envName} && kde headlamp`,
        `KDE: headlamp (${envName})`
      );
    }),
    vscode.commands.registerCommand("kde.project.deploy", (item) =>
      runInTerminal(
        `kde use ${item.envName} && kde project deploy ${item.projectName}`
      )
    ),
    vscode.commands.registerCommand("kde.project.undeploy", (item) =>
      runInTerminal(
        `kde use ${item.envName} && kde project undeploy ${item.projectName}`
      )
    ),
    vscode.commands.registerCommand("kde.project.redeploy", (item) =>
      runInTerminal(
        `kde use ${item.envName} && kde project redeploy ${item.projectName}`
      )
    )
  );

  // TreeView debug logs
  const selDisp = treeView.onDidChangeSelection((e) => {
    const names = e.selection
      .map((i) => i && (i.envName || i.projectName || i.label))
      .join(", ");
    oc.appendLine(`[selection] ${names}`);
  });
  const visDisp = treeView.onDidChangeVisibility((e) => {
    oc.appendLine(`[visibility] kdeEnvView visible=${e.visible}`);
  });
  context.subscriptions.push(selDisp, visDisp);
  oc.appendLine(`[activate] ${context.subscriptions.length} subscriptions`);
}

function deactivate() {}

module.exports = { activate, deactivate };
