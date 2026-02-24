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
