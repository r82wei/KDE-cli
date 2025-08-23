# 使用最新的 Ubuntu LTS 版本作為基礎映像檔
FROM ubuntu:22.04

# 設定 KDE-cli 版本
ARG KDE_CLI_VERSION

# 設定環境變數，避免在安裝過程中出現互動式提問
ENV DEBIAN_FRONTEND=noninteractive

# 更新套件列表並安裝 sudo、Docker 的相依套件以及 gosu
# gosu 是一個輕量的 sudo 替代品，常用於切換使用者身份來執行指令
RUN apt-get update && \
    apt-get install -y \
    sudo \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    gosu

# 新增 Docker 的官方 GPG 金鑰
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 設定 Docker 的 apt repository
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 再次更新套件列表並安裝 Docker Engine
RUN apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install kde-cli
RUN set -eux; \
    git clone -b ${KDE_CLI_VERSION} https://github.com/r82wei/KDE-cli.git; \
    cd KDE-cli; \
    ./install.sh; \
    cd ..; \
    rm -rf KDE-cli

# 關閉 sudo 的密碼提示，方便容器內操作
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# 複製 entrypoint 腳本到容器內
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# 設定工作目錄
WORKDIR /home/user

# 設定 entrypoint，容器啟動時會先執行此腳本
ENTRYPOINT ["entrypoint.sh"]

# 設定容器啟動時的預設指令
CMD ["/bin/bash"]