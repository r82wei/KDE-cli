ARG WEBTOP_VERSION
FROM lscr.io/linuxserver/webtop:${WEBTOP_VERSION:-ubuntu-kde}

ARG OPENCLAW_VERSION
ENV OPENCLAW_VERSION=${OPENCLAW_VERSION}

# 安裝 kde-cli:直接把 build context(repo 根目錄)整包複製進來,交給 local-install.sh 安裝,
# 不再對外 clone。要裝哪些東西完全由 local-install.sh 決定(唯一真實來源),Dockerfile 不需跟著改。
# 情境 1(獨立啟動)用這份 baked-in;情境 2(kde code-server)會以 volume 覆蓋掉。
COPY . /tmp/kde-src/
RUN cd /tmp/kde-src && bash local-install.sh && cd / && rm -rf /tmp/kde-src

### install openclaw ###
RUN curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard

