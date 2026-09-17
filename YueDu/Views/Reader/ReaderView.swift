import SwiftData
import SwiftUI

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var viewModel: ReaderViewModel
    @State private var showControls = true
    @State private var showSettings = false
    @State private var showContents = false

    init(book: Book) {
        self.book = book
        _viewModel = State(initialValue: ReaderViewModel(book: book))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            settingsStore.readerSettings.theme.backgroundColor
                .ignoresSafeArea()

            content

            if showControls {
                ReaderToolbar(
                    viewModel: viewModel,
                    showSettings: $showSettings,
                    showContents: $showContents
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(showControls ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    saveProgress()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }

            ToolbarItem(placement: .principal) {
                Text(viewModel.currentChapter?.title ?? book.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
        }
        .statusBarHidden(!showControls)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showContents) {
            ChapterListView(viewModel: viewModel)
        }
        .task {
            await viewModel.load()
        }
        .onDisappear {
            saveProgress()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("正在打开…")
                .tint(settingsStore.readerSettings.theme.textColor)

        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text(message)
                    .multilineTextAlignment(.center)
                Button("重试") {
                    Task { await viewModel.load(force: true) }
                }
                .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(settingsStore.readerSettings.theme.textColor)
            .padding(32)

        case .ready:
            TabView(selection: $viewModel.currentChapterIndex) {
                ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { index, chapter in
                    ChapterPageView(
                        chapter: chapter,
                        chapterIndex: index,
                        viewModel: viewModel,
                        showControls: $showControls
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: viewModel.currentChapterIndex) {
                viewModel.chapterDidChange()
            }
        }
    }

    private func saveProgress() {
        viewModel.persistProgress(in: modelContext)
    }
}

private struct ReaderToolbar: View {
    @Bindable var viewModel: ReaderViewModel
    @Binding var showSettings: Bool
    @Binding var showContents: Bool
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        VStack(spacing: 0) {
            progressRow

            Divider()

            HStack {
                Button {
                    showContents = true
                } label: {
                    Label("目录", systemImage: "list.bullet")
                }

                Spacer()

                Button {
                    viewModel.goToPreviousChapter()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(viewModel.currentChapterIndex <= 0)

                Spacer()

                Button {
                    viewModel.goToNextChapter()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(viewModel.currentChapterIndex >= viewModel.chapters.count - 1)

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Label("排版", systemImage: "textformat.size")
                }
            }
            .font(.subheadline)
            .labelStyle(.iconOnly)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial)
    }

    private var progressRow: some View {
        VStack(spacing: 7) {
            Slider(
                value: Binding(
                    get: { Double(viewModel.currentChapterIndex) },
                    set: { viewModel.jumpToChapter(Int($0.rounded())) }
                ),
                in: 0...Double(max(viewModel.chapters.count - 1, 1)),
                step: 1
            )
            .tint(settingsStore.readerSettings.theme.textColor)

            HStack {
                Text("第 \(viewModel.currentChapterIndex + 1) 章")
                Spacer()
                Text("共 \(viewModel.chapters.count) 章")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }
}

private struct ChapterPageView: View {
    @Environment(SettingsStore.self) private var settingsStore

    let chapter: EPUBChapter
    let chapterIndex: Int
    let viewModel: ReaderViewModel
    @Binding var showControls: Bool

    @State private var containerHeight: Double = 0
    @State private var contentHeight: Double = 0
    @State private var lastReportedOffset: Double = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    ScrollPositionReporter(coordinateSpaceName: scrollSpaceName)
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                            handleOffset(offset)
                        }

                    VStack(alignment: .leading, spacing: settingsStore.readerSettings.paragraphSpacing) {
                        Text(chapter.title)
                            .font(settingsStore.readerSettings.fontFamily.font(
                                size: settingsStore.readerSettings.fontSize(for: proxy.size.width) * 1.35
                            ).weight(.semibold))
                            .foregroundStyle(settingsStore.readerSettings.theme.textColor)
                            .padding(.bottom, 6)
                            .id(paragraphID(0))

                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph)
                                .font(settingsStore.readerSettings.fontFamily.font(
                                    size: settingsStore.readerSettings.fontSize(for: proxy.size.width)
                                ))
                                .lineSpacing(settingsStore.readerSettings.lineSpacing)
                                .foregroundStyle(settingsStore.readerSettings.theme.textColor)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(paragraphID(index + 1))
                        }
                    }
                    .padding(.horizontal, settingsStore.readerSettings.horizontalPadding)
                    .padding(.top, 24)
                    .padding(.bottom, 140)
                    .background(
                        GeometryReader { contentProxy in
                            Color.clear
                                .onAppear {
                                    contentHeight = contentProxy.size.height
                                }
                                .onChange(of: contentProxy.size.height) { _, newValue in
                                    contentHeight = newValue
                                }
                        }
                    )
                }
                .coordinateSpace(name: scrollSpaceName)
                .scrollIndicators(.hidden)
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.2)) {
                        showControls.toggle()
                    }
                }
                .onAppear {
                    containerHeight = proxy.size.height
                    let targetIndex = viewModel.paragraphIndex(for: chapterIndex, paragraphCount: paragraphs.count)
                    guard targetIndex > 0 else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        scrollProxy.scrollTo(paragraphID(targetIndex), anchor: .top)
                    }
                }
                .onChange(of: proxy.size.height) { _, newValue in
                    containerHeight = newValue
                }
            }
        }
    }

    private var scrollSpaceName: String {
        "chapter-scroll-\(chapterIndex)"
    }

    private func handleOffset(_ offset: Double) {
        guard contentHeight > 0, containerHeight > 0 else { return }
        let scrollable = max(contentHeight - containerHeight, 1)
        let normalized = max(0, min(1, offset / scrollable))

        guard abs(normalized - lastReportedOffset) > 0.002 else { return }
        lastReportedOffset = normalized
        viewModel.updateScrollPosition(chapterIndex: chapterIndex, offset: normalized)
    }

    private func paragraphID(_ index: Int) -> String {
        "chapter-\(chapterIndex)-paragraph-\(index)"
    }

    private var paragraphs: [String] {
        chapter.plainText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
