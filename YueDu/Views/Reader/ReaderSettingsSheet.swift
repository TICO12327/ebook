import SwiftUI

struct ReaderSettingsSheet: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("主题") {
                    Picker("主题", selection: themeBinding) {
                        ForEach(ReaderTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("字体") {
                    Picker("字体", selection: fontFamilyBinding) {
                        ForEach(ReaderFontFamily.allCases) { family in
                            Text(family.displayName).tag(family)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("字号")
                            Spacer()
                            Text("\(Int(settingsStore.readerSettings.fontScale * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: fontScaleBinding,
                            in: ReaderSettings.minimumFontScale...ReaderSettings.maximumFontScale
                        )
                    }
                }

                Section("间距") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("行距")
                        Slider(value: lineSpacingBinding, in: 2...20)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("段距")
                        Slider(value: paragraphSpacingBinding, in: 4...28)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("边距")
                        Slider(value: horizontalPaddingBinding, in: 12...40)
                    }
                }

                Section {
                    Button("恢复默认排版", role: .destructive) {
                        settingsStore.resetReaderSettings()
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var themeBinding: Binding<ReaderTheme> {
        Binding(
            get: { settingsStore.readerSettings.theme },
            set: { settingsStore.readerSettings.theme = $0 }
        )
    }

    private var fontFamilyBinding: Binding<ReaderFontFamily> {
        Binding(
            get: { settingsStore.readerSettings.fontFamily },
            set: { settingsStore.readerSettings.fontFamily = $0 }
        )
    }

    private var fontScaleBinding: Binding<Double> {
        Binding(
            get: { settingsStore.readerSettings.fontScale },
            set: { settingsStore.readerSettings.fontScale = $0 }
        )
    }

    private var lineSpacingBinding: Binding<Double> {
        Binding(
            get: { settingsStore.readerSettings.lineSpacing },
            set: { settingsStore.readerSettings.lineSpacing = $0 }
        )
    }

    private var paragraphSpacingBinding: Binding<Double> {
        Binding(
            get: { settingsStore.readerSettings.paragraphSpacing },
            set: { settingsStore.readerSettings.paragraphSpacing = $0 }
        )
    }

    private var horizontalPaddingBinding: Binding<Double> {
        Binding(
            get: { settingsStore.readerSettings.horizontalPadding },
            set: { settingsStore.readerSettings.horizontalPadding = $0 }
        )
    }
}
