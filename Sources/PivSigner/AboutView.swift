import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            iconView
                .padding(.top, 28)

            Text(L.s("app.title"))
                .font(.system(size: 24, weight: .semibold))
                .tracking(-0.2)

            Text(L.s("about.version", appVersion))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text(L.s("about.tagline"))
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 36)
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 16)

            VStack(spacing: 4) {
                Text(L.s("about.copyright"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(L.s("about.author"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(L.s("about.licenseShort"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            HStack(spacing: 14) {
                Link(destination: URL(string: "https://github.com/FieldHub-Inc/piv-signer")!) {
                    Label(L.s("about.viewSource"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://github.com/FieldHub-Inc/piv-signer/blob/main/LICENSE")!) {
                    Label(L.s("about.license"), systemImage: "doc.text")
                }
            }
            .controlSize(.small)
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
        .frame(width: 380, height: 480)
        .background(VisualEffectBackground())
    }

    @ViewBuilder private var iconView: some View {
        if let icon = appIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        } else {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 96))
                .foregroundStyle(.tint)
        }
    }

    private var appIcon: NSImage? {
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let appIcon = NSApp.applicationIconImage
        if let appIcon, appIcon.size.width > 0 { return appIcon }
        return nil
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .windowBackground
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

final class AboutWindowController: NSObject {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: AboutView())
            let w = NSWindow(contentViewController: host)
            w.title = ""
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
