import SwiftUI
import AppKit

struct ChannelCardView: View {
    let snapshot: IPSnapshot
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: snapshot.channel.iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                header
                Divider().opacity(0.4)
                content
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            if let ip = snapshot.ip {
                Button("复制 IP") { copyToPasteboard(ip) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(snapshot.channel.displayName)
                .font(.subheadline.bold())
            Text(snapshot.channel.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if snapshot.latencyMs > 0 {
                Text("\(snapshot.latencyMs) ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("检测中…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else if let err = snapshot.errorMessage {
            Label(err, systemImage: "xmark.octagon.fill")
                .font(.callout)
                .foregroundStyle(.red)
        } else if let ip = snapshot.ip {
            HStack(spacing: 10) {
                Text(ip)
                    .font(.system(.title3, design: .monospaced))
                    .textSelection(.enabled)
                if let code = snapshot.countryCode, !code.isEmpty {
                    Text(flag(for: code)).font(.title3)
                }
                Text(snapshot.locationLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(spacing: 6) {
                if hasAnyGeo {
                    if let isp = snapshot.isp, !isp.isEmpty {
                        Text(isp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let asn = snapshot.asn, !asn.isEmpty {
                        Text(asn)
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    Spacer()
                    if snapshot.isProxy { TagBadge(text: "Proxy", color: .orange) }
                    if snapshot.isHosting { TagBadge(text: "Hosting", color: .blue) }
                } else {
                    Label("当前归属地源查询失败，可切换其它源", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange.opacity(0.9))
                    Spacer()
                }
            }
        } else {
            Text("尚未检测")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func copyToPasteboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    /// 是否拿到了任何归属地字段。用于在 IP 拿到但 geo 查询失败时提示用户切换源。
    private var hasAnyGeo: Bool {
        let hasCountry = (snapshot.country?.isEmpty == false) || (snapshot.countryCode?.isEmpty == false)
        let hasISP = snapshot.isp?.isEmpty == false
        let hasASN = snapshot.asn?.isEmpty == false
        return hasCountry || hasISP || hasASN
    }

    private func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in countryCode.unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.unicodeScalars.append(scalar)
            }
        }
        return s
    }
}

struct TagBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
