import Foundation

/// 归属地查询服务提供商。
/// 当用户在 UI 上选择某个 provider 后，所有通道的归属地查询都改用该 provider，
/// 不做自动 fallback —— 失败时由用户手动切换其它源。
enum GeoProvider: String, Codable, CaseIterable, Identifiable {
    case ipApi       // ip-api.com (HTTP)
    case ipApiIs     // ipapi.is (HTTPS)
    case ipWhoIs     // ipwho.is (HTTPS)
    case ipSb        // ip.sb  (HTTPS)
    case ipInfo      // ipinfo.io (HTTPS, no token)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ipApi:   return "ip-api.com"
        case .ipApiIs: return "ipapi.is"
        case .ipWhoIs: return "ipwho.is"
        case .ipSb:    return "ip.sb"
        case .ipInfo:  return "ipinfo.io"
        }
    }

    /// 菜单中的次要说明（一行）
    var subtitle: String {
        switch self {
        case .ipApi:   return "HTTP · 45 次/分钟 · 全字段 (含 proxy/hosting)"
        case .ipApiIs: return "HTTPS · 1000 次/天 · 全字段 (含 vpn/tor/datacenter)"
        case .ipWhoIs: return "HTTPS · 10000 次/月"
        case .ipSb:    return "HTTPS · 几乎无限 · 节点速度好"
        case .ipInfo:  return "HTTPS · 每天数十次（未授权）"
        }
    }

    var iconName: String { "globe.badge.chevron.backward" }
}
