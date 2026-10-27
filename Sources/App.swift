import SwiftUI
import AppKit

@main
struct CanIOpenApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    appState.loadData()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Can I Open") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: Self.aboutCredits
                    ])
                }
            }
        }
    }

    private static var aboutCredits: NSAttributedString {
        let credits = NSMutableAttributedString(string: "Based on Can I Open by haabe\n")
        credits.append(NSAttributedString(
            string: "Original project on GitHub",
            attributes: [.link: "https://github.com/haabe/can-i-open"]
        ))
        credits.append(NSAttributedString(string: "\n\nForked and further developed by DotComMediaInternetAgency\n"))
        credits.append(NSAttributedString(
            string: "Project repository on GitHub",
            attributes: [.link: "https://github.com/DotComMediaInternetAgency/can-i-open"]
        ))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        credits.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: credits.length)
        )
        return credits
    }
}
