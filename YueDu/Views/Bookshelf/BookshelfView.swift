import SwiftData
import SwiftUI

struct BookshelfView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.lastOpenedAt, order: .reverse) private var books: [Book]

    @State private var activeBook: Book?
    @State private var searchText = ""
    @State private var bookToDelete: Book?
    @State private var showDeleteConfirmation = false

    private var filteredBooks: [Book] {
        guard !searchText.isEmpty else { return books }
        return books.filter {
            $0.title.localizedStandardContains(searchText)
                || $0.author.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("书架还是空的", systemImage: "books.vertical")
                    } description: {
                        Text("到书城下载一本 EPUB，下载完成后会自动出现在这里。")
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 22) {
                            ForEach(filteredBooks) { book in
                                Button {
                                    open(book)
                                } label: {
                                    BookGridItem(book: book)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        bookToDelete = book
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationTitle("书架")
            .searchable(text: $searchText, prompt: "搜索书名或作者")
            .navigationDestination(item: $activeBook) { book in
                ReaderView(book: book)
            }
            .confirmationDialog(
                "删除《\(bookToDelete?.title ?? "")》？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let bookToDelete {
                        delete(bookToDelete)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("会同时删除本地缓存，之后可以从书城重新下载。")
            }
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 132, maximum: 180), spacing: 20)]
    }

    private func open(_ book: Book) {
        book.lastOpenedAt = .now
        activeBook = book
    }

    private func delete(_ book: Book) {
        if let fileName = book.localFileName {
            BookStorage.remove(fileName: fileName)
        }
        BookStorage.removeCache(for: book.id)
        modelContext.delete(book)
        try? modelContext.save()
    }
}

private struct BookGridItem: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            BookCoverView(coverURL: book.coverURL, title: book.title)
                .frame(height: 186)

            Text(book.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(book.author)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
