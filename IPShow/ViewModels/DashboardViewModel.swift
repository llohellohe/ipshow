import Foundation
import SwiftData

/// 主仪表盘视图模型：编排三通道并行检测、归属地查询、历史持久化与清理。
///
/// 类本身不标记 `@MainActor`，以便能在 SwiftUI `@State` 的默认值表达式中创建实例；
/// 涉及 UI 状态更新与 SwiftData `ModelContext` 访问的方法分别标记 `@MainActor`。
@Observable
final class DashboardViewModel {

    private let detection = IPDetectionService()
    private let geo = GeoLookupService()

    /// 当前各通道最新一次的检测快照（ip == nil && errorMessage == nil 表示加载中）。
    var snapshots: [Channel: IPSnapshot] = [:]
    var isRefreshing: Bool = false
    var lastRefreshAt: Date?
    var localInterfaces: [LocalInterface] = []

    let historyLimit: Int = 500

    init() {
        for ch in Channel.allCases {
            snapshots[ch] = IPSnapshot(channel: ch)
        }
        localInterfaces = LocalInterfaceService.enumerate()
    }

    @MainActor
    func refresh(context: ModelContext, provider: GeoProvider) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // 重置为占位 snapshot 触发 loading UI
        for ch in Channel.allCases {
            snapshots[ch] = IPSnapshot(channel: ch)
        }
        localInterfaces = LocalInterfaceService.enumerate()

        var detected = await detection.detectAll()

        // 并行查询归属地（仅对成功获取 IP 的通道），使用用户选定的 provider
        await withTaskGroup(of: (Int, GeoInfo?).self) { group in
            for (idx, snap) in detected.enumerated() {
                guard let ip = snap.ip else { continue }
                let geoActor = self.geo
                group.addTask {
                    let info = await geoActor.lookup(ip: ip, via: provider)
                    return (idx, info)
                }
            }
            for await (idx, info) in group {
                guard let info else { continue }
                detected[idx].country = info.country
                detected[idx].countryCode = info.countryCode
                detected[idx].region = info.region
                detected[idx].city = info.city
                detected[idx].isp = info.isp
                detected[idx].asn = info.asn
                detected[idx].isProxy = info.isProxy
                detected[idx].isHosting = info.isHosting
            }
        }

        for s in detected {
            snapshots[s.channel] = s
        }
        lastRefreshAt = Date()

        // 写入历史
        for s in detected {
            context.insert(IPRecord(snapshot: s))
        }
        try? context.save()

        trimHistory(context: context)
    }

    private func trimHistory(context: ModelContext) {
        let descriptor = FetchDescriptor<IPRecord>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        guard let all = try? context.fetch(descriptor), all.count > historyLimit else { return }
        for r in all[historyLimit...] {
            context.delete(r)
        }
        try? context.save()
    }

    func clearHistory(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<IPRecord>()) else { return }
        for r in all { context.delete(r) }
        try? context.save()
    }

    /// 三通道出口 IP 是否存在差异（仅在两个及以上通道有结果时判定）。
    var channelsDivergent: Bool {
        let ips = Channel.allCases.compactMap { snapshots[$0]?.ip }
        guard ips.count >= 2 else { return false }
        return Set(ips).count > 1
    }
}
