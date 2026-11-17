# 06 對外連線與流量攔截

回到 [總覽](README.md)。

這組命令處理兩個方向的連線：把本機環境裡的服務**公開到網際網路**（ngrok、Cloudflare Tunnel），
以及把**遠端叢集的流量接到本機**（Telepresence）。

---

### UC-NET-01 用 ngrok 取得臨時公開網址

**狀態**：⚠️ 有落差

> 身為開發者，我想要一個臨時的公開網址指向本機環境的服務，以便給外部系統（webhook）或同事測試。

- **命令**：`kde ngrok <ingress|service|pod|url>`
- **前置條件**：有 ngrok token。第一次使用時互動詢問並存入 `ngrok.env`。
- **主要流程**：

  | 目標 | 行為 |
  |---|---|
  | `ingress` | 把 ngrok 指向控制節點的 ingress-nginx（NodePort 30080） |
  | `service` | 互動選 namespace → service → port；在容器內 `kubectl port-forward` 到 80 再啟動 ngrok |
  | `pod` | 同上，對象是 pod |
  | 其他字串 | 視為 URL，直接轉發（用主機網路） |

- **例外流程**：沒有參數或 `-h` 顯示說明，結束碼 1。
- **落差**：
  - token 存到**當前目錄**的 `ngrok.env`，但讀取的是 workspace 根目錄的，見 [GAP-06](09-gaps.md#gap-06)。
  - help 列出 `daemon, -d`（背景執行），程式碼沒有實作，見 [GAP-15](09-gaps.md#gap-15)。
  - `ingress` 與 URL 模式用寫死的 `ngrok/ngrok:latest`，見 [GAP-17](09-gaps.md#gap-17)。
- 出處：`scripts/ngrok/command.sh`、`scripts/utils/ngrok.sh`；`docs/core/dev-tools/ngrok.md`

---

### UC-NET-02 用 Cloudflare Tunnel 公開服務

**狀態**：✅ 已確認

> 身為開發者，我想要用自己的網域公開本機環境的服務，以便得到固定網址且不必開放防火牆。

- **命令**：`kde cloudflare-tunnel <url|service|pod> [選項]`

  | 選項 | 意義 |
  |---|---|
  | `-q`、`--quick` | 用隨機網址的 quick tunnel，不需要 Cloudflare 帳號 |
  | `-d`、`--domain` | 自訂網域（網域需託管在 Cloudflare） |
  | `-u`、`--url` | 轉發目標 URL（`url` 目標用） |
  | `-n`、`-s`、`--pod`、`-p` | namespace、service、pod、port；給了就不互動詢問 |
  | `--network` | 容器使用的 Docker 網路（只對 `url` 目標有效） |

- **主要流程**（自訂網域）：
  1. **登入**：`.cloudflared/cert.pem` 不存在時，在容器中執行 `cloudflared login`（需要使用者到瀏覽器授權）。
  2. **建立 tunnel**：先刪除同名的舊 tunnel 與設定檔，再建立新的；把憑證與設定檔存到 `<workspace>/.cloudflared/`。
  3. **設定 DNS**：建立指向 tunnel 的 DNS 紀錄，**覆寫既有紀錄**。
  4. **啟動**：在前景執行 tunnel；`service` / `pod` 目標會同時在容器內執行 `kubectl port-forward`。
- **替代流程**：
  - `--quick`：跳過登入、建立與 DNS，直接啟動並印出隨機網址。
  - 缺少的 namespace、service、pod、port、URL、網域會互動詢問。
  - 萬用網域（含 `*`）的設定檔名以 `all` 取代 `*`。
- **例外流程**：未知的目標報錯，結束碼 1；沒有參數顯示說明，結束碼 1。
- **注意**：
  - 這裡的 `-d` 是「網域」，在其他命令是「背景執行」（[GAP-19](09-gaps.md#gap-19)）。
  - 未知的選項會被靜默忽略。
  - 每次執行都會刪除並重建 tunnel，並覆寫 DNS。這對正式網域是有影響的操作，但沒有確認提示。
- 出處：`scripts/cloudflare-tunnel/command.sh`、`scripts/utils/cloudflare.sh`；`docs/core/dev-tools/cloudflare-tunnel.md`

---

### UC-NET-03 用 Telepresence 在本機接手遠端服務

**狀態**：✅ 已確認

> 身為開發者，我想要在本機容器裡執行我的服務，同時讓它擁有遠端 pod 的網路、環境變數與掛載，以便對接真實的上下游服務來除錯。

- **命令**：`kde telepresence <動作> [namespace] [workload]`

  | 動作 | 攔截流量 | 影響遠端 pod | 說明 |
  |---|---|---|---|
  | `replace` | 是 | **停止**遠端 pod | 本機完全取代遠端 |
  | `intercept` | 是 | 否 | 流量改送本機，遠端繼續運行 |
  | `wiretap` | 否（收副本） | 否 | 本機收到流量副本 |
  | `ingest` | 否 | 否 | 只取得遠端的環境與連線能力 |
  | `list` | — | — | 列出 namespace 的連線狀態 |
  | `uninstall` | — | — | 移除 namespace 內所有 Telepresence agent |
  | `clear` | — | — | 停止所有 Telepresence 連線容器 |

- **主要流程**（`replace` / `intercept` / `wiretap` / `ingest`）：
  1. 未給 namespace 時互動選擇。
  2. 詢問要額外代理的內網網段（CIDR）；已設定 `TELEPRESENCE_ALSO_PROXY_CIDR` 就直接使用。
  3. 啟動**連線容器** `kde-telepresence-session-<env>-<namespace>`（已存在就沿用），等待連上叢集，最多 300 秒。
  4. 未給 workload 時從可用清單中選擇。
  5. 執行對應的 Telepresence 動作；除了 `ingest` 之外，會逐組詢問「遠端 port / 本機 port」直到使用者不再新增。遠端 pod 的環境變數被存成 env 檔，掛載被存到環境目錄下的 `.telepresence/`。
  6. 互動選擇一個專案，進入它的**開發容器**。這個容器共用連線容器的網路，並載入遠端 pod 的環境變數。
  7. 使用者離開開發容器後，若沒有其他容器還在用這條連線，就停止連線容器。
- **例外流程**：連線逾時時停止連線容器，結束碼 1；`list` 在沒有連線容器時報錯；`clear` 在沒有任何連線時報錯。
- **設定**：`TELEPRESENCE_MANAGER_NAMESPACE`（預設 `ambassador`）、`TELEPRESENCE_IMAGE`。
- **注意**：
  - 連線容器需要高權限（`NET_ADMIN`、`SYS_ADMIN`、`/dev/net/tun`、`/dev/fuse`、關閉 AppArmor）。
  - `replace` 會停止遠端 pod，對共用的或正式的叢集有實際影響，但沒有額外的確認提示。
  - 這裡用的開發容器與 [UC-PRJ-09](03-project.md#uc-prj-09-進入專案的工作容器) 的條件不完全相同，見 [GAP-07](09-gaps.md#gap-07)。
  - 未知的動作要等到連線容器啟動之後才會顯示說明，見 [GAP-27](09-gaps.md#gap-27)。
- 出處：`scripts/telepresence/command.sh`、`scripts/utils/telepresence.sh`；`docs/core/dev-tools/telepresence.md`
