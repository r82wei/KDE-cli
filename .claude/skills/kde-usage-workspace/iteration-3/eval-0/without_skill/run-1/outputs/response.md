# 讓 myapp 的程式碼修改生效

你的情境是：Kind 環境 + volume mount + nodemon — 這是 KDE-CLI 的 **Hot Reload 模式**，也是最常見的本地開發流程。

## 好消息：直接存檔就好，不需要做任何 KDE 操作

因為你的程式碼目錄已經透過 PVC 掛載進 Pod，而 nodemon 會監控檔案變動，所以：

1. **在 host 上修改並儲存程式碼**（就是你剛才改的那個 function）
2. nodemon 偵測到檔案變更，自動重啟 Node.js 程序
3. 修改立即生效，**不需要 redeploy**

## 確認修改有被 nodemon 抓到

如果想確認 nodemon 真的有重啟，可以查看 pod log：

```bash
kde proj tail myapp
```

你應該會看到類似這樣的輸出：

```
[nodemon] restarting due to changes...
[nodemon] starting `node index.js`
```

## 如果 nodemon 沒有反應怎麼辦

少數情況下 nodemon 可能沒偵測到（例如 polling 設定問題），可以進 pod 手動重啟：

```bash
kde proj pod-exec myapp
# 進入 pod 後，直接 kill nodemon process 讓它重啟
# 或是 Ctrl+C 後重新執行
```

---

**總結**：Kind + volume mount + nodemon 的組合，修改 host 上的程式碼存檔即可，不需要執行任何 `kde proj deploy` 或 `redeploy`。
