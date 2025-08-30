const vscode = require("vscode");
const cp = require("child_process");
const fs = require("fs");
const path = require("path");

const COMPLETED_MESSAGE = "Please enter any key to continue...";
let outputChannel;
function getOutputChannel() {
  if (!outputChannel) {
    outputChannel = vscode.window.createOutputChannel("k8s-dev-environments");
  }
  return outputChannel;
}

function getWorkspacePath() {
  return vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || process.cwd();
}

// 透過 kde status 取得環境狀態，並回傳一個物件，物件的 key 是環境名稱，value 是環境狀態
async function getEnvironmentStatus() {
  const oc = getOutputChannel();
  const output = await execCommand("kde status json");
  const envs = JSON.parse(output);
  const status = {};
  for (const env of envs) {
    status[env.environment] = env.status;
  }
  oc.appendLine(`[status] ${JSON.stringify(status)}`);
  return status;
}

async function runAsTask(command, taskName = "KDE") {
  return new Promise((resolve, reject) => {
    const task = new vscode.Task(
      { type: "process" },
      vscode.TaskScope.Workspace,
      taskName,
      "kde",
      new vscode.ShellExecution(command)
    );
    // 想要顯示在 Terminal 視窗
    task.presentationOptions = {
      reveal: vscode.TaskRevealKind.Always,
      panel: vscode.TaskPanelKind.Shared,
      clear: false,
      showReuseMessage: false,
    };

    const endDisposable = vscode.tasks.onDidEndTaskProcess((e) => {
      if (e.execution.task === task) {
        endDisposable.dispose();
        resolve(e.exitCode); // 0 表成功
      }
    });

    vscode.tasks.executeTask(task).then(undefined, (err) => {
      endDisposable.dispose();
      reject(err);
    });
  });
}

