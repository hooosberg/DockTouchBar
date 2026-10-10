#!/usr/bin/env bash
# 本地开发入口：关旧进程 → 构建真实 .app 包 → 启动；不安装到 /Applications。
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DockTouchBar"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"

build() {
    "$ROOT_DIR/scripts/build.sh"
}

stop_running() {
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    run|--run)
        stop_running
        build
        open_app
        ;;
    --debug|debug)
        stop_running
        build
        lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
        ;;
    --logs|logs)
        stop_running
        build
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        stop_running
        build
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --verify|verify)
        stop_running
        build
        open_app
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
