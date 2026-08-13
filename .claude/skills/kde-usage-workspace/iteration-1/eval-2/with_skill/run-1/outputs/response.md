你要只跑 `build` 和 `test`，跳過 `deploy`，可以用 `--to` 旗標：

```bash
kde proj pipeline backend --to test
```

這條指令會從第一個 stage 開始，執行到 `test` 為止（包含 `build` 和 `test`），不會執行 `deploy`。

如果你的 `dev-env` 不是目前的 active 環境，先切換：

```bash
kde use dev-env
kde proj pipeline backend --to test
```

**說明：**

- `--to <stage>` — 執行到指定的 stage 為止（含該 stage），之後的 stage 全部跳過。
- pipeline stages 是 `build, test, deploy`，`--to test` 就會執行 `build` + `test`，停在 `deploy` 前面。
