# OPENCLAW_VERSION 是官方映像的 tag,升級 OpenClaw 等於換 tag。
ARG OPENCLAW_VERSION=latest
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}

USER root

# kde-cli 在容器內執行時需要的外部指令:
#   docker   - DooD,kde 的核心
#   git      - kde proj fetch/pull 直接在本機執行
#   envsubst - 渲染 kind/k3d config 模板 (gettext-base)
# kubectl 與 helm 不需要:那些都是丟進 deploy-env 容器裡跑的。
RUN apt-get update && apt-get install -y --no-install-recommends \
      git gettext-base ca-certificates docker.io \
 && rm -rf /var/lib/apt/lists/*

# 刻意不在映像內安裝 kde-cli。kde openclaw 啟動的每一種容器都會把主機端的
# ${KDE_CLI_PATH} 以唯讀 bind mount 蓋在 /usr/local/lib/kde 上,所以烤進映像的
# 副本必然被完全遮蔽、一次也用不到;留著的代價則是每個 CLI commit 都打掉映像的
# build cache,還多出一個永遠觀察不到的「映像內建版本」概念。
#
# 映像對 kde 的唯一義務是 /usr/local/bin/kde 這支 wrapper:它不在掛載點內,
# 是 kde 進得了 PATH 的唯一原因。完整理由見 kde-wrapper.sh 的檔頭註解。
#
# build context 是 repo 根目錄,故 COPY 來源要寫完整相對路徑
COPY dockerfiles/kde-openclaw/kde-wrapper.sh /usr/local/bin/kde
COPY dockerfiles/kde-openclaw/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/kde /usr/local/bin/entrypoint.sh

# 保留官方的 tini 當 PID 1,entrypoint 接在它後面,docker stop 的 SIGTERM 才傳得到。
# -s(subreaper)沿用官方映像自己的 ENTRYPOINT(["tini","-s","--"])選擇,不擅自拿掉。
# 上游的 HEALTHCHECK 是 `node dist/docker-healthcheck.js`——相對路徑，靠映像的
# WorkingDir=/app 解析。但 kde openclaw 啟動容器時會用 --workdir 指到 workspace
# （容器內的 kde CLI 靠 $PWD 往上找 kde.env 定位 workspace，不能不指），於是那個
# 相對路徑會解析到 <workspace>/dist/... 而找不到模組，容器永遠是 unhealthy。
# 這裡改寫成絕對路徑，其餘參數沿用上游的值。
HEALTHCHECK --interval=180s --timeout=10s --start-period=15s --retries=3 \
    CMD node /app/dist/docker-healthcheck.js

ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/usr/local/bin/entrypoint.sh"]
