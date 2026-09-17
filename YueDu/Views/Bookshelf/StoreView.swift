import SwiftData
import SwiftUI

struct StoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settingsStore

    @State private var selectedCatalog: OPDSCatalog
    @State private var feed: OPDSFeed?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var importState: [String: ImportState] = [:]
    @State private var importedEntryIDs: Set<String> = []

    init() {
        _selectedCatalog = State(initialValue: OPDSCatalog.defaults[0])
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && feed == nil {
                    ProgressView("正在连接书源…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, feed == nil {
                    ContentUnavailableView {
                        Label("无法加载书源", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("重试") {
                            Task { await loadFeed() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    storeList
                }
            }
            .navigationTitle("在线书城")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    catalogMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadFeed() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .searchable(text: $searchText, prompt: "在书源中搜索")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .onChange(of: selectedCatalog) {
                searchText = ""
                Task { await loadFeed() }
            }
            .task {
                if feed == nil {
                    await loadFeed()
                }
            }
        }
    }

    private var catalogMenu: some View {
        Menu {
            ForEach(settingsStore.catalogs, id: \.self) { catalog in
                Button {
                    selectedCatalog = catalog
                } label: {
                    if catalog == selectedCatalog {
                        Label(catalog.name, systemImage: "checkmark")
                    } else {
                        Text(catalog.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedCatalog.name)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline.weight(.medium))
        }
    }

    private var storeList: some View {
        List {
            if let feed, !feed.entries.isEmpty {
                Section {
                    ForEach(feed.entries) { entry in
                        StoreBookRow(
                            entry: entry,
                            state: importState[entry.id] ?? (importedEntryIDs.contains(entry.id) ? .imported : .idle),
                            onImport: {
                                Task { await importBook(entry) }
                            }
                        )
                    }
                } header: {
                    Text(feed.title)
                }
            } else {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await loadFeed()
        }
    }

    private func loadFeed() async {
        isLoading = true
        errorMessage = nil

        do {
            let loaded = try await OPDSService().loadFeed(from: selectedCatalog.url)
            feed = loaded
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            await loadFeed()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            feed = try await OPDSService().search(query: query, in: selectedCatalog)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func importBook(_ entry: OPDSEntry) async {
        guard let acquisitionURL = entry.acquisitionURL else { return }
        importState[entry.id] = .downloading(progress: nil)

        do {
            let downloadedURL = try await DownloadService.shared.download(
                from: acquisitionURL,
                suggestedTitle: entry.title
            )

            importState[entry.id] = .parsing
            let bookID = UUID()
            let parsed = try EPUBParser().parse(fileURL: downloadedURL, cacheID: bookID)

            let fileName = downloadedURL.lastPathComponent

            var localCoverURL: URL?
            if let coverData = parsed.coverData {
                localCoverURL = BookStorage.saveCover(data: coverData, bookID: bookID)
            }

            let book = Book(
                id: bookID,
                title: parsed.title,
                author: parsed.author,
                summary: entry.summary,
                coverURL: localCoverURL ?? entry.coverURL,
                sourceURL: acquisitionURL,
                localFileName: fileName
            )

            modelContext.insert(book)
            try? modelContext.save()

            importState[entry.id] = .imported
            importedEntryIDs.insert(entry.id)
        } catch {
            BookStorage.remove(fileName: acquisitionURL.lastPathComponent)
            importState[entry.id] = .failed(error.localizedDescription)
        }
    }
}

enum ImportState: Equatable {
    case idle
    case downloading(progress: Double?)
    case parsing
    case imported
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .downloading, .parsing:
            true
        default:
            false
        }
    }
}

private struct StoreBookRow: View {
    let entry: OPDSEntry
    let state: ImportState
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            BookCoverView(coverURL: entry.coverURL, title: entry.title)
                .frame(width: 68, height: 96)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(entry.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !entry.summary.isEmpty {
                    Text(HTMLTextExtractor.plainText(from: entry.summary))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 8)

            actionButton
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .idle:
            Button(action: onImport) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .disabled(entry.acquisitionURL == nil)
        case .downloading:
            ProgressView()
        case .parsing:
            ProgressView()
        case .imported:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        case .failed:
            Button(action: onImport) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
        }
    }
}
