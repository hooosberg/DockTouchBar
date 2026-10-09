#!/bin/bash
# 验证 AI 助手接入、socket 诊断和事件状态机。全程在临时目录里，不碰真实配置。
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tools
# Only compile the components under test; the settings UI and its SwiftUI macro
# plugins are not needed for a socket/state-machine regression test.
SOURCES=(
    Sources/DockTouchBar/AgentStatus.swift
    Sources/DockTouchBar/AgentRegistry.swift
    Sources/DockTouchBar/AgentFileWatcher.swift
    Sources/DockTouchBar/AgentHookInstaller.swift
    Sources/DockTouchBar/AgentPairingPrompt.swift
    Sources/DockTouchBar/AppInfo.swift
    Sources/DockTouchBar/Settings.swift
    Sources/DockTouchBar/Localization.swift
    Sources/DockTouchBar/Translations*.swift
)
swiftc "${SOURCES[@]}" tools/verify-agent-hooks/main.swift -o build/tools/verify-agent-hooks
build/tools/verify-agent-hooks "$@"
