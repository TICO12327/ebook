import SwiftUI

struct ChapterListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore

    let viewModel: ReaderViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        viewModel.jumpToChapter(index)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chapter.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text("第 \(index + 1) 章")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if index == viewModel.currentChapterIndex {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .tint(settingsStore.readerSettings.theme.textColor)
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
