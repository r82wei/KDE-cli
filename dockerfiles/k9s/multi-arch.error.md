# K9s 映像建置說明

本文件說明自建 K9s Docker 映像時，若使用 [k9s 官方 Dockerfile](https://github.com/derailed/k9s/blob/v0.50.18/Dockerfile) 或類似寫法，在 **多平台建置（multi-arch）** 時可能遇到的問題與修正方式。

## 問題：BUILDPLATFORM 導致架構錯誤

### 症狀

在 ARM64 機器（如 Apple Silicon、Raspberry Pi）執行 K9s，按 `s` 進入 Pod Shell 時出現：

```
Shell exec failed: command failed. Check k9s logs: fork/exec /usr/local/bin/kubectl: exec format error
```

### 原因

官方 Dockerfile 的**最終階段**若使用：

```dockerfile
FROM --platform=$BUILDPLATFORM alpine:3.23.0
```

- `BUILDPLATFORM` 是**建置機**的架構（例如 amd64），不是**目標**架構。
- 使用 `docker buildx build --platform linux/amd64,linux/arm64` 時，建 **arm64** 映像的那次建置若建置機是 amd64，最終階段仍會用 **amd64 Alpine**。
- 在 amd64 容器裡執行 `arch` 會得到 `x86_64`，因此會下載 **amd64 的 kubectl**，被打進標成 arm64 的映像。
- 在 ARM64 主機執行該映像時，k9s 呼叫容器內的 kubectl → 實際是 amd64 二進位 → **exec format error**。

### 修正方式

最終階段應依**目標架構**選擇 base 並下載對應的 kubectl，使用 **`TARGETPLATFORM` / `TARGETARCH`**，不要用 `BUILDPLATFORM`，也不要依賴執行時的 `arch`。

#### 錯誤寫法（節錄）

```dockerfile
FROM --platform=$BUILDPLATFORM alpine:3.23.0
ARG KUBECTL_VERSION="v1.32.2"

COPY --from=build /k9s/execs/k9s /bin/k9s
RUN apk --no-cache add --update ca-certificates \
  && apk --no-cache add --update -t deps curl vim \
  && TARGET_ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) \
  && curl -f -L https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGET_ARCH}/kubectl -o /usr/local/bin/kubectl \
  ...
```

#### 正確寫法（節錄）

```dockerfile
FROM --platform=$TARGETPLATFORM alpine:3.23.0
ARG TARGETPLATFORM
ARG TARGETARCH
ARG KUBECTL_VERSION="v1.32.2"

COPY --from=build /k9s/execs/k9s /bin/k9s
RUN apk --no-cache add --update ca-certificates \
  && apk --no-cache add --update -t deps curl vim \
  && curl -f -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
  && chmod +x /usr/local/bin/kubectl \
  && apk del --purge deps

ENTRYPOINT [ "/bin/k9s" ]
```

| 項目 | 錯誤 | 正確 |
|------|------|------|
| 最終階段 base | `FROM --platform=$BUILDPLATFORM` | `FROM --platform=$TARGETPLATFORM` |
| 宣告 ARG | 無 | `ARG TARGETPLATFORM`、`ARG TARGETARCH` |
| kubectl 架構 | `arch \| sed ...`（依執行環境） | 直接用 `${TARGETARCH}`（buildx 會帶入 arm64/amd64） |

---

## 建置方式

### 單機多平台建置並 push

```bash
export K9S_VERSION=0.50.18  # 依需要設定

docker buildx build --no-cache --platform linux/amd64,linux/arm64 --push \
  -t r82wei/k9s:${K9S_VERSION} .
```

### 各平台分別建置、再合併成同一 tag

在不同機器各自 build 並 push 架構專用 tag，再組出多架構的 `latest`（或版本 tag）：

**在 amd64 機器：**
```bash
docker buildx build --no-cache --platform linux/amd64 \
  -t r82wei/k9s:latest-amd64 --push .
```

**在 arm64 機器：**
```bash
docker buildx build --no-cache --platform linux/arm64 \
  -t r82wei/k9s:latest-arm64 --push .
```

**在任一台已登入 registry 的機器，合成多架構 manifest：**
```bash
docker buildx imagetools create -t r82wei/k9s:latest \
  r82wei/k9s:latest-amd64 \
  r82wei/k9s:latest-arm64
```

### 僅本機使用、不 push

只建當前架構並載入本機：

```bash
docker buildx build --no-cache --load -t r82wei/k9s:${K9S_VERSION} .
```

---

## 驗證

建置完成後可檢查映像與容器內 kubectl 架構：

```bash
# 映像架構
docker image inspect --format '{{.Architecture}}' r82wei/k9s:latest

# 容器內 kubectl 的架構（應與映像一致）
docker run --rm --entrypoint file r82wei/k9s:latest /usr/local/bin/kubectl
# 在 ARM64 主機應顯示：ELF 64-bit LSB executable, ARM aarch64
```

---

## 相關文件

- K9s 使用與故障排除（含 ARM64 exec format error 症狀）：[kde-cli/core/dev-tools/k9s.md](kde-cli/core/dev-tools/k9s.md)
- [Docker Buildx 多平台建置](https://docs.docker.com/build/building/multi-platform/)
