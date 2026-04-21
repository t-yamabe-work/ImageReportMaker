import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ReportCore

@MainActor
final class ReportViewModel: ObservableObject {
    @Published var authorName: String
    @Published var date: Date
    @Published var cases: [ReportCase]
    @Published var imageURLs: [URL]

    @Published var previewImage: NSImage?
    @Published var lastExportURL: URL?
    @Published var lastErrorMessage: String?

    @Published var exportFormat: ExportFormat

    // W3-F: ファイル名構成
    @Published var useDateInName: Bool
    @Published var dateFormat: DateFormatOption
    @Published var useFreeTextInName: Bool
    @Published var freeText: String

    // W3-E: 保存先
    @Published var saveDirectoryURL: URL

    // W3-H: 書き出し中フラグ
    @Published var isExporting: Bool = false

    // W3-G: プレビュー倍率
    @Published var previewZoom: Double

    private let preferences: UserPreferences
    private let appPreferences: AppPreferences
    private var previewTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    private static let previewDebounceNanos: UInt64 = 300_000_000
    nonisolated static let previewDpi: Double = 72.0
    nonisolated static let exportDpi: Double = 150.0

    init(
        preferences: UserPreferences = .shared,
        appPreferences: AppPreferences = .shared
    ) {
        self.preferences = preferences
        self.appPreferences = appPreferences

        self.authorName = preferences.authorName
        self.date = Date()
        self.cases = [ReportCase(title: "", detail: "")]
        self.imageURLs = []

        let savedFormat = preferences.lastExportFormat.flatMap { ExportFormat(rawValue: $0) } ?? .jpg
        self.exportFormat = savedFormat

        self.useDateInName = appPreferences.useDateInName
        self.dateFormat = DateFormatOption(rawValue: appPreferences.dateFormatKey) ?? .yyMMdd
        self.useFreeTextInName = appPreferences.useFreeTextInName
        self.freeText = appPreferences.freeText

        self.saveDirectoryURL = Self.resolveInitialSaveDirectory(preferences: preferences)
        self.previewZoom = appPreferences.previewZoom
    }

    // MARK: - Derived

    var currentModel: ReportModel {
        ReportModel(
            authorName: authorName,
            date: date,
            cases: cases,
            imagePaths: imageURLs
        )
    }

    var weekdayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    // MARK: - Author

    func persistAuthorName() {
        preferences.authorName = authorName
    }

    // MARK: - Cases

    func addCase() {
        cases.append(ReportCase(title: "", detail: ""))
    }

    func removeCase(at offsets: IndexSet) {
        cases.remove(atOffsets: offsets)
        if cases.isEmpty {
            cases.append(ReportCase(title: "", detail: ""))
        }
    }

    func moveCase(from source: IndexSet, to destination: Int) {
        cases.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Images

    func addImages(_ urls: [URL]) {
        let allowed: Set<String> = ["png", "jpg", "jpeg"]
        let filtered = urls.filter { allowed.contains($0.pathExtension.lowercased()) }
        imageURLs.append(contentsOf: filtered)
    }

    func removeImage(at offsets: IndexSet) {
        imageURLs.remove(atOffsets: offsets)
    }

    func removeImage(_ url: URL) {
        imageURLs.removeAll { $0 == url }
    }

    // MARK: - Preview rendering (W3-H debounced)

    func requestPreviewRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.previewDebounceNanos)
            } catch {
                return
            }
            if Task.isCancelled { return }
            await MainActor.run { self?.refreshPreviewNow() }
        }
    }

    func refreshPreviewNow() {
        previewTask?.cancel()
        let model = currentModel
        previewTask = Task { [weak self] in
            let data = await Self.renderPreviewData(for: model)
            if Task.isCancelled { return }
            let image = data.flatMap { NSImage(data: $0) }
            await MainActor.run {
                self?.previewImage = image
            }
        }
    }

    private static func renderPreviewData(for model: ReportModel) async -> Data? {
        await Task.detached(priority: .userInitiated) { () -> Data? in
            try? ReportRenderer.render(
                model: model,
                options: RenderOptions(format: .png, dpi: previewDpi)
            )
        }.value
    }

    // MARK: - Save directory (W3-E)

    func changeSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "選択"
        panel.message = "保存先フォルダを選択"
        panel.directoryURL = saveDirectoryURL
        if panel.runModal() == .OK, let url = panel.url {
            saveDirectoryURL = url
            if let bookmark = try? url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                preferences.lastSaveDirectoryBookmark = bookmark
            }
        }
    }

    // MARK: - File name (W3-F)

    var composedFileNameStem: String {
        let dateStem = useDateInName ? dateFormat.format(date) : ""
        let text = useFreeTextInName ? sanitize(freeText) : ""

        if !dateStem.isEmpty, !text.isEmpty {
            return "\(dateStem)_\(text)"
        }
        if !dateStem.isEmpty { return dateStem }
        if !text.isEmpty { return text }
        return dateFormat.format(date) // フォールバック: 日付のみ
    }

    var composedFileName: String {
        "\(composedFileNameStem).\(exportFormat.rawValue)"
    }

    func persistFileNamePreferences() {
        appPreferences.useDateInName = useDateInName
        appPreferences.dateFormatKey = dateFormat.rawValue
        appPreferences.useFreeTextInName = useFreeTextInName
        appPreferences.freeText = freeText
    }

    // MARK: - Zoom (W3-G)

    func persistZoom() {
        appPreferences.previewZoom = previewZoom
    }

    // MARK: - Export (W3-H: background + isExporting)

    func export() {
        guard !isExporting else { return }
        lastErrorMessage = nil

        let model = currentModel
        let format = exportFormat
        let url = saveDirectoryURL.appendingPathComponent(composedFileName)

        isExporting = true

        Task { [weak self] in
            let result = await Self.performExport(model: model, format: format, url: url)
            await MainActor.run {
                guard let self else { return }
                self.isExporting = false
                switch result {
                case .success(let saved):
                    self.lastExportURL = saved
                    self.preferences.lastFileName = saved.lastPathComponent
                    self.preferences.lastExportFormat = format.rawValue
                    if let bookmark = try? self.saveDirectoryURL.bookmarkData(
                        options: [],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        self.preferences.lastSaveDirectoryBookmark = bookmark
                    }
                case .failure(let error):
                    self.lastErrorMessage = "書き出し失敗: \(error.localizedDescription)"
                }
            }
        }
    }

    private static func performExport(
        model: ReportModel,
        format: ExportFormat,
        url: URL
    ) async -> Result<URL, Error> {
        await Task.detached(priority: .userInitiated) { () -> Result<URL, Error> in
            do {
                let data = try ReportRenderer.render(
                    model: model,
                    options: RenderOptions(format: format, dpi: exportDpi)
                )
                try data.write(to: url, options: .atomic)
                return .success(url)
            } catch {
                return .failure(error)
            }
        }.value
    }

    // MARK: - Helpers

    private static func resolveInitialSaveDirectory(preferences: UserPreferences) -> URL {
        if let bookmark = preferences.lastSaveDirectoryBookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale {
                return url
            }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    private func sanitize(_ text: String) -> String {
        let invalid: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.filter { !invalid.contains($0) })
    }
}
