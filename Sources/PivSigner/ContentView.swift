import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum AppMode: String, CaseIterable, Identifiable {
    case sign, verify
    var id: String { rawValue }
    var titleKey: String { self == .sign ? "mode.sign" : "mode.verify" }
    var icon: String { self == .sign ? "signature" : "checkmark.shield" }
}

struct ContentView: View {
    @State private var mode: AppMode = .sign
    @State private var identities: [SmartCardIdentity] = []
    @State private var selectedIdentity: SmartCardIdentity?

    var body: some View {
        Group {
            switch mode {
            case .sign:
                SignView(identities: identities, selectedIdentity: $selectedIdentity)
            case .verify:
                VerifyView()
            }
        }
        .frame(minWidth: 620, minHeight: 560)
        .navigationTitle(L.s("app.title"))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $mode) {
                    ForEach(AppMode.allCases) { m in
                        Label(L.s(m.titleKey), systemImage: m.icon).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
        }
        .onAppear(perform: refreshIdentities)
        .onReceive(NotificationCenter.default.publisher(for: SmartCardWatcher.changedNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshIdentities() }
        }
    }

    private func refreshIdentities() {
        let found = SignerCore.discoverIdentities()
        identities = found
        if let cur = selectedIdentity, !found.contains(cur) {
            selectedIdentity = found.first
        } else if selectedIdentity == nil {
            selectedIdentity = found.first
        }
    }
}

// MARK: - Sign View

struct SignView: View {
    let identities: [SmartCardIdentity]
    @Binding var selectedIdentity: SmartCardIdentity?

    @State private var fileURLs: [URL] = []
    @State private var isSigning = false
    @State private var batchResult: BatchSignResult?
    @State private var errorMessage: String?

    @State private var preset: SignPreset = PreferenceStore.loadSelectedPreset()
    @State private var options: SignOptions = PreferenceStore.loadSelectedPreset().options()

