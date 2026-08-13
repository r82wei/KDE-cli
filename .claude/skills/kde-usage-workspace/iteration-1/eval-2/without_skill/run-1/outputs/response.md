# 只執行 build 和 test 兩個 stage 的指令

你的 pipeline stages 是 `build, test, deploy`，目標是執行 build 和 test 但跳過 deploy。

## 推薦指令

使用 `--from` 加 `--to` 指定範圍：

```bash
kde proj pipeline backend --from build --to test
```

這會從 `build` 開始執行，到 `test` 結束，不會執行 `deploy`。

## 說明

| 旗標 | 作用 |
|------|------|
| `--from build` | 從 build 階段開始 |
| `--to test` | 執行到 test 階段為止（含 test） |

Pipeline 會依照 `project.env` 中 `KDE_PIPELINE_STAGES` 定義的順序過濾，build → test → deploy 中，`--from build --to test` 的結果就是只執行 `build` 和 `test`。

## 備注：其他可能的寫法

如果你只改了 build.sh 但不需要重跑 test，也可以單獨執行一個 stage：

```bash
kde proj pipeline backend --only build
```

但根據你的需求（build + test），`--from build --to test` 是最直接的做法。

> 注意：`--only` 一次只能指定一個 stage，且不能與 `--from`/`--to` 混用。如果需要執行連續的多個 stage，請使用 `--from ... --to ...`。
