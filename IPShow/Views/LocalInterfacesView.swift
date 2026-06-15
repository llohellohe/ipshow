import SwiftUI

struct LocalInterfacesView: View {
    let interfaces: [LocalInterface]

    var body: some View {
        if interfaces.isEmpty {
            Text("未发现可用网卡")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(interfaces) { ifa in
                    HStack(spacing: 8) {
                        Text(ifa.name)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(ifa.family.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text(ifa.address)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                    }
                }
            }
        }
    }
}
