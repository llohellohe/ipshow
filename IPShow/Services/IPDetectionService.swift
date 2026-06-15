import Foundation

enum IPDetectionError: LocalizedError {
    case invalidResponse
    case emptyBody
    case shellFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "服务端返回非预期响应"
        case .emptyBody: return "响应内容为空"
        case .shellFailed(let code, let msg):
            return "shell 退出码 \(code)\(msg.isEmpty ? "" : "：\(msg)")"
        }
    }
}

/// 按通道分别探测对外公网 IP。
/// - App 通道：URLSession.shared 配置，默认遵循系统 Network Proxies。
/// - Shell 通道：通过 /bin/zsh -l -c 调用 curl，加载 login shell 环境变量（包含 http_proxy 等）。
/// - 直连通道：URLSession 配置 connectionProxyDictionary=[:]，强制忽略系统代理。
actor IPDetectionService {

    private let primaryURL = URL(string: "https://api.ipify.org?format=json")!
    private let fallbackURL = URL(string: "https://ifconfig.co/ip")!

    private let appSession: URLSession
    private let directSession: URLSession

    init() {
        let appConfig = URLSessionConfiguration.default
        appConfig.timeoutIntervalForRequest = 8
        appConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        self.appSession = URLSession(configuration: appConfig)

        let directConfig = URLSessionConfiguration.ephemeral
        directConfig.timeoutIntervalForRequest = 8
        directConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        directConfig.connectionProxyDictionary = [:] // 关键：忽略系统代理
        self.directSession = URLSession(configuration: directConfig)
    }

    /// 并行检测三个通道。
    func detectAll() async -> [IPSnapshot] {
        async let app = detect(channel: .app)
        async let shell = detect(channel: .shell)
        async let direct = detect(channel: .direct)
        return await [app, shell, direct]
    }

    func detect(channel: Channel) async -> IPSnapshot {
        var snapshot = IPSnapshot(channel: channel)
        let start = Date()
        do {
            switch channel {
            case .app:
                snapshot.ip = try await fetchIP(via: appSession)
            case .direct:
                snapshot.ip = try await fetchIP(via: directSession)
            case .shell:
                snapshot.ip = try await fetchIPViaShell()
            }
        } catch {
            snapshot.errorMessage = error.localizedDescription
        }
        snapshot.latencyMs = Int(Date().timeIntervalSince(start) * 1000)
        return snapshot
    }

    // MARK: - URLSession 通用查询

    private func fetchIP(via session: URLSession) async throws -> String {
        // 先尝试 ipify (json)
        if let ip = try? await fetchJSONIP(from: primaryURL, via: session) {
            return ip
        }
        // 回退到纯文本接口
        let (data, response) = try await session.data(from: fallbackURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw IPDetectionError.invalidResponse
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { throw IPDetectionError.emptyBody }
        return raw
    }

    private func fetchJSONIP(from url: URL, via session: URLSession) async throws -> String {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw IPDetectionError.invalidResponse
        }
        if let decoded = try? JSONDecoder().decode([String: String].self, from: data),
           let ip = decoded["ip"], !ip.isEmpty {
            return ip
        }
        throw IPDetectionError.emptyBody
    }

    // MARK: - Shell (curl)

    private func fetchIPViaShell() async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // -l 让 zsh 作为 login shell 启动，加载 ~/.zprofile / ~/.zshrc 中可能定义的 proxy 环境变量
            proc.arguments = [
                "-l", "-c",
                "curl -fsS --max-time 8 https://api.ipify.org || curl -fsS --max-time 8 https://ifconfig.co/ip"
            ]

            let stdout = Pipe()
            let stderr = Pipe()
            proc.standardOutput = stdout
            proc.standardError = stderr

            proc.terminationHandler = { p in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let err = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard p.terminationStatus == 0 else {
                    continuation.resume(throwing: IPDetectionError.shellFailed(p.terminationStatus, err.isEmpty ? out : err))
                    return
                }
                // 兼容 ipify 的 JSON 输出
                if out.hasPrefix("{"),
                   let data = out.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode([String: String].self, from: data),
                   let ip = decoded["ip"], !ip.isEmpty {
                    continuation.resume(returning: ip)
                    return
                }
                if !out.isEmpty {
                    continuation.resume(returning: out)
                } else {
                    continuation.resume(throwing: IPDetectionError.emptyBody)
                }
            }

            do {
                try proc.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
