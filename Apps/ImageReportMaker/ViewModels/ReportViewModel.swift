import SwiftUI
import ReportCore

@MainActor
final class ReportViewModel: ObservableObject {
    @Published var authorName: String
    @Published var date: Date
    @Published var cases: [ReportCase]
    @Published var imageURLs: [URL]

    private let preferences: UserPreferences

    init(preferences: UserPreferences = .shared) {
        self.preferences = preferences
        self.authorName = preferences.authorName
        self.date = Date()
        self.cases = [ReportCase(title: "", detail: "")]
        self.imageURLs = []
    }

    func persistAuthorName() {
        preferences.authorName = authorName
    }

    // TODO: worker3 で追加実装
    // - addCase / removeCase / moveCase
    // - addImages / removeImage / moveImage
    // - export(format:) -> URL
}
