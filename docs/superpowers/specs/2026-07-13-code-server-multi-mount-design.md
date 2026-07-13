# code-server 支援掛載多個資料夾/檔案 — 設計文件

日期：2026-07-13
狀態：已核准，待實作

## 背景

目前 `kde code-server` 的 `-v/--volume` 只接受**單一**目錄，並以「host 路徑 = container 路徑」的慣例掛載進 container（`-v "${MOUNT_PATH}:${MOUNT_PATH}"`）。`--workdir` 則在該掛載目錄底下開啟。

需求：讓 `-v` 可以指定**多個**掛載目標，且每個目標可以是**目錄或單一檔案**，以便一次把多個專案/共用函式庫/設定檔帶進 code-server container。

## 目標

- `-v/--volume` 可重複指定多次，累積成掛載清單。
- 每個 `-v` 目標可以是目錄或一般檔案。
- 沿用「host 路徑 = container 路徑」的掛載慣例。
- code-server 仍只開啟單一 `--workdir`（多根工作區不在本次範圍）。

## 非目標（YAGNI）

- 不支援多根工作區（`.code-workspace` / multi-root）自動產生。
- 不支援逗號分隔語法（只用重複 `-v`）。
- 不支援自訂 container 內掛載路徑（維持 host=container 慣例）。

## 行為規格

### 指定方式
- `-v/--volume` 可重複多次，每次一個目標：
  ```
  kde code-server -v ~/proj-a -v ~/proj-b -v ~/.gitconfig
  ```
- 每個目標以 `-v "${PATH}:${PATH}"` 掛載（host 路徑 = container 路徑）。
- 無任何 `-v` 時維持現狀：預設掛載當前路徑 `$PWD`。

### 開啟資料夾（workdir）
- code-server 只開啟單一 `--workdir`，必為**目錄**。
- 未指定 `--workdir` 時，預設為**第一個「目錄型」`-v`**（略過檔案型目標）。
- 若所有 `-v` 都是檔案、且未給 `--workdir` → 報錯，要求明確指定 `--workdir`。

### 驗證規則
1. 每個 `-v` 目標必須存在，且為目錄或一般檔案，否則報錯並中止。
2. 掛載目標以絕對路徑去重（相同路徑只掛一次），避免 Docker duplicate mount 錯誤。
3. `--workdir` 必須是目錄，且位於**任一目錄型掛載目標**底下（等於該目錄，或在其之下）。

## 程式改動

### 1. `scripts/code-server/command.sh`
- 新增 bash 陣列 `MOUNT_PATHS=()`。
- `-v/--volume` 分支改為 `MOUNT_PATHS+=("$2")`（append，不覆寫）。
- 呼叫慣例調整：`start_code_server` 前段仍為位置參數，掛載清單以 `"$@"` 傳在最後：
  ```bash
  start_code_server "${PORT}" "${DAEMON}" "${NAME}" "${OPEN_PATH}" "${MOUNT_PATHS[@]}"
  ```
- `--help` 更新 `-v` 說明：可重複指定、可掛目錄或單一檔案。

### 2. `scripts/utils/code-server.sh`
- `start_code_server` 簽章調整為前 4 個位置參數 `(PORT DAEMON NAME OPEN_PATH)`，之後 `shift 4`，剩餘 `"$@"` 為掛載清單 `MOUNT_PATHS`。
- 若 `MOUNT_PATHS` 為空 → 預設為 `$PWD`。
- 對每個掛載目標 `readlink -f` 解析絕對路徑，驗證存在且為目錄或檔案，並去重。
- 決定 `OPEN_PATH`：
  - 若呼叫端已給（非空）→ 用該值（`readlink -f` 後）。
  - 否則挑第一個目錄型掛載目標；若無 → 報錯。
- workdir 驗證：必為目錄，且在任一目錄型掛載目標底下。
- 組 docker 參數：以迴圈把每個掛載目標展開為多個 `-v "${p}:${p}"`，取代原本單一的 `-v "${MOUNT_PATH}:${MOUNT_PATH}"`。daemon 與非 daemon 兩個分支都套用。
- 啟動訊息列出所有掛載目標與開啟資料夾。

### 3. 文件同步（依 CLAUDE.md 規則）
- `docs/core/quick-reference.md`
- `.claude/skills/kde-usage/SKILL.md`
- `.claude/skills/kde-usage/references/quick-reference.md`

## 相容性

- 既有用法 `kde code-server`（無參數）與 `kde code-server -v <dir> -w <dir>` 行為不變。
- 只擴充 `-v` 的重複與檔案能力，不移除任何現有旗標。
