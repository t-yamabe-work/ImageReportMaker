import SwiftUI

@main
struct ImageReportMakerApp: App {
    var body: some Scene {
        WindowGroup("画像報告書メーカー") {
            ContentView()
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowResizability(.contentSize)
    }
}
