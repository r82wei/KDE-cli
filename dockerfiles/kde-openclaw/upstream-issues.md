# 官方 OpenClaw 映像的已知問題

本文件記錄 **base image 自己帶進來、不屬於 KDE-CLI 的問題**。這些不是 `kde openclaw`
的 bug，修不修、怎麼修都取決於上游何時修好，所以獨立記在這裡，而不是散在
`Dockerfile` / `entrypoint.sh` 的註解裡。

`OPENCLAW_VERSION` 的預設值在 `build.sh` 與 `release.sh`，兩支必須同步。

---

## 2026.9.1：`@openai/codex` 缺頂層連結，一開始對話就報 app-server 找不到

**狀態**：上游未修（2026-09-05 確認）。**本專案的處置是把 base image 退回
`2026.8.2-browser`**（`build.sh` / `release.sh` 的 `OPENCLAW_VERSION`），
不在自家映像層套補丁 —— 補丁依賴上游的 `node_modules` 版面，維護成本比等上游修好高，
而 2026.8.2 是實測可用的版本。等上游出新版再依下面的驗法決定要不要升。

**影響版本**：`ghcr.io/openclaw/openclaw:2026.9.1`，含 `-browser` 變體。
`2026.8.2` 不受影響。

### 症狀

`kde openclaw onboard` 全程正常、gateway 也起得來，**一開始對話**才炸：

```
Error: Managed Codex app-server binary was not found for @openai/codex.
Reinstall or update OpenClaw, or run pnpm install in a source checkout.
Set plugins.entries.codex.config.appServer.command or OPENCLAW_CODEX_APP_SERVER_BIN
to use a custom Codex binary.
```

onboard 不會踩到，是因為那階段只寫設定、不啟動 codex plugin；要到第一次對話才去
啟 codex app-server，那一刻才需要 binary。

### 原因

2026.9.1 把 `/app/node_modules` 的頂層條目從 **447 個縮到 62 個**，`@openai/codex`
在 `/app/node_modules/.modules.yaml` 裡被標成 `"private"`。套件本身還在
pnpm store（`/app/node_modules/.pnpm/@openai+codex@0.152.1/`）、原生 binary 也完好，
但這兩個東西不見了：

- `/app/node_modules/@openai/codex`（連結）
- `/app/node_modules/.bin/codex`（啟動器，2026.8.2 是 `-> ../@openai/codex/bin/codex.js`）

而 codex plugin 的 resolver（`/app/dist/managed-binary-*.js` 的
`resolveManagedCodexAppServerCommandCandidates`）**只認這兩條路**：

1. 從 `<root>/package.json` 用 `createRequire` 解析 `@openai/codex`
2. `access(X_OK)` 檢查 `<root>/node_modules/.bin/codex`

兩條都斷，所有候選路徑落空，於是丟出上面那個錯誤。

判定這是上游**意外**而非有意移除的依據：其他 plugin 的 SDK（`@anthropic-ai/sdk`、
`@google/genai`）在 2026.9.1 都還在頂層有連結，只有 codex 掉了；而 2026.8.2
兩者俱全。看起來是縮 `node_modules` 時把 codex 的連結一起砍掉，但 codex plugin
的 resolver 沒跟著改。

### 複現（不必啟容器對話）

```bash
docker run --rm --entrypoint sh ghcr.io/openclaw/openclaw:2026.9.1 -c \
  'node -e "require(\"module\").createRequire(\"/app/package.json\").resolve(\"@openai/codex/package.json\")"'
# → MODULE_NOT_FOUND
```

### 上游出新版時怎麼驗有沒有修好

```bash
docker run --rm --entrypoint sh ghcr.io/openclaw/openclaw:<新tag> -c \
  'ls -d /app/node_modules/@openai/codex && ls -la /app/node_modules/.bin/codex'
```

兩者都在 = 已修，直接升 `build.sh` / `release.sh` 的 `OPENCLAW_VERSION` 即可。
還是缺就繼續留在 `2026.8.2-browser`，或改用下面那個修法。

### 已驗證的修法（刻意未採用，保留備查）

加在 `Dockerfile` 的 `apt-get` 之後：

