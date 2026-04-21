import Foundation

public final class UserPreferences: @unchecked Sendable {
    public static let shared = UserPreferences()

    private let defaults: UserDefaults

    private enum Key {
        static let authorName = "authorName"
        static let lastSaveDirectoryBookmark = "lastSaveDirectoryBookmark"
        static let lastFileName = "lastFileName"
        static let lastExportFormat = "lastExportFormat"
        static let caseHistory = "caseHistory"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var authorName: String {
        get { defaults.string(forKey: Key.authorName) ?? "山田 太郎" }
        set { defaults.set(newValue, forKey: Key.authorName) }
    }

    public var lastSaveDirectoryBookmark: Data? {
        get { defaults.data(forKey: Key.lastSaveDirectoryBookmark) }
        set { defaults.set(newValue, forKey: Key.lastSaveDirectoryBookmark) }
    }

    public var lastFileName: String? {
        get { defaults.string(forKey: Key.lastFileName) }
        set { defaults.set(newValue, forKey: Key.lastFileName) }
    }

    public var lastExportFormat: String? {
        get { defaults.string(forKey: Key.lastExportFormat) }
        set { defaults.set(newValue, forKey: Key.lastExportFormat) }
    }
}
