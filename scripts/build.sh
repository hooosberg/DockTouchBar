#!/bin/bash
# 编译并打包成 build/DockTouchBar.app
#
# 签名身份（按顺序选第一个可用的）：
#   1. 环境变量 SIGN_IDENTITY
#   2. 钥匙串里的 "Developer ID Application" 证书（能分发、能公证）
#   3. 钥匙串里的 "Apple Development" 证书
#   4. ad-hoc（-）
# 始终用同一个证书签名很重要：辅助功能权限绑定在签名上，换证书或用 ad-hoc 重新编译都要重新授权。
#
# RELEASE=1 时加可信时间戳（公证需要，要联网）；平时编译不加，离线也能用。
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="DockTouchBar"
APP="build/$APP_NAME.app"
# `build/` 只放中间产物；防止 Spotlight 把这里的 .app 当成第二个可启动应用。
mkdir -p build
touch build/.metadata_never_index

if [ -z "${SIGN_IDENTITY:-}" ]; then
    IDENTITIES="$(security find-identity -v -p codesigning)"
    SIGN_IDENTITY="$(awk -F'"' '/Developer ID Application/ {print $2; exit}' <<<"$IDENTITIES")"
    if [ -z "$SIGN_IDENTITY" ]; then
        SIGN_IDENTITY="$(awk -F'"' '/Apple Development/ {print $2; exit}' <<<"$IDENTITIES")"
    fi
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

# 通用二进制：arm64（Apple 芯片，已实机验证）+ x86_64（Intel，未实机验证）
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
# 去掉调试符号：链接后的二进制里带着编译机器上的源码路径（用户名、目录名）。公开发布前必须去掉，
# 也顺便让文件更小。这一步要在签名之前做。
strip -S "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

case "$SIGN_IDENTITY" in
    -)
        codesign --force --sign - "$APP" ;;
    "Developer ID"*)
        # hardened runtime 是公证的前提；App 只 dlopen 系统私有框架，不需要额外 entitlement。
        if [ "${RELEASE:-0}" = "1" ]; then
            codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
        else
            codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
        fi ;;
    *)
        codesign --force --sign "$SIGN_IDENTITY" "$APP" ;;
esac

echo "Signed with: $SIGN_IDENTITY"
echo "Built $APP"
