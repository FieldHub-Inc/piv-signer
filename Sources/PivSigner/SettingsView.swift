import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: ProfileStore = .shared
    @State private var selection: UUID?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 720, height: 480)
        .onAppear {
            if selection == nil { selection = store.selectedID }
        }
    }

    // MARK: Sidebar

    @ViewBuilder private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section(L.s("settings.section.profiles")) {
                    ForEach(store.profiles) { profile in
                        Text(profile.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .tag(profile.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(VisualEffect(material: .sidebar, blending: .behindWindow))

            Divider()

            HStack(spacing: 2) {
                FooterButton(systemName: "plus", help: L.s("profile.add"), action: addProfile)
                FooterButton(systemName: "minus", help: L.s("profile.delete"),
                             enabled: selection != nil, action: deleteCurrent)
                FooterButton(systemName: "doc.on.doc", help: L.s("profile.duplicate"),
                             enabled: selection != nil, action: duplicateCurrent)
                Spacer()
            }
            .frame(height: 24)
            .padding(.horizontal, 6)
            .background(VisualEffect(material: .titlebar, blending: .withinWindow))
        }
        .background(VisualEffect(material: .sidebar, blending: .behindWindow))
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if let id = selection,
           let idx = store.profiles.firstIndex(where: { $0.id == id }) {
            ProfileEditor(profile: $store.profiles[idx])
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(L.s("profile.empty"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func addProfile() {
        let new = store.add(named: L.s("profile.untitled"), options: SignOptions())
        selection = new.id
    }

    private func duplicateCurrent() {
        guard let id = selection,
              let p = store.profiles.first(where: { $0.id == id }) else { return }
        let copy = store.duplicate(p)
        selection = copy.id
    }

    private func deleteCurrent() {
        guard let id = selection else { return }
        store.delete(id)
        selection = store.selectedID
    }
}

// MARK: - Footer button

private struct FooterButton: View {
    let systemName: String
    let help: String
    var enabled: Bool = true
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hovered && enabled ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.primary : Color.secondary)
        .disabled(!enabled)
        .help(help)
        .onHover { hovered = $0 }
    }
}

// MARK: - Visual effect background

private struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}

// MARK: - Profile editor

struct ProfileEditor: View {
    @Binding var profile: Profile

    var body: some View {
        Form {
            Section {
                LabeledContent(L.s("profile.name")) {
                    TextField("", text: $profile.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }
            }

            Section(L.s("options.title")) {
                Picker(L.s("options.format"), selection: $profile.options.attached) {
                    Text(L.s("options.format.attached")).tag(true)
                    Text(L.s("options.format.detached")).tag(false)
                }

                Picker(L.s("options.hash"), selection: $profile.options.hash) {
                    ForEach(SignOptions.Hash.allCases) { h in
                        Text(h.label).tag(h)
                    }
                }

                Picker(L.s("options.chain"), selection: $profile.options.chain) {
                    ForEach(SignOptions.Chain.allCases) { c in
                        Text(L.s(c.localizationKey)).tag(c)
                    }
                }
            }

            Section(L.s("options.output")) {
                Picker("", selection: Binding<Bool>(
                    get: { profile.options.output.isAdjacent },
                    set: { adjacent in
                        if adjacent { profile.options.output = .adjacent }
                        else { pickOutputFolder() }
                    }
                )) {
                    Text(L.s("options.output.adjacent")).tag(true)
                    Text(L.s("options.output.folder")).tag(false)
                }
                .labelsHidden()

                if case .folder(let bookmark) = profile.options.output,
                   let url = SignOptions.resolve(bookmark: bookmark) {
                    HStack {
                        Image(systemName: "folder").foregroundStyle(.secondary)
                        Text(url.path)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(L.s("button.choose"), action: pickOutputFolder)
                            .controlSize(.small)
                    }
                }
            }

            Section(L.s("options.timestamp")) {
                HStack {
                    Toggle("", isOn: $profile.options.addTimestamp)
                        .labelsHidden()
                        .disabled(true)
                    Text(L.s("options.timestamp.soon"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L.s("button.choose")
        if panel.runModal() == .OK, let url = panel.url,
           let bookmark = SignOptions.makeBookmark(for: url) {
            profile.options.output = .folder(bookmark: bookmark)
        }
    }
}
