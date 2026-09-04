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

# 安裝 kde-cli:把 build context(repo 根目錄)整包複製進來,交給 local-install.sh 安裝。
# 要裝哪些東西完全由 local-install.sh 決定(唯一真實來源),Dockerfile 不需跟著改。
# 執行時 kde openclaw 會用 volume 把主機端的 kde-cli 蓋上來,確保版本一致。
COPY . /tmp/kde-src/
RUN cd /tmp/kde-src && bash local-install.sh && cd / && rm -rf /tmp/kde-src

# build context 是 repo 根目錄,故 COPY 來源要寫完整相對路徑
COPY dockerfiles/kde-openclaw/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

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
