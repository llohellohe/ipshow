import Foundation

/// 单次刷新中、某个通道的检测结果（瞬态对象，仅用于 UI 状态）。
struct IPSnapshot: Identifiable, Equatable {
    let id: UUID
    let channel: Channel
    let timestamp: Date
    var ip: String?
    var countryCode: String?
    var country: String?
    var region: String?
    var city: String?
    var isp: String?
    var asn: String?
    var isProxy: Bool
    var isHosting: Bool
    var errorMessage: String?
    var latencyMs: Int

    init(channel: Channel) {
        self.id = UUID()
        self.channel = channel
        self.timestamp = Date()
        self.isProxy = false
        self.isHosting = false
        self.latencyMs = 0
    }

    var isSuccess: Bool { ip != nil && errorMessage == nil }

    /// 拼接 country / region / city 形成一行可读位置串。
    var locationLine: String {
        var parts: [String] = []
        if let country, !country.isEmpty { parts.append(country) }
        if let region, !region.isEmpty, region != city { parts.append(region) }
        if let city, !city.isEmpty { parts.append(city) }
        return parts.joined(separator: " · ")
    }
}
