# 04 CI/CD Pipeline

回到 [總覽](README.md)。

Pipeline 是「專案 → 環境」的交付流程。它的定位（`docs/principle.md`）是讓使用者自訂每個階段的
shell script 與執行映像，並且能在本機重現、除錯同一套流程。

## 模型

- 一個專案有一條 pipeline，定義在 `project.env`。
- Pipeline 是**有序的 stage 清單**（`KDE_PIPELINE_STAGES`，逗號或空白分隔）。沒有設定時視為 `build,deploy`。
- 每個 stage 是「一支腳本 + 一個映像」，在符合 [專案容器共同條件](03-project.md#uc-prj-09-進入專案的工作容器) 的一次性容器中執行。
- Stage 名稱中的 `-` 在變數名稱裡寫成 `_`（`security-scan` → `KDE_PIPELINE_STAGE_security_scan_*`）。

### Stage 設定

`<s>` 代表 stage 名稱。

| 變數 | 意義 | 預設 |
|---|---|---|
| `KDE_PIPELINE_STAGE_<s>_SCRIPT` | 要執行的腳本 | `<s>.sh`（需存在於專案目錄） |
| `KDE_PIPELINE_STAGE_<s>_IMAGE` | 執行映像 | `build` 用 `DEVELOP_IMAGE`，其餘用 `DEPLOY_IMAGE` |
| `KDE_PIPELINE_STAGE_<s>_WORKDIR` | 執行目錄；相對路徑以專案目錄為基準 | 專案目錄 |
| `KDE_PIPELINE_STAGE_<s>_SKIP` | `true` 時永遠跳過 | `false` |
| `KDE_PIPELINE_STAGE_<s>_MANUAL_ONLY` | `true` 時只有 `--manual` 才執行 | `false` |
| `KDE_PIPELINE_STAGE_<s>_ALLOW_FAILURE` | `true` 時失敗不中止 pipeline | `false` |
| `KDE_PIPELINE_STAGE_<s>_PAUSE` | `true` 時成功後暫停，等使用者確認才繼續 | `false` |
| `KDE_PIPELINE_STAGE_<s>_MOUNT_<名稱>` | 只給這個 stage 的額外掛載（`host:container[:ro]`） | 無 |

### Pipeline 層級設定

| 變數 | 意義 | 預設 |
|---|---|---|
| `KDE_PIPELINE_STAGES` | stage 清單 | `build,deploy` |
| `KDE_PIPELINE_FAIL_FAST` | `false` 時任何 stage 失敗都繼續往下 | 啟用 |
| `KDE_MOUNT_<名稱>` | 所有 stage 與專案容器共用的額外掛載 | 無 |

---

### UC-PIPE-01 執行 pipeline

**狀態**：⚠️ 有落差

> 身為開發者，我想要用一個命令完成建置與部署，以便把修改送進環境。
>
> 身為 DevOps，我想要在本機執行與正式流程相同的 pipeline，以便在送出前驗證它。

- **命令**：`kde project pipeline [project] [選項]`（`deploy` 是同義詞）
- **前置條件**：專案存在。
- **主要流程**：
  1. 載入 `project.env`。原始碼 repo 不存在時自動取得（[UC-PRJ-03](03-project.md#uc-prj-03-更新專案原始碼)）。
  2. 清空 `.pipeline.env`。
  3. 依選項篩出要執行的 stage（UC-PIPE-02），印出清單與模式。
  4. 對每個 stage 依序：
     1. `SKIP=true` → 跳過。
     2. `MANUAL_ONLY=true` 且不是手動模式 → 跳過並提示 `--manual`。
     3. 找不到腳本 → 報錯；fail fast 啟用時整條失敗，否則跳過這個 stage。
     4. 確認 `WORKDIR` 存在，否則該 stage 失敗。
     5. 在容器中 `cd <WORKDIR>`，載入 `.pipeline.env`（存在時），執行腳本。
     6. 依結果處理失敗（UC-PIPE-04）與暫停（UC-PIPE-05）。
  5. 印出「Pipeline 執行完成（執行了 N 個階段）」；一個都沒執行時印出警告，結束碼仍為 0。
- **例外流程**：專案不存在時列出可用專案，結束碼 1；選項錯誤時 stderr 報錯，結束碼 1。
- **落差**：步驟 4.6 的失敗處理實際上不會生效，見 [GAP-01](09-gaps.md#gap-01)。
- 出處：`scripts/project/command.sh:132-166`、`scripts/utils/pipeline.sh`

---

### UC-PIPE-02 只執行部分 stage

**狀態**：✅ 已確認

> 身為 DevOps，我想要只跑某一段流程，以便不必每次從頭執行。

| 選項 | 行為 |
|---|---|
| `--from <s>` | 從該 stage 開始 |
| `--to <s>` | 執行到該 stage 為止（含） |
| `--only <s>` | 只執行該 stage |

- 每個選項都支援 `--opt value` 與 `--opt=value` 兩種寫法。
- `--only` 不能與 `--from` / `--to` 併用（報錯）。選項缺值也會報錯。
- **所有選項只從命令列讀取**，每次解析前重置，不會從環境變數繼承（help 明文）。
- stage 名稱不會被驗證是否存在於清單，見 [GAP-24](09-gaps.md#gap-24)。
- 出處：`pipeline.sh:225-259`、`513-614`　測試：`test/test-pipeline-args.sh`

---

### UC-PIPE-03 手動 stage 與除錯

**狀態**：✅ 已確認

> 身為 DevOps，我想要把危險或昂貴的 stage 設成預設不執行，以便只在明確要求時才跑。
>
> 身為 DevOps，我想要進入某個 stage 的執行環境手動操作，以便除錯失敗的腳本。

| 選項 | 行為 |
|---|---|
| `-m`、`--manual` | 手動模式：`MANUAL_ONLY` 的 stage 也會執行。手動模式下不會因 `PAUSE` 暫停 |
| `-s`、`--shell` | Shell 模式：每個 stage 不執行腳本，而是在它的容器裡開啟互動 shell，離開後進入下一個 stage。隱含 `--manual`。stage 的結束碼不算失敗 |

- `--shell` 與 `--no-tty` 互斥（shell 需要 TTY），併用會報錯。
- 出處：`pipeline.sh:162-177`、`292-303`、`576-610`　測試：`test/test-only-manual.sh`

---

### UC-PIPE-04 失敗處理

**狀態**：⚠️ 有落差

> 身為 DevOps，我想要讓非關鍵的 stage（如 lint）失敗時不擋住後面的部署，以便流程不因次要問題中斷。

- **設計上的規則**（程式碼的判斷順序與 `docs/core/cicd-pipeline.md` 一致）：
  1. Shell 模式：不算失敗。
  2. 該 stage `ALLOW_FAILURE=true`：印出警告，繼續下一個 stage。
  3. Fail fast 啟用（預設）：印出「Pipeline 執行失敗」，以該 stage 的結束碼結束。
  4. Fail fast 停用（`KDE_PIPELINE_FAIL_FAST=false`）：印出警告，繼續。
- **實際行為**：stage 失敗時 CLI 直接以該結束碼中止，上述第 2、4 條與失敗訊息都不會出現。
  已用實際程式碼搭配假的 `docker` 驗證，見 [GAP-01](09-gaps.md#gap-01)。
- 測試：`test/test-allow-failure.sh` 只驗證 `is_stage_allow_failure` 這個判斷函式的回傳值，沒有涵蓋整條流程。

---

### UC-PIPE-05 暫停確認與變數傳遞

**狀態**：✅ 已確認

> 身為 DevOps，我想要在某個 stage 之後停下來檢查輸出，以便決定要不要繼續部署。
>
> 身為 DevOps，我想要把前一個 stage 產生的值（如映像 tag）交給後面的 stage，以便各階段保持一致。

- **暫停**：stage 成功且 `PAUSE=true` 時，詢問「繼續執行？(y/N)」（從 `/dev/tty` 讀取）。回答不是 `y` / `Y` 就停止，結束碼 0。手動模式下不暫停；`--no-tty` 下自動繼續並印出提示。
- **變數傳遞**：stage 腳本把 `KEY=value` 寫進專案目錄的 `.pipeline.env`，之後的 stage 在執行腳本前會 `source` 它。這個檔案在每次 pipeline 開始時清空。
- 出處：`pipeline.sh:305-310`、`343-346`、`475-495`；`docs/core/cicd-pipeline.md`

---

### UC-PIPE-06 解除部署

**狀態**：✅ 已確認

> 身為開發者，我想要把專案從環境移除，以便重新部署或釋放資源。

- **命令**：`kde project undeploy [project]`
- **主要流程**：專案有 `undeploy` 的腳本（`undeploy.sh` 或 `KDE_PIPELINE_STAGE_undeploy_SCRIPT`）時，把它當成一個 stage 執行（等同 `--only undeploy`，不需要列在 `KDE_PIPELINE_STAGES` 裡）。
- **替代流程**（沒有腳本）：

  | 環境類型 | 行為 |
  |---|---|
  | kind、k3d | 印出警告，刪除與專案同名的 namespace |
  | 外部 K8s | **拒絕執行**，stderr 要求建立 `undeploy.sh`，失敗 |

- **設計理由**：對外部叢集不做預設的刪除動作，「避免危險操作」（`project.sh:351-355`）。
- 出處：`project.sh:311-357`；`docs/core/project.md`

---

### UC-PIPE-07 重新部署

**狀態**：⚠️ 有落差

> 身為開發者，我想要在改了映像、manifest 或環境變數之後乾淨地重新部署，以便確定環境反映最新設定。

- **命令**：`kde project redeploy [project] [--no-tty]`
- **主要流程**：解除部署（UC-PIPE-06）→ 執行完整 pipeline（UC-PIPE-01）。解除部署失敗就中止。
- **與 hot reload 的分工**（`docs/core/quick-reference.md`）：只改程式碼時不需要 redeploy，因為專案目錄已掛進 pod，檔案監看工具會自動重啟。
- **落差**：除了 `--no-tty` 之外不接受其他 pipeline 選項（`--from` 等會被忽略），見 [GAP-11](09-gaps.md#gap-11)。解除部署的腳本失敗時會被當成成功，見 [GAP-01](09-gaps.md#gap-01)。
- 出處：`scripts/project/command.sh:173-184`

---

### UC-PIPE-08 非互動執行

**狀態**：✅ 已確認

> 身為 AI agent 或 CI，我想要在沒有 TTY 的環境執行 pipeline，以便自動化整個交付流程。

- **選項**：`--no-tty`（`pipeline`、`deploy`、`redeploy`）
- **行為**：stage 容器以 `-i` 而不是 `-it` 啟動；`PAUSE` 自動繼續；清單輸出標示「非互動式」。
- **為什麼需要**：預設的 `docker run -it` 在沒有 TTY 時會直接失敗。
- 出處：`pipeline.sh:312-317`、`585-588`；commit `feat: add --no-tty option for non-interactive pipeline execution`（2026-04-13）
