#!/bin/bash

# 把 kde 安裝到 LIB_DIR，並在 BIN_DIR 建立 kde 指令的 symlink。
#
# 安裝路徑開放以環境變數覆寫，是為了讓測試不必動到真正的 /usr/local（也就不需要 root）。
LIB_DIR="${KDE_INSTALL_LIB_DIR:-/usr/local/lib/kde}"
BIN_DIR="${KDE_INSTALL_BIN_DIR:-/usr/local/bin}"

# 安全閘：LIB_DIR 是下面 find -delete 的目標，被覆寫成 / 之類的值會是災難。
case "${LIB_DIR}" in
    ""|"/"|"/usr"|"/usr/local"|"/usr/local/lib"|"/usr/local/bin")
        echo "❌ 不安全的安裝路徑 KDE_INSTALL_LIB_DIR=${LIB_DIR}，已中止" >&2
        exit 1
        ;;
esac

# 重裝時「只清空 LIB_DIR 的內容，不刪掉目錄本身」——刻意不呼叫 uninstall.sh。
#
# LIB_DIR 會被 kde openclaw 與 kde code-server 以唯讀 bind mount 掛進容器
# （見 scripts/utils/openclaw.sh、scripts/utils/code-server.sh）。bind mount 綁的是
# inode：把目錄整個 rm -rf 再建回來，運行中的容器會繼續守著那個已刪除的 inode，
# 容器內看到的是一個空目錄——症狀是 `kde: command not found`，而且再裝一次也
# 救不回來，只能重建容器。保留目錄則讓重裝對運行中的容器即時生效
# （唯讀只限制容器那一側寫入，不影響主機端更新內容）。
#
# 代價：清空到複製完成之間有一小段時間，容器內的 kde 是不完整的。改成「裝到
# 暫存目錄再 atomic 換名」可消除這個破窗，但那必然換掉 inode，與上述目的直接
# 衝突，故取此折衷。
mkdir -p "${LIB_DIR}"
find "${LIB_DIR}" -mindepth 1 -delete

cp -r kde.sh "${LIB_DIR}/"
cp -r ./scripts "${LIB_DIR}/"
cp -r ./docs "${LIB_DIR}/"
cp -r ./templates "${LIB_DIR}/"
cp -r ./.claude "${LIB_DIR}/"

# symlink 不在 LIB_DIR 內，重建它與上面的 inode 考量無關。
# 用 -f 覆寫既有的 symlink：不再先跑 uninstall.sh，沒有人幫忙把舊的移掉。
mkdir -p "${BIN_DIR}"
ln -sfn "${LIB_DIR}/kde.sh" "${BIN_DIR}/kde"

echo "安裝完成"
