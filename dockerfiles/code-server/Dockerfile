FROM codercom/code-server:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    git \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Add the Docker repository to Apt sources (Debian base image)
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && rm -rf /var/lib/apt/lists/*

# 安裝 kde-cli:直接把 build context(repo 根目錄)整包複製進來,交給 local-install.sh 安裝,
# 不再對外 clone。要裝哪些東西完全由 local-install.sh 決定(唯一真實來源),Dockerfile 不需跟著改。
# 情境 1(獨立啟動)用這份 baked-in;情境 2(kde code-server)會以 volume 覆蓋掉。
COPY . /tmp/kde-src/
RUN cd /tmp/kde-src && bash local-install.sh && cd / && rm -rf /tmp/kde-src

# AI agent 安裝機制：
# - /entrypoint.d 是 code-server base image 內建的啟動 hook(coder/code-server#5177),
#   base entrypoint 會在啟動 code-server 前執行其中所有可執行檔。用它就不必覆寫
#   ENTRYPOINT(內建的 --bind-addr 0.0.0.0:8080 . 等參數不必手動複製)。
# - 新增 agent 只要往 agents/ 丟一支 install-<name>.sh,不需改 entrypoint 邏輯。
COPY dockerfiles/code-server/entrypoint.d/ /entrypoint.d/
COPY dockerfiles/code-server/agents/ /usr/local/lib/kde-agents/
RUN chmod 0755 /entrypoint.d/*.sh /usr/local/lib/kde-agents/*.sh

USER coder