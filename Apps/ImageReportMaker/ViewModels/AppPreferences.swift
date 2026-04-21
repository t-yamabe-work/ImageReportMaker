import Foundation

/// Apps 側独自の設定（ReportCore の UserPreferences で扱わないキー）を UserDefaults で永続化する。
final class AppPreferences: @unchecked Sendable {
    static let shared = AppPreferences()

    /// 詳細文のデフォルト文言（W3-I）
    static let defaultCaseDetail: String = "を進行いたしました。"

    private let defaults: UserDefaults

    private enum Key {
        static let useDateInName = "useDateInName"
        static let dateFormatKey = "dateFormatKey"
        static let useFreeTextInName = "useFreeTextInName"
        static let freeText = "freeText"
        static let previewZoom = "previewZoom"
        static let topCaseTitle = "topCaseTitle"
        static let topCaseDetail = "topCaseDetail"
        static let collisionPolicy = "collisionPolicy"
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

    // W3-J: 一番上の案件を記憶
    var topCaseTitle: String? {
        get { defaults.string(forKey: Key.topCaseTitle) }
        set { defaults.set(newValue, forKey: Key.topCaseTitle) }
    }

    var topCaseDetail: String? {
        get { defaults.string(forKey: Key.topCaseDetail) }
        set { defaults.set(newValue, forKey: Key.topCaseDetail) }
    }

    // W3-K: 同名ファイル衝突時の挙動
    var collisionPolicy: FileCollisionPolicy {
        get {
            FileCollisionPolicy(rawValue: defaults.string(forKey: Key.collisionPolicy) ?? "") ?? .warn
        }
        set { defaults.set(newValue.rawValue, forKey: Key.collisionPolicy) }
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

enum FileCollisionPolicy: String, CaseIterable, Identifiable, Sendable {
    case overwrite
    case warn
    case sequential

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overwrite: return "上書き"
        case .warn: return "警告"
        case .sequential: return "連番"
        }
    }
}