```dockerfile
RUN set -eu; \
    if [ ! -e /app/node_modules/.bin/codex ]; then \
      codex_pkg=''; \
      for d in /app/node_modules/.pnpm/@openai+codex@*/node_modules/@openai/codex; do \
        if [ -f "$d/bin/codex.js" ]; then codex_pkg="$d"; break; fi; \
      done; \
      [ -n "$codex_pkg" ] || { echo "找不到 @openai/codex launcher 套件"; exit 1; }; \
      mkdir -p /app/node_modules/@openai; \
      ln -sfn "$codex_pkg" /app/node_modules/@openai/codex; \
      ln -sfn ../@openai/codex/bin/codex.js /app/node_modules/.bin/codex; \
    fi; \
    node -e 'require("module").createRequire("/app/package.json").resolve("@openai/codex/package.json")'; \
    node -e 'require("fs").accessSync("/app/node_modules/.bin/codex", require("fs").constants.X_OK)'
```

兩個關鍵取捨，改動前請先讀：

- **只補與架構無關的 launcher 套件**，認法是「它才有 `bin/codex.js`」，平台變體
  （`@openai+codex@0.152.1-linux-x64` 之類）一律不碰。launcher 自己會依
  `process.arch` 去 `vendor/<triple>/bin` 挑原生 binary；寫死 `-linux-x64`
  會讓 `release.sh` 的 arm64 build 壞掉。
- **末兩行 node 斷言刻意不受 `if` 包住**。連結已存在就跳過建立，讓上游修好後
  這段自動變成 no-op；但斷言恆執行，上游哪天再動 `node_modules` 版面、這個補法
  失效時要**在 build 就爆**，而不是又變成一次「onboard 完才發現不能對話」。

驗證紀錄（實際 build `2026.9.1-browser`）：連結建出、`createRequire` 解析成功、
`.bin/codex --version` 回 `codex-cli 0.152.1`、`codex app-server` 起得來（只警告
bubblewrap 不在 PATH，會用內建的）；以 `PUID/PGID=1001` 降權後 X_OK 與解析同樣通過。

---

## 所有 `-browser` 變體：`/home/node/.cache` 屬 root，新 workspace 啟動即 restart loop

**狀態**：**已修**，見 `entrypoint.sh` 的 `mkdir -p "${OPENCLAW_HOME_DIR}/.cache"`
與其後的 `chown`。此處只留成因，方便日後判斷同類症狀。

**影響版本**：`2026.8.2-browser` 與 `2026.9.1-browser` 皆實測為 `root:root`，
所以退回 2026.8.2 並不會讓這件事消失，entrypoint 那段修正不能拿掉。
非 `-browser` 的 tag 根本沒有 `.cache` 目錄，不受影響。

`-browser` 變體的 playwright 安裝步驟以 root 建出 `/home/node/.cache`（只有裡面的
`ms-playwright` 被 chown 給 node），那層目錄在映像裡是 `root:root 0755`。entrypoint
原本只 chown home 與 `.openclaw`，降權後的 OpenClaw 建不了
`~/.cache/openclaw-<uid>` 這個 SQLite worker temp dir，容器啟動即失敗並被
`--restart unless-stopped` 打進 restart loop，日誌只留下：

```
SQLite read-only worker Unable to create fallback OpenClaw temp dir:
/home/node/.cache/openclaw-<uid>
```

與 `PUID` 是多少無關（uid 1000 實測同樣 EACCES）。**只有全新 onboard 會踩到**：
home 是 named volume，Docker 只在目錄為空的首次掛載把映像的 `/home/node` 預先
複製進去，那次會把 root 所有的 `.cache` 一起帶進 volume；既有 workspace 沿用的是
OpenClaw 自己建的 `.cache`（屬 node），所以換基底映像後照樣能跑。

修在 entrypoint 而非 Dockerfile，是因為 Dockerfile 的 chown 只能修好未來的預先
複製來源，治不了已經帶著 root 所有 `.cache` 的既有 volume。

> 這兩件事同一天發現、都在 `-browser` 變體上，但**成因無關**：一個是 pnpm
> hoisting 掉了連結（只有 2026.9.1），一個是 playwright 安裝步驟的目錄擁有者
> （所有 `-browser` 變體）。不要混在一起診斷。
