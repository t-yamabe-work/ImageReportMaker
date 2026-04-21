import Foundation

/// Apps 側独自の設定（ReportCore の UserPreferences で扱わないキー）を UserDefaults で永続化する。
final class AppPreferences: @unchecked Sendable {
    static let shared = AppPreferences()

    private let defaults: UserDefaults

    private enum Key {
        static let useDateInName = "useDateInName"
        static let dateFormatKey = "dateFormatKey"
        static let useFreeTextInName = "useFreeTextInName"
        static let freeText = "freeText"
        static let previewZoom = "previewZoom"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var useDateInName: Bool {
        get {
            if defaults.object(forKey: Key.useDateInName) == nil { return true }
            return defaults.bool(forKey: Key.useDateInName)
        }
        set { defaults.set(newValue, forKey: Key.useDateInName) }
    }

    var dateFormatKey: String {
        get { defaults.string(forKey: Key.dateFormatKey) ?? DateFormatOption.yyMMdd.rawValue }
        set { defaults.set(newValue, forKey: Key.dateFormatKey) }
    }

    var useFreeTextInName: Bool {
        get { defaults.bool(forKey: Key.useFreeTextInName) }
        set { defaults.set(newValue, forKey: Key.useFreeTextInName) }
    }

    var freeText: String {
        get { defaults.string(forKey: Key.freeText) ?? "" }
        set { defaults.set(newValue, forKey: Key.freeText) }
    }

    var previewZoom: Double {
        get {
            let v = defaults.double(forKey: Key.previewZoom)
            return v == 0 ? 1.0 : v
        }
        set { defaults.set(newValue, forKey: Key.previewZoom) }
    }
}

enum DateFormatOption: String, CaseIterable, Identifiable, Sendable {
    case yyMMdd = "yyMMdd"
    case isoDash = "yyyy-MM-dd"
    case yyyyMMdd = "yyyyMMdd"
    case MMdd = "MMdd"
    case japanese = "yyyy年MM月dd日"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yyMMdd: return "YYMMDD"
        case .isoDash: return "YYYY-MM-DD"
        case .yyyyMMdd: return "YYYYMMDD"
        case .MMdd: return "MMDD"
        case .japanese: return "YYYY年MM月DD日"
        }
    }

    func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = rawValue
        return f.string(from: date)
    }
}
