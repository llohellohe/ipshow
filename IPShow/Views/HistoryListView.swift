import SwiftUI
import AppKit

struct HistoryListView: View {
    let records: [IPRecord]

    var body: some View {
        if records.isEmpty {
            Text("暂无历史记录")
                .foregroundStyle(.secondary)
                .font(.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(records) { r in
                    HistoryRow(record: r)
                    Divider().opacity(0.5)
                }
            }
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct HistoryRow: View {
    let record: IPRecord

    var body: some View {
        HStack(spacing: 10) {
            Text(formatTime(record.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(record.channel.displayName)
                .font(.caption)
                .frame(width: 70, alignment: .leading)

            if let ip = record.ip {
                Text(ip)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                Label("失败", systemImage: "xmark.octagon")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Spacer()

            if let code = record.countryCode, !code.isEmpty {
                Text(flag(for: code))
            }
            if let country = record.country, !country.isEmpty {
                Text(country)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contextMenu {
            if let ip = record.ip {
                Button("复制 IP") {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(ip, forType: .string)
                }
            }
        }
    }

    private func formatTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f.string(from: d)
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
