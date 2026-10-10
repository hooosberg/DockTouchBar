#!/bin/bash
# 打包 build/DockTouchBar-<版本>.dmg：打开后把 App 拖进「应用程序」即可安装。
#
# 不带参数：用 Developer ID 签名 App 和 DMG，带可信时间戳（需要联网），不公证。
# 要发给别人用，需要公证。先存一次凭据（按提示输入 Apple ID、App 专用密码、Team ID，密码存进钥匙串）：
#   xcrun notarytool store-credentials DockTouchBar
# 之后带上 NOTARY_PROFILE 运行：
#   NOTARY_PROFILE=DockTouchBar scripts/make-dmg.sh
# 公证会提交两次：先公证并装订 App 本身（这样 App 从 DMG 里拖出来后离线也能通过 Gatekeeper），
# 再公证并装订 DMG。每次通常几分钟。
set -euo pipefail
cd "$(dirname "$0")/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-}"

# 公证前先确认凭据能用，免得编译完才发现不行。
if [ -n "$NOTARY_PROFILE" ]; then
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        echo "找不到可用的公证凭据「$NOTARY_PROFILE」。先运行： xcrun notarytool store-credentials $NOTARY_PROFILE" >&2
        exit 1
    fi
fi

RELEASE=1 scripts/build.sh

APP="build/DockTouchBar.app"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
DMG="build/DockTouchBar-$VERSION.dmg"
STAGING="build/dmg-staging"
SIGN_AUTHORITY="$(codesign -dvv "$APP" 2>&1 | awk -F= '/^Authority=/ && !found {print $2; found = 1}')"

# 提交给 Apple 公证，等结果；没有通过就停下，并提示怎么查原因。
notarize() {
    local output
    output="$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)" || { echo "$output" >&2; exit 1; }
    echo "$output"
    if ! grep -q "status: Accepted" <<<"$output"; then
        local id
        id="$(awk '/^ *id:/ {print $2; exit}' <<<"$output")"
        echo "公证没有通过。查看原因： xcrun notarytool log $id --keychain-profile $NOTARY_PROFILE" >&2
        exit 1
    fi
}

if [ -n "$NOTARY_PROFILE" ]; then
    case "$SIGN_AUTHORITY" in
        "Developer ID"*) ;;
        *) echo "公证需要 Developer ID 证书签名，当前是：${SIGN_AUTHORITY:-ad-hoc}" >&2; exit 1 ;;
    esac
    ZIP="build/DockTouchBar-notarize.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    notarize "$ZIP"
    rm -f "$ZIP"
    xcrun stapler staple "$APP"
fi

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "DockTouchBar $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

case "$SIGN_AUTHORITY" in
    "Developer ID"*) codesign --force --timestamp --sign "$SIGN_AUTHORITY" "$DMG" ;;
esac

if [ -n "$NOTARY_PROFILE" ]; then
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    echo "== 验证"
    xcrun stapler validate "$DMG"
    spctl -a -t open --context context:primary-signature -vv "$DMG"
fi

echo "DMG: $DMG"