    var body: some View {
        Form {
            Section {
                CardStatusRow(
                    identities: identities,
                    selected: selectedIdentity,
                    onRefresh: refreshIdentities
                )
                if identities.count > 1 {
                    Picker(L.s("cert.picker.label"), selection: $selectedIdentity) {
                        ForEach(identities) { id in
                            Text(id.commonName).tag(Optional(id))
                        }
                    }
                }
            }

            optionsSection

            Section {
                MultiFileDropZone(urls: $fileURLs, titleKey: "drop.sign.title")
                    .onChange(of: fileURLs) { _ in
                        batchResult = nil
                        errorMessage = nil
                    }
            }

            if let batchResult {
                resultSection(batchResult)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: Options section

    @ViewBuilder private var optionsSection: some View {
        Section(L.s("options.title")) {
            Picker(L.s("options.preset"), selection: $preset) {
                ForEach(SignPreset.allCases) { p in
                    Text(L.s(p.localizationKey)).tag(p)
                }
            }
            .onChange(of: preset) { newValue in
                PreferenceStore.saveSelectedPreset(newValue)
                if newValue != .custom {
                    options = newValue.options()
                }
            }

            Picker(L.s("options.format"), selection: $options.attached) {
                Text(L.s("options.format.attached")).tag(true)
                Text(L.s("options.format.detached")).tag(false)
            }
            .pickerStyle(.segmented)

            Picker(L.s("options.hash"), selection: $options.hash) {
                ForEach(SignOptions.Hash.allCases) { h in
                    Text(h.label).tag(h)
                }
            }

            Picker(L.s("options.chain"), selection: $options.chain) {
                ForEach(SignOptions.Chain.allCases) { c in
                    Text(L.s(c.localizationKey)).tag(c)
                }
            }

            outputControl

            timestampControl
        }
        .onChange(of: options) { newValue in
            let matched = SignPreset.match(newValue)
            if matched != preset {
                preset = matched
            }
            if matched == .custom {
                PreferenceStore.saveCustomOptions(newValue)
            }
        }
    }

    @ViewBuilder private var outputControl: some View {
        let isAdjacent = options.output.isAdjacent
        Picker(L.s("options.output"), selection: Binding<Bool>(
            get: { isAdjacent },
            set: { adjacent in
                if adjacent {
                    options.output = .adjacent
                } else {
                    pickOutputFolder()
                }
            }
        )) {
            Text(L.s("options.output.adjacent")).tag(true)
            Text(L.s("options.output.folder")).tag(false)
        }

        if case .folder(let bookmark) = options.output,
           let url = SignOptions.resolve(bookmark: bookmark) {
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(L.s("options.output.folderName", url.path))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(L.s("button.choose"), action: pickOutputFolder)
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder private var timestampControl: some View {
        HStack {
            Toggle(L.s("options.timestamp"), isOn: $options.addTimestamp)
                .disabled(true)
            Spacer()
            Text(L.s("options.timestamp.soon"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1), in: Capsule())
        }
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L.s("button.choose")
        if panel.runModal() == .OK, let url = panel.url {
            if let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                options.output = .folder(bookmark: bookmark)
            }
        } else if !options.output.isAdjacent == false {
            options.output = .adjacent
        }
    }

    // MARK: Bottom bar

    @ViewBuilder private var bottomBar: some View {
        HStack {
            if !fileURLs.isEmpty {
                Text(fileURLs.count == 1
                     ? fileURLs[0].lastPathComponent
                     : L.s("drop.files.count", fileURLs.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(action: sign) {
                HStack(spacing: 8) {
                    if isSigning { ProgressView().controlSize(.small) }
                    Text(L.s(isSigning ? "button.signing" : "button.sign"))
                }
                .frame(minWidth: 140)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSign)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: Result

    @ViewBuilder private func resultSection(_ result: BatchSignResult) -> some View {
        let succeeded = result.succeeded
        let failed = result.failed

        Section {
            HStack(spacing: 12) {
                Image(systemName: failed.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(failed.isEmpty ? .green : .orange)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(failed.isEmpty
                         ? L.s("result.batch.allOk", succeeded.count)
                         : L.s("result.batch.summary", succeeded.count, failed.count))
                        .font(.headline)
                }
                Spacer()
                if let firstOK = succeeded.first?.output {
                    Button(L.s("button.showInFinder")) {
                        let urls = succeeded.compactMap(\.output)
                        NSWorkspace.shared.activateFileViewerSelecting(urls.isEmpty ? [firstOK] : urls)
                    }
                }
            }
        }

        if !succeeded.isEmpty {
            Section {
                ForEach(succeeded.indices, id: \.self) { i in
                    let item = succeeded[i]
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.source.lastPathComponent).font(.callout)
                            if let out = item.output {
                                Text(out.lastPathComponent)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }

        if !failed.isEmpty {
            Section {
                ForEach(failed.indices, id: \.self) { i in
                    let item = failed[i]
                    HStack(alignment: .top) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.source.lastPathComponent).font(.callout)
                            if let err = item.error {
                                Text(L.s("result.failure", err.localizedDescription))
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: Actions

    private var canSign: Bool {
        !fileURLs.isEmpty && selectedIdentity != nil && !isSigning
    }

    private func refreshIdentities() {
        NotificationCenter.default.post(name: SmartCardWatcher.changedNotification, object: nil)
    }

    private func sign() {
        guard !fileURLs.isEmpty, let id = selectedIdentity else { return }
        isSigning = true
        batchResult = nil
        errorMessage = nil
        let urls = fileURLs
        let opts = options
        DispatchQueue.global(qos: .userInitiated).async {
            let result = SignerCore.sign(urls: urls, identity: id.identity, options: opts)
            DispatchQueue.main.async {
                self.batchResult = result
                self.isSigning = false
            }
        }
    }
}

// MARK: - Verify View

struct VerifyView: View {
    @State private var fileURL: URL?
    @State private var isVerifying = false
    @State private var result: VerificationResult?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                FileDropZone(
                    fileURL: $fileURL,
                    titleKey: "drop.verify.title",
                    allowedTypes: [UTType(filenameExtension: "p7m") ?? .data, .data]
                )
                .onChange(of: fileURL) { _ in
                    result = nil
                    errorMessage = nil
                }
            }

            if let result {
                Section {
                    VerifyHeader(valid: result.allValid)
                }
                Section(L.s("verify.signers")) {
                    ForEach(result.signers) { s in
                        SignerRow(signer: s)
                    }
                }
                Section {
                    HStack {
                        Label {
                            Text(L.s("verify.payloadSize"))
                        } icon: {
                            Image(systemName: "doc")
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: Int64(result.payload.count), countStyle: .file))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Button(L.s("button.savePayload")) {
                        savePayload(result.payload)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button(action: verify) {
                    HStack(spacing: 8) {
                        if isVerifying { ProgressView().controlSize(.small) }
                        Text(L.s(isVerifying ? "button.verifying" : "button.verify"))
                    }
                    .frame(minWidth: 140)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(fileURL == nil || isVerifying)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func verify() {
        guard let fileURL else { return }
        isVerifying = true
        result = nil
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let r = try SignerCore.verify(fileURL: fileURL)
                DispatchQueue.main.async {
                    self.result = r
                    self.isVerifying = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isVerifying = false
                }
            }
        }
    }

    private func savePayload(_ data: Data) {
        guard let fileURL else { return }
        let name = fileURL.deletingPathExtension().lastPathComponent
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.directoryURL = fileURL.deletingLastPathComponent()
        if panel.runModal() == .OK, let dest = panel.url {
            try? data.write(to: dest)
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        }
    }
}

// MARK: - Reusable rows

struct CardStatusRow: View {
    let identities: [SmartCardIdentity]
    let selected: SmartCardIdentity?
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(identities.isEmpty ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: identities.isEmpty ? "key.slash" : "key.fill")
                    .foregroundStyle(identities.isEmpty ? .red : .green)
            }

            VStack(alignment: .leading, spacing: 2) {
                if identities.isEmpty {
                    Text(L.s("card.title.empty")).font(.headline)
                    Text(L.s("card.subtitle.empty"))
                        .font(.caption).foregroundStyle(.secondary)
                } else if let s = selected {
                    Text(s.commonName).font(.headline).lineLimit(1)
                    if let exp = s.notAfter {
                        Text(L.s("card.subtitle.validUntil", exp.formatted(date: .long, time: .omitted)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(L.s("card.refresh"))
        }
    }
}

struct VerifyHeader: View {
    let valid: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: valid ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundStyle(valid ? .green : .red)
                .font(.title)
            Text(L.s(valid ? "verify.title.valid" : "verify.title.invalid"))
                .font(.headline)
            Spacer()
        }
    }
}

struct SignerRow: View {
    let signer: VerifiedSigner

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: signer.statusOK ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                    .foregroundStyle(signer.statusOK ? .green : .red)
                Text(signer.commonName).font(.headline)
                Spacer()
            }
            if !signer.issuer.isEmpty {
                LabeledContent(L.s("verify.issuer")) {
                    Text(signer.issuer).foregroundStyle(.secondary)
                }
                .font(.callout)
            }
            if let date = signer.signedAt {
                LabeledContent(L.s("verify.signedAt")) {
                    Text(date.formatted(date: .abbreviated, time: .standard))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.callout)
            }
            if !signer.trusted {
                Label(L.s("verify.notTrusted"), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Drop zones

struct FileDropZone: View {
    @Binding var fileURL: URL?
    let titleKey: String
    let allowedTypes: [UTType]
    @State private var isTargeted = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 160)
            .padding(16)
            .background(background)
            .overlay(border)
            .contentShape(Rectangle())
            .onTapGesture { if fileURL == nil { pickFile() } }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 10) {
            icon
            if let fileURL {
                fileInfo(for: fileURL)
            } else {
                Text(L.s(titleKey)).font(.headline)
                Text(L.s("drop.subtitle"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var icon: some View {
        Image(systemName: fileURL == nil ? "tray.and.arrow.down" : "doc.fill")
            .font(.system(size: 34, weight: .light))
            .foregroundStyle(fileURL == nil ? Color.secondary : Color.accentColor)
    }

    @ViewBuilder private func fileInfo(for url: URL) -> some View {
        Text(url.lastPathComponent)
            .font(.headline)
            .lineLimit(1).truncationMode(.middle)
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            let human = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            Text(L.s("file.size", human))
                .font(.caption).foregroundStyle(.secondary)
        }
        HStack(spacing: 12) {
            Button(L.s("button.choose"), action: pickFile)
            Button(L.s("button.clear"), role: .destructive) { self.fileURL = nil }
        }
        .controlSize(.small)
        .padding(.top, 4)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private var border: some View {
        let dash: [CGFloat] = fileURL == nil ? [6, 4] : []
        let color: Color = isTargeted ? .accentColor : Color.secondary.opacity(0.35)
        return RoundedRectangle(cornerRadius: 10)
            .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: dash))
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true)
            else { return }
            DispatchQueue.main.async { self.fileURL = url }
        }
        return true
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedTypes
        if panel.runModal() == .OK, let url = panel.url {
            self.fileURL = url
        }
    }
}

struct MultiFileDropZone: View {
    @Binding var urls: [URL]
    let titleKey: String
    @State private var isTargeted = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding(16)
            .background(background)
            .overlay(border)
            .contentShape(Rectangle())
            .onTapGesture { if urls.isEmpty { pickFiles() } }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 10) {
            icon
            if urls.isEmpty {
                Text(L.s(titleKey)).font(.headline)
                Text(L.s("drop.subtitle"))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                fileList
            }
        }
    }

    private var icon: some View {
        Image(systemName: urls.isEmpty ? "tray.and.arrow.down" : (urls.count == 1 ? "doc.fill" : "doc.on.doc.fill"))
            .font(.system(size: 32, weight: .light))
            .foregroundStyle(urls.isEmpty ? Color.secondary : Color.accentColor)
    }

    @ViewBuilder private var fileList: some View {
        if urls.count == 1, let url = urls.first {
            Text(url.lastPathComponent).font(.headline)
                .lineLimit(1).truncationMode(.middle)
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                Text(L.s("file.size", ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text(L.s("drop.files.count", urls.count)).font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(urls.prefix(8), id: \.self) { url in
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if urls.count > 8 {
                        Text("+ \(urls.count - 8)…")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 80)
        }
        HStack(spacing: 12) {
            Button(L.s("button.choose"), action: pickFiles)
            Button(L.s("button.clear"), role: .destructive) { urls = [] }
        }
        .controlSize(.small)
        .padding(.top, 4)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    private var border: some View {
        let dash: [CGFloat] = urls.isEmpty ? [6, 4] : []
        let color: Color = isTargeted ? .accentColor : Color.secondary.opacity(0.35)
        return RoundedRectangle(cornerRadius: 10)
            .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: dash))
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true)
                else { return }
                lock.lock(); collected.append(url); lock.unlock()
            }
        }
        group.notify(queue: .main) {
            self.urls = collected
        }
        return !providers.isEmpty
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            urls = panel.urls
        }
    }
}
