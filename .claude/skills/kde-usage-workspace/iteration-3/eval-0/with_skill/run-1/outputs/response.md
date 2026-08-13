你的設定正好是「熱重載模式」——Kind + volume mount + nodemon。在這個模式下，**你只需要存檔，nodemon 會自動偵測到檔案變更並重啟 process，不需要做任何 `kde` 操作**。

不需要 redeploy，不需要重新 build image。

## 確認變更有生效

存完檔後，用以下指令看 pod log，確認 nodemon 確實有重啟：

```bash
kde proj tail myapp
```

你應該會看到 nodemon 輸出類似：

```
[nodemon] restarting due to changes...
[nodemon] starting `node index.js`
```

這代表你改的 function 已經生效了。

## 如果 nodemon 沒有重啟

可能是 volume mount 路徑或 nodemon watch 路徑設定的問題。可以先 exec 進去 pod 確認：

```bash
kde proj pod-exec myapp
```

進去後確認 nodemon 正在 watch 的目錄是否包含你改的檔案。

## 什麼時候才需要 redeploy？

以下情況才需要跑完整的 pipeline（`kde proj redeploy myapp`）：

- 換了 Docker image 版本
- 改了 K8s manifest（deployment、service 等）
- 新增或修改了環境變數
- 沒有使用 volume mount，code 是打包進 image 裡的
