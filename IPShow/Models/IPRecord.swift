import Foundation
import SwiftData

/// SwiftData 持久化的历史记录模型。每次刷新会为每个通道写入一条。
@Model
final class IPRecord {
    var id: UUID
    var timestamp: Date
    /// 存 Channel 的 rawValue；SwiftData 直接持久化 enum 兼容性较弱，落 String 更稳。
    var channelRaw: String
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

    init(snapshot: IPSnapshot) {
        self.id = snapshot.id
        self.timestamp = snapshot.timestamp
        self.channelRaw = snapshot.channel.rawValue
        self.ip = snapshot.ip
        self.countryCode = snapshot.countryCode
        self.country = snapshot.country
        self.region = snapshot.region
        self.city = snapshot.city
        self.isp = snapshot.isp
        self.asn = snapshot.asn
        self.isProxy = snapshot.isProxy
        self.isHosting = snapshot.isHosting
        self.errorMessage = snapshot.errorMessage
        self.latencyMs = snapshot.latencyMs
    }

    var channel: Channel { Channel(rawValue: channelRaw) ?? .app }
}
