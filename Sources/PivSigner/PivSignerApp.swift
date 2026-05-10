import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let win = NSApp.windows.first {
            win.titlebarAppearsTransparent = false
            win.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct PivSignerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _ = SmartCardWatcher.shared
    }

    var body: some Scene {
        WindowGroup(L.s("app.title")) {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button(L.s("menu.about")) {
                    let credits = "\(L.s("about.tagline"))\n\n\(L.s("about.copyright"))"
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: L.s("app.title"),
                        .credits: NSAttributedString(
                            string: credits,
                            attributes: [.font: NSFont.systemFont(ofSize: 11)]
                        ),
                    ])
                }
            }
        }
    }
}
