import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var context
    @State private var viewModel = DashboardViewModel()
    @Query(sort: \IPRecord.timestamp, order: .reverse) private var history: [IPRecord]

    @State private var isLocalExpanded: Bool = false
    @State private var autoRefresh: Bool = false
    @State private var autoRefreshTask: Task<Void, Never>?

    /// 持久化用户选择的归属地源
    @AppStorage("geoProvider") private var providerRaw: String = GeoProvider.ipApi.rawValue
    private var currentProvider: GeoProvider {
        GeoProvider(rawValue: providerRaw) ?? .ipApi
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    currentSection
                    localSection
                    historySection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 540, minHeight: 640)
        .task {
            await viewModel.refresh(context: context, provider: currentProvider)
        }
        .onChange(of: providerRaw) { _, _ in
            Task { @MainActor in
                await viewModel.refresh(context: context, provider: currentProvider)
            }
        }
        .onChange(of: autoRefresh) { _, newValue in
            autoRefreshTask?.cancel()
            if newValue {
                autoRefreshTask = Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                        if Task.isCancelled { break }
                        await viewModel.refresh(context: context, provider: currentProvider)
                    }
                }
            }
        }
        .onDisappear {
            autoRefreshTask?.cancel()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundStyle(.tint)
                .font(.title2)
            Text("IPShow")
                .font(.title2.bold())
            Spacer()
            providerMenu
            Toggle("每分钟自动刷新", isOn: $autoRefresh)
                .toggleStyle(.switch)
                .controlSize(.small)
            Button {
                Task { await viewModel.refresh(context: context, provider: currentProvider) }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(viewModel.isRefreshing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var providerMenu: some View {
        Menu {
            Picker("归属地源", selection: $providerRaw) {
                ForEach(GeoProvider.allCases) { p in
                    VStack(alignment: .leading) {
                        Text(p.displayName)
                        Text(p.subtitle).font(.caption2)
                    }
                    .tag(p.rawValue)
                }
            }
        } label: {
            Label(currentProvider.displayName, systemImage: "globe.badge.chevron.backward")
                .labelStyle(.titleAndIcon)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .fixedSize()
        .help("切换归属地查询源：\(currentProvider.subtitle)")
    }

    // MARK: - Current

    private var currentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("当前出口")
                    .font(.headline)
                Spacer()
                if let t = viewModel.lastRefreshAt {
                    Text("上次刷新 \(t.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if viewModel.channelsDivergent {
                Label("不同通道的出口 IP 存在差异，代理可能未对所有流量生效",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            ForEach(Channel.allCases) { ch in
                let snap = viewModel.snapshots[ch] ?? IPSnapshot(channel: ch)
                ChannelCardView(
                    snapshot: snap,
                    isLoading: viewModel.isRefreshing && snap.ip == nil && snap.errorMessage == nil
                )
            }
        }
    }

    // MARK: - Local

    private var localSection: some View {
        DisclosureGroup(isExpanded: $isLocalExpanded) {
            LocalInterfacesView(interfaces: viewModel.localInterfaces)
                .padding(.top, 6)
        } label: {
            HStack {
                Image(systemName: "personalhotspot")
                    .foregroundStyle(.secondary)
                Text("本地网卡")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.localInterfaces.count) 个接口")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("历史记录")
                    .font(.headline)
                Spacer()
                Text("\(history.count) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    viewModel.clearHistory(context: context)
                } label: {
                    Label("清空", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(history.isEmpty)
                .help("清空全部历史记录")
            }
            HistoryListView(records: history)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: IPRecord.self, inMemory: true)
}
