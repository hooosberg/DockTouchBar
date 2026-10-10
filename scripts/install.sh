#!/bin/bash
# 编译 → 预拷贝 → 关闭旧版 → 替换 → 启动；复制或启动命令失败时保留/恢复旧版。
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="DockTouchBar"
BUILD_APP="build/$APP_NAME.app"
INSTALL_APP="/Applications/$APP_NAME.app"
STAGE="/Applications/.DockTouchBar-install-$$.app"
BACKUP="/Applications/.DockTouchBar-local-backup-$$.app"
MOVED_OLD=0
INSTALLED_NEW=0
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cleanup() {
    STATUS=$?
    trap - EXIT
    if [ "$STATUS" -ne 0 ]; then
        if [ "$INSTALLED_NEW" -eq 1 ]; then rm -rf "$INSTALL_APP" || true; fi
        if [ "$MOVED_OLD" -eq 1 ]; then
            if mv "$BACKUP" "$INSTALL_APP"; then open "$INSTALL_APP" || true; fi
        fi
    else
        rm -rf "$BACKUP" || true
    fi
    rm -rf "$STAGE" || true
    exit "$STATUS"
}
trap cleanup EXIT

scripts/build.sh
/usr/bin/ditto "$BUILD_APP" "$STAGE"
/usr/bin/codesign --verify --deep --strict "$STAGE"
pkill -x "$APP_NAME" 2>/dev/null || true
for i in {1..50}; do
    if ! pgrep -x "$APP_NAME" >/dev/null; then break; fi
    sleep 0.2
done
if pgrep -x "$APP_NAME" >/dev/null; then
    echo "Old DockTouchBar did not exit; installation aborted." >&2
    exit 1
fi
if [ -d "$INSTALL_APP" ]; then
    mv "$INSTALL_APP" "$BACKUP"
    MOVED_OLD=1
fi
mv "$STAGE" "$INSTALL_APP"
INSTALLED_NEW=1
open "$INSTALL_APP"
# 正式安装完成后，中间 .app 不应继续作为第二个 LaunchServices/Spotlight 候选项存在。
"$LSREGISTER" -u "$BUILD_APP" 2>/dev/null || true
rm -rf "$BUILD_APP"
echo "Installed $INSTALL_APP"
