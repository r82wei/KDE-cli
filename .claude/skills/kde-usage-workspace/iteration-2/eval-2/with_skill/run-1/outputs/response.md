你要只重跑 build 和 test，跳過 deploy，使用 `--from` 搭配 `--to` 來指定範圍：

```bash
kde proj pipeline backend --from build --to test
```

這條指令會：
- 從 build stage 開始執行
- 執行到 test stage 為止
- 跳過 deploy stage

由於你沒有切換環境的需求（當前就是 dev-env），直接下這條指令即可。如果不確定當前 active 環境，可以先確認：

```bash
kde current
```

如果顯示的不是 dev-env，先切換：

```bash
kde use dev-env
```

再執行 pipeline 指令。
