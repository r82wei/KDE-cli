# 使用 Ngrok 建立對外網址

### ⚠️ 需要先註冊 Ngrok 帳號，免費方案最多一個 domain

## 使用情境

### 使用 Ngrok 讓 Service 對外服務

- 輸入下列指令，Ngrok 將會產生一個對外網址，並且對應到 Service

  ```bash
  kde ngrok service
  ```

### 使用 Ngrok 讓 Pod 對外服務

- 輸入下列指令，Ngrok 將會產生一個對外網址，並且對應到 Pod

  - 此功能需要在 Deployment 內設定 containerPort 才可以使用

  ```bash
  kde ngrok pod
  ```

### 使用 Ngrok 讓 Ingress Controller 對外服務

1. 輸入下列指令，Ngrok 將會產生一個對外網址，並且對應到 Ingress Nginx Controller

   - 使用此功能需要先註冊 Ngrok 帳號，並且產生 Token ([教學網址](https://steam.oxxostudio.tw/category/python/example/ngrok.html))
   - 第一次執行會跳出提示「請輸入 NGROK_TOKEN:」，請輸入上述說明產生的 NGROK_TOKEN
   - 啟動 Ngrok 後，需要新增或修改 ingress 設定的 host 與顯示的網址相同

   ```bash
   kde ngrok
   ```

2. 部署專案時，將專案的 Domain 設定成跟 ngrok 給的對外網址相同，如果設定過網址，通常可以檢查專案資料夾內的 `deploy.env`，大部分會是 `DOMAIN` 這個環境變數
