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
    @Published var fileName: String

    private let preferences: UserPreferences
    private var previewTask: Task<Void, Never>?

    init(preferences: UserPreferences = .shared) {
        self.preferences = preferences
        self.authorName = preferences.authorName
        self.date = Date()
        self.cases = [ReportCase(title: "", detail: "")]
        self.imageURLs = []

        let savedFormat = preferences.lastExportFormat.flatMap { ExportFormat(rawValue: $0) } ?? .jpg
        self.exportFormat = savedFormat
        self.fileName = preferences.lastFileName ?? Self.defaultFileName(for: Date(), format: savedFormat)
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

    // MARK: - Preview rendering

    func refreshPreview() {
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
                options: RenderOptions(format: .png)
            )
        }.value
    }

    // MARK: - Export

    func updateFileNameDefaultIfNeeded() {
        let auto = Self.defaultFileName(for: date, format: exportFormat)
        if fileName.isEmpty {
            fileName = auto
        } else if let stem = Self.baseName(fileName),
                  Self.looksLikeDateStem(stem) {
            fileName = auto
        } else {
            fileName = Self.replaceExtension(fileName, with: exportFormat.rawValue)
        }
    }

    func export() {
        lastErrorMessage = nil
        let saveDir = resolveSaveDirectory()
        let name = fileName.isEmpty ? Self.defaultFileName(for: date, format: exportFormat) : fileName
        let url = saveDir.appendingPathComponent(Self.replaceExtension(name, with: exportFormat.rawValue))

        do {
            let data = try ReportRenderer.render(
                model: currentModel,
                options: RenderOptions(format: exportFormat)
            )
            try data.write(to: url, options: .atomic)
            lastExportURL = url

            preferences.lastFileName = url.lastPathComponent
            preferences.lastExportFormat = exportFormat.rawValue
            if let bookmark = try? saveDir.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                preferences.lastSaveDirectoryBookmark = bookmark
            }
        } catch {
            lastErrorMessage = "書き出し失敗: \(error.localizedDescription)"
        }
    }

    private func resolveSaveDirectory() -> URL {
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

    // MARK: - File name helpers

    static func defaultFileName(for date: Date, format: ExportFormat) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyMMdd"
        return "\(f.string(from: date)).\(format.rawValue)"
    }

    private static func baseName(_ name: String) -> String? {
        guard let dot = name.lastIndex(of: ".") else { return name }
        return String(name[..<dot])
    }

    private static func looksLikeDateStem(_ stem: String) -> Bool {
        guard stem.count == 6 else { return false }
        return stem.allSatisfy { $0.isNumber }
    }

    private static func replaceExtension(_ name: String, with ext: String) -> String {
        guard let dot = name.lastIndex(of: ".") else { return "\(name).\(ext)" }
        return String(name[..<dot]) + "." + ext
    }
}
