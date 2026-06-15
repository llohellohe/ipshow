import Foundation

/// 三类网络出口通道，用于区分流量实际走过的链路。
enum Channel: String, Codable, CaseIterable, Identifiable {
    case app
    case shell
    case direct

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app: return "App 通道"
        case .shell: return "Shell 通道"
        case .direct: return "直连通道"
        }
    }

    var subtitle: String {
        switch self {
        case .app: return "URLSession.shared · 遵循系统代理"
        case .shell: return "/bin/zsh -l curl · 继承终端环境变量"
        case .direct: return "URLSession · 忽略系统代理"
        }
    }

    var iconName: String {
        switch self {
        case .app: return "app.dashed"
        case .shell: return "terminal"
        case .direct: return "network"
        }
    }
}
