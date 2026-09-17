import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    @State private var showAddCatalog = false
    @State private var catalogName = ""
    @State private var catalogURL = ""
    @State private var showAddError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(settingsStore.catalogs, id: \.self) { catalog in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(catalog.name)
                                .font(.subheadline.weight(.medium))
                            Text(catalog.url.absoluteString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                settingsStore.removeCatalog(catalog)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        showAddCatalog = true
                    } label: {
                        Label("添加 OPDS 书源", systemImage: "plus.circle")
                    }
                } header: {
                    Text("在线书源")
                } footer: {
                    Text("支持标准 OPDS 目录，例如 Project Gutenberg、Standard Ebooks，以及你自建的 OPDS 服务。")
                }

                Section("阅读默认值") {
                    NavigationLink {
                        ReaderSettingsSheet()
                    } label: {
                        Label("排版与主题", systemImage: "textformat.size")
                    }
                }

                Section {
                    LabeledContent("版本", value: appVersion)
                    LabeledContent("书籍存储", value: storageDescription)
                } header: {
                    Text("关于")
                } footer: {
                    Text("这是自用版本，数据与书籍都保存在本机。")
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showAddCatalog) {
                addCatalogSheet
            }
            .alert("书源信息不完整", isPresented: $showAddError) {
                Button("好", role: .cancel) {}
            } message: {
                Text("请填写名称和有效的 URL。")
            }
        }
    }

    private var addCatalogSheet: some View {
        NavigationStack {
            Form {
                TextField("名称", text: $catalogName)
                TextField("OPDS URL", text: $catalogURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            .navigationTitle("添加书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        resetCatalogForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if settingsStore.addCatalog(name: catalogName, urlString: catalogURL) {
                            resetCatalogForm()
                        } else {
                            showAddError = true
                        }
                    }
                }
            }
        }
    }

    private func resetCatalogForm() {
        showAddCatalog = false
        catalogName = ""
        catalogURL = ""
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var storageDescription: String {
        let path = BookStorage.rootDirectory.path
        return path.isEmpty ? "本机" : "本机"
    }
}
