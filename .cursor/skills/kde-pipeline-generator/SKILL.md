---
name: kde-pipeline-generator
description: Automatically detects tech stack from a KDE project directory and generates complete pipeline configuration (project.env + shell scripts). Use when the user asks to set up a pipeline, generate pipeline config, auto-detect project type, scaffold KDE project scripts, or create build/deploy scripts for a KDE project.
---

# KDE Pipeline Generator

自動偵測 KDE 專案技術棧，與使用者互動後產生完整的 `project.env` + 所有 Pipeline shell 腳本。

## 執行流程

### Phase 1：確認目標目錄

首先確認專案所在路徑。KDE 專案結構為：
```
environments/<env_name>/namespaces/<project_name>/
```

如果使用者未指定，詢問：
- 當前環境名稱（或請使用者指向 namespaces/<project>/ 目錄）
- 專案名稱

**掃描 repo 目錄**：在 `namespaces/<project_name>/` 下尋找 Git repo 子目錄（或直接在該目錄中偵測）。

### Phase 2：偵測技術棧

依優先順序尋找以下指標檔案：

| 偵測檔案 | 技術棧 | 預設 DEVELOP_IMAGE |
|---------|--------|-------------------|
| `package.json` | Node.js | `node:20` |
| `go.mod` | Go | `golang:1.21` |
| `requirements.txt` / `pyproject.toml` / `Pipfile` / `setup.py` | Python | `python:3.11` |
| `pom.xml` | Java (Maven) | `maven:3.9-eclipse-temurin-21` |
| `build.gradle` / `build.gradle.kts` | Java (Gradle) | `gradle:8-jdk21` |
| `Cargo.toml` | Rust | `rust:1.75` |
| `composer.json` | PHP | `php:8.2-cli` |
| `Gemfile` | Ruby | `ruby:3.3` |
| `Dockerfile` 存在（其他無匹配） | 已容器化 | `docker:latest` |

同時偵測部署方式（掃描 repo 內目錄和檔案）：

| 偵測條件 | 部署方式 |
|---------|---------|
| `helm/` 或 `charts/` 目錄存在 | Helm |
| `k8s/` 或 `kubernetes/` 目錄存在 | kubectl raw YAML |
| `kustomization.yaml` 存在 | Kustomize |
| 以上皆無 | 待使用者選擇 |

### Phase 3：與使用者互動確認

偵測完成後，整理偵測結果並向使用者確認以下資訊（用一段摘要呈現，請使用者逐一確認或修改）：

**必要資訊**：
1. **技術棧**：顯示偵測結果，請確認或修改
2. **Pipeline 階段**：詢問要包含哪些階段（必選 build + deploy，可選 test / lint / release / security-scan）
3. **部署方式**：顯示偵測結果，若未偵測到請選擇（kubectl / Helm / Kustomize）
4. **App Port**：應用程式監聽的 port（用於 Service YAML）
5. **Namespace**：通常等於專案名稱，確認是否一致

**選擇性資訊**（根據回答決定是否詢問）：
- 若選擇 **release 階段** → 詢問 Container Registry URL（例如 `registry.example.com`）
- 若部署到**外部 K8s**（ENV_TYPE=k8s）→ 建議加入 `undeploy.sh`，詢問是否需要
- 若 **Helm**：詢問 chart 路徑（預設 `./helm/<project_name>` 或 `./charts/<project_name>`）

### Phase 4：產生檔案

根據確認的資訊，使用 [templates.md](templates.md) 中的對應模板產生以下檔案，寫入 `namespaces/<project_name>/`：

| 檔案 | 條件 |
|------|------|
| `project.env` | 必要 |
| `build.sh` | 必要 |
| `test.sh` | 包含 test 階段時 |
| `lint.sh` | 包含 lint 階段時（自動設 MANUAL_ONLY）|
| `release.sh` | 包含 release 階段時（使用 private registry）|
| `deploy.sh` | 必要 |
| `undeploy.sh` | 使用者要求，或外部 K8s 環境 |

產生後，對每個檔案執行 `chmod +x` 並向使用者說明各腳本的功能。

---

## project.env 產生規則

```bash
# Git（若使用者有提供）
GIT_REPO_URL=<url>
GIT_REPO_BRANCH=main

# 映像
DEVELOP_IMAGE=<偵測到的映像>
DEPLOY_IMAGE=r82wei/deploy-env:1.0.0

# 應用配置
APP_NAME=<project_name>
APP_PORT=<port>
NAMESPACE=<project_name>

# Pipeline 階段（根據使用者選擇）
KDE_PIPELINE_STAGES="<stage1>,<stage2>,..."

# 各階段配置
KDE_PIPELINE_STAGE_<stage>_IMAGE=<image>
KDE_PIPELINE_STAGE_<stage>_SCRIPT=<stage>.sh

# lint 階段自動加旗標
KDE_PIPELINE_STAGE_lint_MANUAL_ONLY=true
KDE_PIPELINE_STAGE_lint_ALLOW_FAILURE=true

# 若有 private registry
DOCKER_REGISTRY=<registry_url>

# Helm（若使用 Helm）
HELM_CONFIG_HOME=${PROJECT_PATH}/.helm/config
HELM_CACHE_HOME=${PROJECT_PATH}/.helm/cache
HELM_DATA_HOME=${PROJECT_PATH}/.helm/data
HELM_PLUGINS=${PROJECT_PATH}/.helm/plugins
```

---

## 階段間資料傳遞

若 Pipeline 包含 `release` 階段，提醒使用者：

```bash
# release.sh 輸出
echo "APP_IMAGE=${DOCKER_REGISTRY}/${APP_NAME}:${VERSION}" >> .pipeline.env

# deploy.sh 讀取
source .pipeline.env
# 使用 ${APP_IMAGE}
```

---

## 注意事項

- `project.env` 和 `*.sh` 腳本應納入版本控制
- 敏感資訊（密碼、Token）應放在 `.env`，不要放進 `project.env`
- `undeploy.sh` 在外部 K8s 環境為**必要**（缺少時 kde 會拒絕執行 undeploy）
- 本地 Kind/K3D 環境若缺少 `undeploy.sh`，系統預設刪除整個 namespace（通常可接受）
- 所有腳本第一行應有 `#!/bin/bash` 和 `set -e`

---

## 腳本模板

完整的各語言腳本模板請參考 [templates.md](templates.md)。
