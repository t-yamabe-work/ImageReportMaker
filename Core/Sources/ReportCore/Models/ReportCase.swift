import Foundation

public struct ReportCase: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var details: [String]

    public init(id: UUID = UUID(), title: String, details: [String]) {
        self.id = id
        self.title = title
        self.details = details
    }
}
