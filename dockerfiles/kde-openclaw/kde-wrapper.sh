#!/bin/bash

# 容器內 /usr/local/bin/kde 的實體：把 kde 指令轉交給主機端掛進來的 CLI。
#
# 本映像刻意「不」內建 kde-cli。kde openclaw 啟動的每一種容器（狀態檢查的一次性
# 容器、onboard、gateway）都會把主機端的 ${KDE_CLI_PATH} 以唯讀 bind mount 蓋在
# /usr/local/lib/kde 上（見 scripts/utils/openclaw.sh 的 build_openclaw_docker_args），
# 所以任何烤進映像的副本都必然被完全遮蔽、一次也用不到；留著只會讓每個 CLI commit
# 都打掉映像的 build cache，並製造一個永遠觀察不到的「映像內建版本」概念。
#
# 真正必須留在映像裡的只有這支 wrapper：它位於 /usr/local/bin，不在掛載點內，
# 是 `kde` 進得了 PATH 的唯一原因。
#
# 為什麼掛載是唯一的版本來源、而不是可選項：workspace 是「讀寫」掛進容器的，
# 容器內外的 kde 會寫同一批 state（current.env、k8s.env、.pipeline.env、
# kubeconfig）。版本歪掉不是功能少一點，是兩邊互相寫壞對方認得的格式。
#
# 刻意不用裸 symlink：掛載缺席時 symlink 只會得到
# `bash: /usr/local/bin/kde: No such file or directory`，指向 symlink 自己而不是
# 真正的原因，非常難診斷。
#
# 路徑開放以環境變數覆寫，是為了讓測試不必真的建出 /usr/local/lib/kde
# （與 entrypoint.sh 的 OPENCLAW_HOME_DIR 同一個理由）。
KDE_LIB_DIR="${KDE_LIB_DIR:-/usr/local/lib/kde}"

if [[ ! -x "${KDE_LIB_DIR}/kde.sh" ]]; then
    echo "❌ 容器內找不到 kde CLI：${KDE_LIB_DIR}/kde.sh 不存在或不可執行。" >&2
    echo "   本映像刻意不內建 kde，一律使用主機端掛入的版本，以免與 workspace 的版本歪掉。" >&2
    echo "   常見成因：容器啟動之後，主機端把該目錄整個換掉了（舊版 local-install.sh" >&2
    echo "   會 rm -rf 再重建，bind mount 於是守著已刪除的 inode，看起來就是空目錄）。" >&2
    echo "   修法：重建容器 —— kde openclaw stop && kde openclaw run" >&2
    exit 1
fi

exec "${KDE_LIB_DIR}/kde.sh" "$@"
