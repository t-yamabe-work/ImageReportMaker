import Foundation

/// Apps 側独自の設定（ReportCore の UserPreferences で扱わないキー）を UserDefaults で永続化する。
final class AppPreferences: @unchecked Sendable {
    static let shared = AppPreferences()

    /// 詳細文のデフォルト文言（W3-I）。複数詳細対応で単要素配列。
    static let defaultCaseDetails: [String] = ["を進行いたしました。"]

    private let defaults: UserDefaults

    private enum Key {
        static let useDateInName = "useDateInName"
        static let dateFormatKey = "dateFormatKey"
        static let useFreeTextInName = "useFreeTextInName"
        static let freeText = "freeText"
        static let previewZoom = "previewZoom"
        static let topCaseTitle = "topCaseTitle"
        static let topCaseDetail = "topCaseDetail"          // 旧: String?（マイグレ用に残す）
        static let topCaseDetails = "topCaseDetails"        // 新: [String]?（JSON）
        static let collisionPolicy = "collisionPolicy"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateTopCaseDetailIfNeeded()
    }

    private func migrateTopCaseDetailIfNeeded() {
        // 旧キーがあって新キーが未設定のときだけ移行
        guard defaults.object(forKey: Key.topCaseDetails) == nil,
              let legacy = defaults.string(forKey: Key.topCaseDetail) else {
            // 旧キーが残っているなら掃除のみ
            if defaults.object(forKey: Key.topCaseDetail) != nil,
               defaults.object(forKey: Key.topCaseDetails) != nil {
                defaults.removeObject(forKey: Key.topCaseDetail)
            }
            return
        }
        if let data = try? JSONEncoder().encode([legacy]) {
            defaults.set(data, forKey: Key.topCaseDetails)
        }
        defaults.removeObject(forKey: Key.topCaseDetail)
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

    var topCaseDetails: [String]? {
        get {
            guard let data = defaults.data(forKey: Key.topCaseDetails) else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            if let value = newValue,
               let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: Key.topCaseDetails)
            } else {
                defaults.removeObject(forKey: Key.topCaseDetails)
            }
        }
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
