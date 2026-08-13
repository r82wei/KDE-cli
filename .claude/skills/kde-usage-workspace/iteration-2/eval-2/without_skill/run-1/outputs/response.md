# 只跑 build 和 test 兩個 stage 的指令

你的情境：
- Pipeline stages：`build, test, deploy`
- 想執行：`build` 和 `test`，跳過 `deploy`
- 當前 project：`backend`，環境：`dev-env`

## 步驟一：切換到 dev-env 環境

如果尚未切換到 `dev-env`，先執行：

```bash
kde use dev-env
```

## 步驟二：執行 pipeline，只跑 build 到 test

使用 `--from` 搭配 `--to` 旗標，指定執行範圍：

```bash
kde proj pipeline backend --from build --to test
```

這樣 KDE-CLI 會從 `build` 開始，執行到 `test` 為止，`deploy` 不會被執行。

## 為什麼用 --from --to 而不是 --only？

- `--only <stage>`：只執行**單一**指定的 stage（例如只跑 `build` 一個）
- `--from <stage> --to <stage>`：執行一個**連續範圍**的 stages（build、test 兩個都跑）
- `--only` 不能與 `--from` / `--to` 同時使用

## 其他等效寫法

```bash
# 等號語法同樣有效
kde proj pipeline backend --from=build --to=test
```

## 補充：如果每次都要手動切環境很麻煩

可以在 workspace 底下的 `current.env` 確認當前環境是否已經是 `dev-env`：

```bash
kde cur         # 查看當前環境
kde use dev-env # 切換到 dev-env
```
