import Foundation

public struct ReportCase: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var detail: String

    public init(id: UUID = UUID(), title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}
