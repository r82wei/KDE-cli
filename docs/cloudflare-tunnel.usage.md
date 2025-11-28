# 使用 Cloudflare Tunnel 建立對外網址

## 使用說明

```bash
kde cloudflare-tunnel <target> [options]     透過 Cloudflare Tunnel 建立連線

target:
  url                  透過 Cloudflare Tunnel 與 url 建立連線 (e.g. http://localhost:8080 or http://192.168.1.1)
  service              透過 Cloudflare Tunnel 與當前 k8s 環境的 service 建立連線
  pod                  透過 Cloudflare Tunnel 與當前 k8s 環境的 pod 建立連線

options:
  -h, --help              Show help
  -q, --quick             使用隨機網址的 Cloudflare Tunnel (不需要登入 Cloudflare 帳號)
  -d, --domain            Cloudflare Tunnel 的自訂 domain (需要登入 Cloudflare 帳號且 Domain 有託管在 Cloudflare 上) (e.g. myapp.example.com)
  -u, --url               要轉發的目標 URL 位址 (e.g. http://localhost:8080 or http://192.168.1.1)
  -n, --namespace         Namespace 名稱
  -s, --service           Service 名稱
  --pod                   Pod 名稱
  -p, --port              Port 號碼
  --network               Docker 網路 (default: 當前 K8s 環境的 Docker 網路)，也可設定為 host (即使用主機的網路)
```

## Cloudflare quick tunnel 隨機網址

### 產生隨機網址對應到指定的 URL

- ⚠️  因為是在 container 內執行，如果要對應到本地的 8080 port，不可以直接使用 http://127.0.0.1:8080，而是需要輸入本地的 IP，例如： http://192.168.0.20:8080

```bash
# 此範例會將 Cloudflare 產生的隨機網址 proxy 到提示輸入的 url
kde cloudflare-tunnel url --quick

# 此範例會將 Cloudflare 產生的隨機網址 proxy 到 192.168.0.20 的 8080 port
kde cloudflare-tunnel url --url http://192.168.0.20:8080 --quick
```

### 產生隨機網址對應到當前 K8S 環境的指定 service

```bash
# 此範例會將 Cloudflare 產生的隨機網址 proxy 到互動選單選擇後的 service
kde cloudflare-tunnel service --quick

# 此範例會將 Cloudflare 產生的隨機網址 proxy 到 namespace my-app 底下的 nginx service 8080 port
kde cloudflare-tunnel service --namespace my-app --service nginx --port 8080 --quick
```

### 產生隨機網址對應到當前 K8S 環境的指定 Pod

```bash
# 此範例會將 Cloudflare 產生的隨機網址 proxy 到互動選單選擇後的 pod
kde cloudflare-tunnel pod --quick

# 此範例會將 Cloudflare 產生的隨機網址 proxy 到 namespace my-app 底下的 nginx-xj3234sdf pod 8080 port
kde cloudflare-tunnel pod --namespace my-app --pod nginx-xj3234sdf --port 8080 --quick
```

## Cloudflare 託管的自有 Domain

### `需要有私人網址託管在 Cloudflare，第一次執行會產生 cloudflare 登入網址，需要透過瀏覽器登入取得憑證 (會將憑證存在 .cloudflared 資料夾內，後續就不用再登入)`

### 將自訂網址對應到指定的 URL

- ⚠️  因為是在 container 內執行，如果要對應到本地的 8080 port，不可以直接使用 http://127.0.0.1:8080，而是需要輸入本地的 IP，例如： http://192.168.0.20:8080

```bash
# 此範例將會自動設定 DNS test.gosu.world 並且 proxy 到網址 http://192.168.0.20:8080
kde cloudflare-tunnel url --url http://192.168.0.20:8080 --domain test.gosu.world
```

### 將自訂網址對應到當前環境的 service

```bash
# 此範例將會自動設定 DNS test.gosu.world 並且 proxy 到互動選單選擇後的 service
kde cloudflare-tunnel service --domain test.gosu.world

# 此範例將會自動設定 DNS test.gosu.world 並且 proxy 到 namespace my-app 底下的 nginx service 8080 port
kde cloudflare-tunnel service --domain test.gosu.world --namespace my-app --service nginx --port 8080
```

### 將自訂網址對應到當前環境的 pod

```bash
# 此範例將會自動設定 DNS test.gosu.world 並且 proxy 到互動選單選擇後的 pod
kde cloudflare-tunnel pod --domain test.gosu.world

# 此範例將會自動設定 DNS test.gosu.world 並且 proxy 到 namespace my-app 底下的 nginx-xj3234sdf pod 8080 port
kde cloudflare-tunnel pod --domain test.gosu.world --namespace my-app --pod nginx-xj3234sdf --port 8080
```
