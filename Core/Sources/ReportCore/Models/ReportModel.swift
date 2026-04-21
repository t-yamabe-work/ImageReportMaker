import Foundation

public struct ReportModel: Equatable, Sendable {
    public var authorName: String
    public var date: Date
    public var cases: [ReportCase]
    public var imagePaths: [URL]

    public init(
        authorName: String,
        date: Date,
        cases: [ReportCase],
        imagePaths: [URL]
    ) {
        self.authorName = authorName
        self.date = date
        self.cases = cases
        self.imagePaths = imagePaths
    }
}