function runInNewTerminal(command, title = "KDE") {
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
  // 指令結束後自動離開 shell，關閉終端機
  terminal.sendText(`${command}; exit`);
  return terminal;
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

// 顯示環境狀態的圖示
function iconForEnv(status) {
  switch (status) {
    case "RUNNING":
      return new vscode.ThemeIcon(
        "circle-filled",
        new vscode.ThemeColor("testing.iconPassed")
      );
    case "UNREADY":
      // 空心圓 + 淡色
      return new vscode.ThemeIcon(
        "circle-outline",
        new vscode.ThemeColor("disabledForeground")
      );
    case "error":
      return new vscode.ThemeIcon(
        "circle-filled",
        new vscode.ThemeColor("testing.iconFailed")
      );
  }
}

async function createEnvironmentFlow(item) {
  const oc = getOutputChannel();
  oc.appendLine(`[invoke] kde.createEnv ${item?.envName ?? "<undefined>"}`);
  const exitCode = await runAsTask(
    `kde create ${item.envName} && echo "${COMPLETED_MESSAGE}"`
  );
  if (exitCode === 0) {
    provider.refresh();
  } else {
    vscode.window.showErrorMessage(
      `Task create env failed with exit code ${exitCode}`
    );
  }
}

async function addEnvironmentFlow(item) {
  const oc = getOutputChannel();
  const ws = getWorkspacePath();
  if (!ws) return;

  // 1) 環境名稱
  const envName = await vscode.window.showInputBox({
    prompt: "請輸入要建立的環境名稱",
    placeHolder: "例如：dev、staging、prod",
    validateInput: (val) =>
      !/^[a-zA-Z0-9-_]+$/.test(val) ? "環境名稱只能包含字母、數字、-、_" : null,
  });
  oc.appendLine(`[addEnvironmentFlow] ${envName}`);
  if (!envName) return;

  // 2) 環境類型
  const pick = await vscode.window.showQuickPick(
    [
      { label: "kind（本地 Docker 內的 K8s）", val: "kind" },
      { label: "k3d（輕量 K3s on Docker）", val: "k3d" },
      { label: "k8s（連接現有 K8s 叢集）", val: "k8s" },
    ],
    { title: "選擇環境類型", placeHolder: "kind / k3d / k8s" }
  );
  if (!pick) return;
  oc.appendLine(`[addEnvironmentFlow] ${pick.val}`);

  // 3) 類型特定參數（針對 k8s）
  let kubeconfigPath = "";
  if (pick.val === "k8s") {
    const file = await vscode.window.showOpenDialog({
      title: "選擇 kubeconfig 檔",
      canSelectMany: false,
      // filters: { 'kubeconfig': ['yaml', 'yml'] }
    });
    if (!file) return;
    kubeconfigPath = file[0].fsPath;
    oc.appendLine(`[addEnvironmentFlow] ${kubeconfigPath}`);
  }

  // 4) 建立 + 切換
  try {
    // 依你的 kde-cli 參數調整：這裡假設支援 --type
    let exitCode;
    switch (pick.val) {
      case "kind":
        exitCode = await runAsTask(
          `kde init && kde create ${envName} kind && echo "${COMPLETED_MESSAGE}"`,
          `KDE: create env ${envName}`
        );
        break;
      case "k3d":
        exitCode = await runAsTask(
          `kde init && kde create ${envName} k3d && echo "${COMPLETED_MESSAGE}"`,
          `KDE: create env ${envName}`
        );
        break;
      case "k8s":
        exitCode = await runAsTask(
          `kde init && kde create ${envName} k8s ${kubeconfigPath} && echo "${COMPLETED_MESSAGE}"`,
          `KDE: create env ${envName}`
        );
        break;
    }
    if (exitCode === 0) {
      vscode.window.showInformationMessage(
        `已建立環境：${envName}（${pick.val}）`
      );
      provider.refresh();
    } else {
      vscode.window.showErrorMessage(
        `Task create env failed with exit code ${exit}`
      );
    }
  } catch (e) {
    vscode.window.showErrorMessage(`建立環境失敗：${e.message ?? e}`);
  }
}

async function createProjectFlow(item) {
  const oc = getOutputChannel();
  oc.appendLine(`[invoke] kde.createProject ${item?.envName ?? "<undefined>"}`);
  // 跳出輸入框，輸入專案名稱
  const projectName = await vscode.window.showInputBox({
    prompt: "請輸入要建立的專案名稱",
    placeHolder: "例如：my-project",
  });
  if (!projectName) return;
  oc.appendLine(`[createProjectFlow] ${projectName}`);
  const exitCode = await runAsTask(
    `kde project create ${projectName} && echo "${COMPLETED_MESSAGE}"`
  );
  if (exitCode === 0) {
    provider.refresh(item);
  }
}

function refreshEnvironmentsFlow(item) {
  provider.refresh();
}

class EnvironmentItem extends vscode.TreeItem {
  constructor(name, status) {
    super(`${name}`, vscode.TreeItemCollapsibleState.Collapsed);
    const oc = getOutputChannel();
    oc.appendLine(`[EnvironmentItem] ${name} ${status}`);
    this.contextValue = "environment";
    this.envName = name;
    this.iconPath = iconForEnv(status || "UNREADY");
  }
}

class ProjectItem extends vscode.TreeItem {
  constructor(envName, name) {
    super(`${name}`, vscode.TreeItemCollapsibleState.Collapsed);
    this.contextValue = "project";
    this.envName = envName;
    this.projectName = name;
  }
}

class PodItem extends vscode.TreeItem {
  constructor(envName, projectName, podName) {
    super(`${podName}`, vscode.TreeItemCollapsibleState.None);
    this.contextValue = "pod";
    this.envName = envName;
    this.projectName = projectName;
    this.podName = podName;
  }
}

class KDETreeProvider {
  constructor() {
    this._onDidChangeTreeData = new vscode.EventEmitter();
    this.onDidChangeTreeData = this._onDidChangeTreeData.event;
  }

  refresh(element) {
    this._onDidChangeTreeData.fire(element);
  }

  async getChildren(element) {
    const workspace = getWorkspacePath();
    const oc = getOutputChannel();
    if (!element) {
      try {
        const status = await getEnvironmentStatus();
        const output = await execCommand("kde ls");
        const envs = output.split(/\r?\n/).filter(Boolean);
        oc.appendLine(`[getChildren] ${JSON.stringify(envs)}`);
        oc.appendLine(`[status] ${JSON.stringify(status)}`);
        return envs.map((e) => new EnvironmentItem(e, status[e]));
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
          try {
            oc.appendLine(`[getChildren] ${element.envName} --use`);
            await execCommand(`kde use ${element.envName}`);
            const output = await execCommand(`kde project ls`);
            const names = output.split(/\r?\n/).filter(Boolean);
            return names.map((name) => new ProjectItem(element.envName, name));
          } catch (err2) {
            vscode.window.showErrorMessage(
              `無法載入專案 (${element.envName})：${err2}`
            );
            return [];
          }
        }
      );
    }
    if (element instanceof ProjectItem) {
      return vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Window,
          title: `載入 Pods (${element.projectName})`,
        },
        async () => {
          try {
            await execCommand(`kde use ${element.envName}`);
            const output = await execCommand(
              `kde project pod ${element.projectName}`
            );
            const pods = output.split(/\r?\n/).filter(Boolean);
            return pods.map(
              (pod) => new PodItem(element.envName, element.projectName, pod)
            );
          } catch (err3) {
            vscode.window.showErrorMessage(
              `無法載入 Pods (${element.projectName})：${err3}`
            );
            return [];
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
  oc.appendLine("k8s-dev-environments activated");
  provider = new KDETreeProvider();
  const treeView = vscode.window.createTreeView("kdeEnvView", {
    treeDataProvider: provider,
  });
  context.subscriptions.push(
    treeView,
    vscode.commands.registerCommand("kde.addEnv", addEnvironmentFlow),
    vscode.commands.registerCommand("kde.refresh", refreshEnvironmentsFlow),
    vscode.commands.registerCommand("kde.createEnv", createEnvironmentFlow),
    vscode.commands.registerCommand("kde.stopEnv", async (item) => {
      oc.appendLine(`[invoke] kde.stopEnv ${item?.envName ?? "<undefined>"}`);
      const exitCode = await runAsTask(
        `kde use ${item.envName} && kde stop ${item.envName} && echo "${COMPLETED_MESSAGE}"`
      );
      if (exitCode === 0) {
        provider.refresh();
      } else {
        vscode.window.showErrorMessage(
          `Task stop env failed with exit code ${exitCode}`
        );
      }
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
      let terminal = runInNewTerminal(
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
      runInNewTerminal(
        `kde use ${envName} && kde headlamp`,
        `KDE: headlamp (${envName})`
      );
    }),
    vscode.commands.registerCommand("kde.expose", async (item) => {
      let envName = item && item.envName;
      if (!envName && treeView.selection && treeView.selection[0]) {
        envName = treeView.selection[0].envName;
      }
      oc.appendLine(`[invoke] kde.expose ${envName || "<undefined>"}`);
      if (!envName) {
        try {
          const output = await execCommand("kde ls");
          const envs = output.split(/\r?\n/).filter(Boolean);
          envName = await vscode.window.showQuickPick(envs, {
            placeHolder: "選擇要 Port Forward 的環境",
          });
        } catch (e) {
          vscode.window.showErrorMessage(`讀取環境清單失敗：${e}`);
          return;
        }
      }
      if (!envName) {
        return;
      }
      vscode.window.showInformationMessage(`啟動 Port Forward：${envName}`);
      runInNewTerminal(
        `kde use ${envName} && kde expose`,
        `KDE: port forward (${envName})`
      );
    }),
    vscode.commands.registerCommand("kde.createProject", createProjectFlow),
    vscode.commands.registerCommand("kde.project.deploy", async (item) => {
      const exitCode = await runAsTask(
        `kde use ${item.envName} && kde project deploy ${item.projectName} && echo "${COMPLETED_MESSAGE}"`,
        `KDE: deploy (${item.projectName})`
      );
      if (exitCode === 0) {
        provider.refresh(item);
      } else {
        vscode.window.showErrorMessage(`Deploy 失敗（exit=${exitCode}）`);
      }
    }),
    vscode.commands.registerCommand("kde.project.undeploy", async (item) => {
      const exitCode = await runAsTask(
        `kde use ${item.envName} && kde project undeploy ${item.projectName} && echo "${COMPLETED_MESSAGE}"`,
        `KDE: undeploy (${item.projectName})`
      );
      if (exitCode === 0) {
        provider.refresh(item);
      } else {
        vscode.window.showErrorMessage(`Undeploy 失敗（exit=${exitCode}）`);
      }
    }),
    vscode.commands.registerCommand("kde.project.redeploy", async (item) => {
      const exitCode = await runAsTask(
        `kde use ${item.envName} && kde project redeploy ${item.projectName} && echo "${COMPLETED_MESSAGE}"`,
        `KDE: redeploy (${item.projectName})`
      );
      if (exitCode === 0) {
        provider.refresh(item);
      } else {
        vscode.window.showErrorMessage(`Redeploy 失敗（exit=${exitCode}）`);
      }
    }),
    vscode.commands.registerCommand("kde.project.exec-develop-env", (item) =>
      runInNewTerminal(
        `kde use ${item.envName} && kde project exec ${item.projectName} develop`,
        `KDE: exec develop env (${item.projectName})`
      )
    ),
    vscode.commands.registerCommand("kde.project.exec-deploy-env", (item) =>
      runInNewTerminal(
        `kde use ${item.envName} && kde project exec ${item.projectName} deploy`,
        `KDE: exec deploy env (${item.projectName})`
      )
    ),
    vscode.commands.registerCommand("kde.project.telepresenceReplace", (item) =>
      runInNewTerminal(
        `kde use ${item.envName} && kde telepresence replace ${item.projectName}`,
        `KDE: telepresence replace (${item.projectName})`
      )
    ),
    vscode.commands.registerCommand("kde.pod.logs", async (item) => {
      // 提示使用者輸入 tail 的行數
      const lines = await vscode.window.showInputBox({
        prompt: "請輸入要顯示的 log 行數",
        placeHolder: "例如：100",
      });
      if (!lines) return;
      runInNewTerminal(
        `kde use ${item.envName} && kde project tail ${item.projectName} ${item.podName} ${lines}`,
        `KDE: logs ${item.podName})`
      );
    }),
    vscode.commands.registerCommand("kde.pod.portForward", async (item) => {
      // 提示使用者輸入 port
      const localPort = await vscode.window.showInputBox({
        prompt: "請輸入要 port forward 的 local port",
        placeHolder: "例如：8080",
      });
      if (!localPort) return;
      const targetPort = await vscode.window.showInputBox({
        prompt: "請輸入要 port forward 的 target port",
        placeHolder: "例如：8080",
      });
      if (!targetPort) return;
      runInNewTerminal(
        `kde use ${item.envName} && kde expose ${item.projectName} pod ${item.podName} ${targetPort} ${localPort}`,
        `KDE: pod port-forward ${localPort} (${item.projectName}/${item.podName})`
      );
    }),
    vscode.commands.registerCommand("kde.pod.exec", (item) =>
      runInNewTerminal(
        `kde use ${item.envName} && kde project pod-exec ${item.projectName} ${item.podName}`,
        `KDE: exec ${item.podName})`
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

function deactivate() {
  provider = null;
  outputChannel = null;
}

module.exports = { activate, deactivate };
