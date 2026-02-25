# Docker image 建置 - K9S 

## 建置方式

### 單機多平台建置並 push

```bash
./release.sh
```

### 僅本機使用、不 push

只建當前架構並載入本機：

```bash
./build.sh
```

---

## 相關文件

- [K9S Github](https://github.com/derailed/k9s)
- [Docker Buildx 多平台建置](https://docs.docker.com/build/building/multi-platform/)
