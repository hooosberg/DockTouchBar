import Foundation
import AppKit

/// 新版本更新信息
struct UpdateReleaseInfo: Equatable {
    let version: String
    let title: String
    let notes: String
    let releaseURL: URL
    let assetName: String
    let downloadURL: URL
    let assetSize: Int64
}

/// 自动检测与安装更新管理器（遵循 macOS 安全与签名校验规范）
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    enum State: Equatable {
        case idle
        case checking
        case upToDate(Date)
        case available(UpdateReleaseInfo)
        case downloading(progress: Double)
        case verifying
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var currentRelease: UpdateReleaseInfo?
    private var currentTempDir: URL?
    private var downloadObservation: NSKeyValueObservation?

    private let releasesAPI = URL(string: "https://api.github.com/repos/hooosberg/DockTouchBar/releases/latest")!

    override init() {
        super.init()
    }

    // MARK: - 检查更新

    /// 检查新版本。silent 为 true 时如果已是最新版本则不打扰用户（用于启动或后台静默检查）
    func checkForUpdates(silent: Bool = false) {
        switch state {
        case .checking, .downloading, .verifying, .installing:
            return
        default:
            executeCheck(silent: silent)
        }
    }

    private func executeCheck(silent: Bool) {
        state = .checking

        var request = URLRequest(url: releasesAPI, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("DockTouchBar/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                // GitHub API 对未登录请求按 IP 限流（每小时 60 次），共用网络/VPN 时很容易被占满，
                // 返回 403。任何 API 失败都改走不限流的网页重定向，避免用户看到“服务器响应异常”。
                if let error {
                    self.fallbackCheck(silent: silent, failure: L10n.tr("检查更新失败：\(error.localizedDescription)", "Check failed: \(error.localizedDescription)"))
                    return
                }
                guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                    self.fallbackCheck(silent: silent, failure: L10n.tr("更新服务器响应异常", "Update server returned an error"))
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.fallbackCheck(silent: silent, failure: L10n.tr("解析更新信息失败", "Failed to parse update info"))
                    return
                }

                self.parseReleaseResponse(json, silent: silent)
            }
        }.resume()
    }

    /// 备用检查：请求 github.com/…/releases/latest 网页，跟随重定向后从最终地址 `/releases/tag/<tag>` 取版本号，
    /// 安装包地址按发布约定 `DockTouchBar-<版本>.dmg` 拼出。拿不到更新说明和文件大小，但不受 API 限流影响。
    private func fallbackCheck(silent: Bool, failure: String) {
        let page = AppInfo.repositoryURL.appendingPathComponent("releases/latest")
        var request = URLRequest(url: page, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "HEAD"
        request.setValue("DockTouchBar/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let final = response?.url, final.pathComponents.contains("tag"),
                      let tag = final.pathComponents.last, !tag.isEmpty else {
                    self.state = silent ? .idle : .failed(failure)
                    return
                }
                let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
                let assetName = "\(AppInfo.name)-\(version).dmg"
                let download = AppInfo.repositoryURL.appendingPathComponent("releases/download/\(tag)/\(assetName)")
                self.parseReleaseResponse([
                    "tag_name": tag,
                    "name": "\(AppInfo.name) \(version)",
                    "body": "",
                    "html_url": final.absoluteString,
                    "assets": [["name": assetName, "browser_download_url": download.absoluteString, "size": 0]],
                ], silent: silent)
            }
        }.resume()
    }

    private func parseReleaseResponse(_ json: [String: Any], silent: Bool) {
        let tagName = (json["tag_name"] as? String) ?? ""
        let cleanVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
        let currentVersion = AppInfo.version.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))

        guard !cleanVersion.isEmpty else {
            state = silent ? .idle : .failed(L10n.tr("未找到有效的版本标签", "No valid version tag found"))
            return
        }

        // 版本比对
        let hasNew = Self.isVersion(cleanVersion, greaterThan: currentVersion)
        if !hasNew {
            state = .upToDate(Date())
            return
        }

        // 寻找合适的更新包资产（优先找 .dmg，其次找 .zip）
        guard let assets = json["assets"] as? [[String: Any]] else {
            state = silent ? .idle : .failed(L10n.tr("新版本未包含可下载的安装包", "No downloadable package in the new release"))
            return
        }

        var matchedAsset: (name: String, url: URL, size: Int64)?
        for item in assets {
            guard let name = item["name"] as? String,
                  let downloadStr = item["browser_download_url"] as? String,
                  let downloadURL = URL(string: downloadStr) else { continue }
            let size = (item["size"] as? Int64) ?? 0

            if name.hasSuffix(".dmg") {
                matchedAsset = (name, downloadURL, size)
                break
            } else if name.hasSuffix(".zip") && matchedAsset == nil {
                matchedAsset = (name, downloadURL, size)
            }
        }

        guard let asset = matchedAsset else {
            state = silent ? .idle : .failed(L10n.tr("未找到适配的 macOS 安装包 (.dmg)", "No macOS installer (.dmg) found"))
            return
        }

        let title = (json["name"] as? String) ?? tagName
        let notes = (json["body"] as? String) ?? ""
        let releaseURLStr = (json["html_url"] as? String) ?? AppInfo.repositoryURL.absoluteString
        let releaseURL = URL(string: releaseURLStr) ?? AppInfo.repositoryURL

        let releaseInfo = UpdateReleaseInfo(
            version: cleanVersion,
            title: title,
            notes: notes,
            releaseURL: releaseURL,
            assetName: asset.name,
            downloadURL: asset.url,
            assetSize: asset.size
        )
        self.currentRelease = releaseInfo
        self.state = .available(releaseInfo)
    }

    // MARK: - 下载并安装

    /// 开始下载并按照苹果规范校验后替换安装
    func startInstall() {
        guard case .available(let info) = state, currentRelease != nil else { return }
        state = .downloading(progress: 0.0)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DockTouchBarUpdate-\(UUID().uuidString)")
        self.currentTempDir = tempDir
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            currentTempDir = nil
            state = .failed(error.localizedDescription)
            return
        }

        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        self.downloadSession = session

        var request = URLRequest(url: info.downloadURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
        request.setValue("DockTouchBar/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        let task = session.downloadTask(with: request)
        self.downloadTask = task
        task.resume()
    }

    /// 取消下载
    func cancel() {
        guard case .downloading = state else { return }
        downloadTask?.cancel()
        downloadTask = nil
        downloadSession?.invalidateAndCancel()
        downloadSession = nil
        if let dir = currentTempDir {
            try? FileManager.default.removeItem(at: dir)
            currentTempDir = nil
        }
        if let release = currentRelease {
            state = .available(release)
        } else {
            state = .idle
        }
    }

    // MARK: - 解包、安全校验与安装替换

    private func processDownloadedFile(at downloadedLocation: URL) {
        guard let tempDir = currentTempDir, let release = currentRelease else {
            state = .failed(L10n.tr("升级临时目录无效", "Invalid update directory"))
            try? FileManager.default.removeItem(at: downloadedLocation)
            return
        }

        let localFile = tempDir.appendingPathComponent(release.assetName)
        do {
            try FileManager.default.moveItem(at: downloadedLocation, to: localFile)
        } catch {
            state = .failed(L10n.tr("保存安装文件失败：\(error.localizedDescription)", "Failed to save downloaded file"))
            try? FileManager.default.removeItem(at: downloadedLocation)
            return
        }

        state = .verifying

        // 在后台线程解包与校验
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let extractedAppURL = try self.extractApp(from: localFile, in: tempDir)
                // 苹果安全规范校验（代码签名、Team ID、Bundle ID 完整性）
                try self.verifyAppleCodeSignature(for: extractedAppURL)

                DispatchQueue.main.async {
                    self.state = .installing
                }

                // 执行替换并重启
                try self.replaceAndRestart(newAppURL: extractedAppURL, tempDir: tempDir)
            } catch {
                DispatchQueue.main.async {
                    self.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// 解包 DMG 或 ZIP
    private func extractApp(from packageURL: URL, in workingDir: URL) throws -> URL {
        let isDMG = packageURL.pathExtension.lowercased() == "dmg"
        let isZIP = packageURL.pathExtension.lowercased() == "zip"

        if isDMG {
            return try extractFromDMG(dmgURL: packageURL, workingDir: workingDir)
        } else if isZIP {
            return try extractFromZIP(zipURL: packageURL, workingDir: workingDir)
        } else {
            throw UpdateError.unsupportedPackageFormat
        }
    }

    private func extractFromDMG(dmgURL: URL, workingDir: URL) throws -> URL {
        // 使用 hdiutil attach 挂载
        let attachProcess = Process()
        attachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attachProcess.arguments = ["attach", dmgURL.path, "-nobrowse", "-readonly", "-plist"]

        let pipe = Pipe()
        attachProcess.standardOutput = pipe
        attachProcess.standardError = Pipe()
        try attachProcess.run()
        attachProcess.waitUntilExit()

        guard attachProcess.terminationStatus == 0 else {
            throw UpdateError.failedToMountDMG
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        var mountPoint: String?
        if let plist = try? PropertyListSerialization.propertyList(from: outputData, options: [], format: nil) as? [String: Any],
           let entities = plist["system-entities"] as? [[String: Any]] {
            for entity in entities {
                if let point = entity["mount-point"] as? String {
                    mountPoint = point
                    break
                }
            }
        }

        guard let mount = mountPoint else {
            throw UpdateError.failedToFindMountPoint
        }

        defer {
            // 确保卸载 DMG
            let detachProcess = Process()
            detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detachProcess.arguments = ["detach", mount, "-force"]
            if (try? detachProcess.run()) != nil { detachProcess.waitUntilExit() }
        }

        let mountedAppURL = URL(fileURLWithPath: mount).appendingPathComponent("DockTouchBar.app")
        guard FileManager.default.fileExists(atPath: mountedAppURL.path) else {
            throw UpdateError.appNotFoundInPackage
        }

        let targetAppURL = workingDir.appendingPathComponent("DockTouchBar.app")
        if FileManager.default.fileExists(atPath: targetAppURL.path) {
            try? FileManager.default.removeItem(at: targetAppURL)
        }

        // 使用 ditto 或 cp 完整复制（保留所有权限和扩展属性）
        let copyProcess = Process()
        copyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        copyProcess.arguments = [mountedAppURL.path, targetAppURL.path]
        try copyProcess.run()
        copyProcess.waitUntilExit()

        guard copyProcess.terminationStatus == 0, FileManager.default.fileExists(atPath: targetAppURL.path) else {
            throw UpdateError.failedToCopyApp
        }

        return targetAppURL
    }

    private func extractFromZIP(zipURL: URL, workingDir: URL) throws -> URL {
        let unzipProcess = Process()
        unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzipProcess.arguments = ["-x", "-k", zipURL.path, workingDir.path]
        try unzipProcess.run()
        unzipProcess.waitUntilExit()

        guard unzipProcess.terminationStatus == 0 else {
            throw UpdateError.failedToExtractZIP
        }

        let appURL = workingDir.appendingPathComponent("DockTouchBar.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw UpdateError.appNotFoundInPackage
        }
        return appURL
    }

    // MARK: - 苹果安全规范代码签名验证

    /// 严格验证新 App 的代码签名完整性和 Team ID
    private func verifyAppleCodeSignature(for appURL: URL) throws {
        // 1. 验证签名完整性（无篡改）
        let verifyProcess = Process()
        verifyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        verifyProcess.arguments = ["--verify", "--deep", "--strict", appURL.path]
        try verifyProcess.run()
        verifyProcess.waitUntilExit()

        guard verifyProcess.terminationStatus == 0 else {
            throw UpdateError.codeSignatureInvalid
        }

        // 2. 检查 Bundle Identifier
        let infoPlistPath = appURL.appendingPathComponent("Contents/Info.plist").path
        guard let infoData = try? Data(contentsOf: URL(fileURLWithPath: infoPlistPath)),
              let infoPlist = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any],
              let bundleID = infoPlist["CFBundleIdentifier"] as? String,
              bundleID == "com.maohuhu.docktouchbar" else {
            throw UpdateError.bundleIDMismatch
        }

        // 3. 检查 Team ID 是否与当前 App 一致（防止冒名替换）
        let currentTeamID = Self.extractTeamID(for: Bundle.main.bundleURL)
        let newTeamID = Self.extractTeamID(for: appURL)

        guard let currentTeamID, !currentTeamID.isEmpty, currentTeamID != "not set",
              newTeamID == currentTeamID else {
            throw UpdateError.teamIDMismatch
        }
    }

    private static func extractTeamID(for bundleURL: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dvv", bundleURL.path]
        let pipe = Pipe()
        process.standardError = pipe
        do { try process.run() } catch { return nil }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.components(separatedBy: .newlines) {
            if line.hasPrefix("TeamIdentifier=") {
                return line.replacingOccurrences(of: "TeamIdentifier=", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - 替换并重启

    private func replaceAndRestart(newAppURL: URL, tempDir: URL) throws {
        let targetAppURL = Bundle.main.bundleURL
        let currentPID = ProcessInfo.processInfo.processIdentifier

        // 编写安全的外部替换重启脚本
        let scriptURL = tempDir.appendingPathComponent("update_and_restart.sh")
        try Self.replacementScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
        // 路径通过参数传递，不插入 shell 源码（路径可以包含空格、引号、$ 或反引号）。
        launcher.arguments = [scriptURL.path, String(currentPID), newAppURL.path, targetAppURL.path, tempDir.path]
        let logURL = tempDir.appendingPathComponent("install.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }
        launcher.standardOutput = log
        launcher.standardError = log
        try launcher.run()

        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    /// 同一目录预拷贝，旧包改名保留；安装或启动命令失败时回退。失败时保留临时目录和日志。
    static let replacementScript = """
        #!/bin/bash
        set -euo pipefail
        PID="$1"
        SRC="$2"
        DEST="$3"
        TEMP="$4"
        case "$PID" in ''|*[!0-9]*) exit 64 ;; esac
        case "$DEST" in /*.app) ;; *) exit 64 ;; esac
        [ -d "$SRC" ] && [ -d "$DEST" ] && [ -d "$TEMP" ] || exit 1
        PARENT="$(dirname "$DEST")"
        STAGE="$PARENT/.DockTouchBar-update-$$.app"
        BACKUP="$PARENT/.DockTouchBar-backup-$$.app"
        MOVED_OLD=0
        cleanup() {
            STATUS=$?
            trap - EXIT
            if [ "$STATUS" -ne 0 ] && [ "$MOVED_OLD" -eq 1 ]; then
                # 即使删除失败，也继续尝试回退；旧包备份不会被失败清理删除。
                rm -rf "$DEST" || true
                if mv "$BACKUP" "$DEST"; then
                    /usr/bin/open -n "$DEST" || true
                fi
            fi
            rm -rf "$STAGE" || true
            if [ "$STATUS" -eq 0 ]; then
                rm -rf "$BACKUP" "$TEMP" || true
            fi
            exit "$STATUS"
        }
        trap cleanup EXIT

        /usr/bin/ditto "$SRC" "$STAGE"

        # 等待旧进程安全退出（最多等待 10 秒）
        for i in {1..50}; do
            if ! kill -0 "$PID" 2>/dev/null; then
                break
            fi
            sleep 0.2
        done
        if kill -0 "$PID" 2>/dev/null; then
            echo "Old process did not exit; installation aborted." >&2
            exit 1
        fi

        mv "$DEST" "$BACKUP"
        MOVED_OLD=1
        mv "$STAGE" "$DEST"
        /usr/bin/open -n "$DEST"
        """

    // MARK: - 版本比对算法

    static func isVersion(_ newVer: String, greaterThan currentVer: String) -> Bool {
        let cleanNew = newVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
        let cleanCurrent = currentVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n"))
        func parts(_ value: String) -> [Int]? {
            let segments = value.split(separator: ".", omittingEmptySubsequences: false)
            guard !segments.isEmpty, segments.allSatisfy({ !$0.isEmpty && $0.allSatisfy { ("0"..."9").contains($0) } }) else { return nil }
            let numbers = segments.compactMap { Int($0) }
            return numbers.count == segments.count ? numbers : nil
        }
        guard let newParts = parts(cleanNew), let currentParts = parts(cleanCurrent) else { return false }
        let maxCount = max(newParts.count, currentParts.count)
        for i in 0..<maxCount {
            let n = i < newParts.count ? newParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if n > c { return true }
            if n < c { return false }
        }
        return false
    }
}

// MARK: - URLSessionDownloadDelegate

extension UpdateManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            if self.downloadSession === session, self.downloadTask === downloadTask, case .downloading = self.state {
                self.state = .downloading(progress: progress)
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // URLSession 的临时文件只在回调期间有效：先保存，再回主线程核对是否还是当前下载。
        let staged = FileManager.default.temporaryDirectory.appendingPathComponent("DockTouchBarDownload-\(UUID().uuidString)")
        let result: Result<URL, Error>
        do {
            guard let response = downloadTask.response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
            try FileManager.default.moveItem(at: location, to: staged)
            result = .success(staged)
        } catch { result = .failure(error) }
        DispatchQueue.main.async {
            guard self.downloadSession === session, self.downloadTask === downloadTask,
                  case .downloading = self.state else {
                try? FileManager.default.removeItem(at: staged)
                return
            }
            self.downloadTask = nil
            self.downloadSession = nil
            session.finishTasksAndInvalidate()
            switch result {
            case .success(let location): self.processDownloadedFile(at: location)
            case .failure(let error): self.state = .failed(error.localizedDescription)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, (error as NSError).code != NSURLErrorCancelled {
            DispatchQueue.main.async {
                guard self.downloadSession === session, self.downloadTask === task else { return }
                self.downloadTask = nil
                self.downloadSession = nil
                session.finishTasksAndInvalidate()
                self.state = .failed(L10n.tr("下载出错：\(error.localizedDescription)", "Download error: \(error.localizedDescription)"))
            }
        }
    }
}

// MARK: - 错误定义

enum UpdateError: LocalizedError {
    case unsupportedPackageFormat
    case failedToMountDMG
    case failedToFindMountPoint
    case appNotFoundInPackage
    case failedToCopyApp
    case failedToExtractZIP
    case codeSignatureInvalid
    case bundleIDMismatch
    case teamIDMismatch

    var errorDescription: String? {
        switch self {
        case .unsupportedPackageFormat:
            return L10n.tr("不支持的安装包格式", "Unsupported package format")
        case .failedToMountDMG:
            return L10n.tr("无法挂载更新镜像 (DMG)", "Failed to mount DMG image")
        case .failedToFindMountPoint:
            return L10n.tr("找不到镜像挂载路径", "Failed to locate DMG mount point")
        case .appNotFoundInPackage:
            return L10n.tr("安装包中未找到应用实体", "DockTouchBar.app not found in package")
        case .failedToCopyApp:
            return L10n.tr("解压应用失败", "Failed to extract application")
        case .failedToExtractZIP:
            return L10n.tr("解压 ZIP 安装包失败", "Failed to unzip package")
        case .codeSignatureInvalid:
            return L10n.tr("安装包代码签名验证未通过，已被安全拦截", "Code signature verification failed (blocked for security)")
        case .bundleIDMismatch:
            return L10n.tr("安装包应用标识不匹配", "Bundle Identifier mismatch")
        case .teamIDMismatch:
            return L10n.tr("开发者签名证书不一致，已被安全拦截", "Developer Team ID mismatch (blocked for security)")
        }
    }
}
