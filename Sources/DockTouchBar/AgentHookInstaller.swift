import Foundation

/// 转发脚本 `agent-hook.sh`：所有智能体（用自己的 hook，或按指令手动）都通过它把事件交给 App。
/// 配置怎么改由智能体自己按“配对智能体”提示词去做，App 不再替任何一个助手改配置。
enum AgentHookInstaller {
    static var supportDirectory: URL { AgentMonitor.supportDirectory }
    static var scriptURL: URL { supportDirectory.appendingPathComponent("agent-hook.sh") }

    /// 把脚本写成当前版本（App 每次启动都写一遍）。
    static func refreshScript() throws {
        let script = """
        #!/bin/bash
        # \(AppInfo.name): forwards AI agent events to the app. Does nothing (and never fails) if the app isn't running.
        # Usage: agent-hook.sh <Event> [agent-id] [session-id] < /dev/null
        #   Event: UserPromptSubmit | PostToolUse | Stop | Interrupt | SessionEnd   (session-id is optional)
        #   agent-hook.sh --check [agent-id]      is the app reachable, which host app did it find
        #   agent-hook.sh --verify <agent-id>     the app runs the test itself and answers PASS or FAIL
        #   agent-hook.sh --register <agent-id> <display-name> <hook|instructions> <notes> [file...]   only accepted after --verify passed
        # Agents with their own hooks pipe the hook JSON on stdin; agents that call this by hand pass a session-id instead.
        SOCK="${DTB_SOCKET:-$HOME/Library/Application Support/\(AppInfo.fileName)/agent.sock}"
        case "$1" in --check|--verify|--register)
          [ -S "$SOCK" ] || { echo "NOT_RUNNING \(AppInfo.name) is not running (no socket). Ask the user to open it, then stop and wait."; exit 0; }
          MODE="$1"; ID="$2"
          case "$ID" in ""|*[!A-Za-z0-9._-]*) ID="" ;; esac
          NAME="Check"; [ "$MODE" = "--verify" ] && NAME="Verify"; [ "$MODE" = "--register" ] && NAME="Register"
          [ -n "$ID" ] && NAME="$NAME|$ID"
          EXTRA=""
          if [ "$MODE" = "--register" ]; then
            [ $# -ge 2 ] && shift 2 || shift $#
            for A in "$@"; do A="${A//$'\t'/ }"; A="${A//$'\n'/ }"; A="${A//$'\r'/ }"; EXTRA="$EXTRA$A"$'\t'; done
          fi
          # Keep diagnostics for pairing commands; normal lifecycle events below stay silent.
          REPLY="$( { printf '%s\t%s\t%s\n' "$NAME" "$PPID" "$EXTRA"; sleep 1; } | LC_ALL=C /usr/bin/nc -U -w 2 "$SOCK" 2>&1)"
          NC_STATUS=$?
          if [ "$NC_STATUS" -eq 0 ] && [ -n "$REPLY" ]; then
            printf '%s\\n' "$REPLY"
          else
            REASON=connection_failed
            case "$REPLY" in
              *"Operation not permitted"*|*"Permission denied"*) REASON=permission_denied ;;
              *"Connection refused"*) REASON=connection_refused ;;
              *"timed out"*) REASON=timeout ;;
            esac
            [ "$NC_STATUS" -ne 0 ] || REASON=no_response
            printf 'NOT_REACHABLE reason=%s nc_exit=%s. Stop and tell the user.\\n' "$REASON" "$NC_STATUS"
            printf 'socket=%s\\n' "$SOCK"
            if [ -n "$REPLY" ]; then
              printf '%s\\n' "$REPLY"
            else
              echo "nc emitted no diagnostic; the cause cannot be determined from its exit status alone."
            fi
            echo "A sandbox or local socket permissions may block access even while the app is running. Stop and report this output. Any retry outside the sandbox requires your agent's normal permission approval; do not disable the sandbox or bypass hook trust."
          fi
          exit 0 ;;
        esac
        [ -S "$SOCK" ] || exit 0
        EVENT="$1"
        case "$2" in ""|*[!A-Za-z0-9._-]*) ;; *) EVENT="$1|$2" ;; esac
        PAYLOAD=""
        [ -t 0 ] || PAYLOAD="$(/bin/cat | /usr/bin/tr -d '\\n\\r')"
        case "$3" in ""|*[!A-Za-z0-9._-]*) ;; *) [ -n "$PAYLOAD" ] || PAYLOAD="{\\"session_id\\":\\"$3\\",\\"manual\\":true}" ;; esac
        printf '%s\\t%s\\t%s\\n' "$EVENT" "$PPID" "$PAYLOAD" | /usr/bin/nc -U -w 1 "$SOCK" >/dev/null 2>&1
        exit 0
        """
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        // 早期版本的脚本，没人用了。
        try? FileManager.default.removeItem(at: supportDirectory.appendingPathComponent("claude-hook.sh"))
    }
}
