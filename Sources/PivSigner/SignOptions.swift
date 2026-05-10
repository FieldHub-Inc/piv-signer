import Foundation
import Security

struct SignOptions: Codable, Equatable {
    enum Hash: String, CaseIterable, Codable, Identifiable {
        case sha256, sha384, sha512
        var id: String { rawValue }
        var label: String {
            switch self {
            case .sha256: return "SHA-256"
            case .sha384: return "SHA-384"
            case .sha512: return "SHA-512"
            }
        }
        var cmsAlgorithm: CFString {
            switch self {
            case .sha256: return kCMSEncoderDigestAlgorithmSHA256
            case .sha384: return "SHA384" as CFString
            case .sha512: return "SHA512" as CFString
            }
        }
    }

    enum Chain: String, CaseIterable, Codable, Identifiable {
        case signerOnly, intermediates, full
        var id: String { rawValue }
        var localizationKey: String {
            switch self {
            case .signerOnly: return "options.chain.signer"
            case .intermediates: return "options.chain.intermediates"
            case .full: return "options.chain.full"
            }
        }
        var cmsMode: CMSCertificateChainMode {
            switch self {
            case .signerOnly: return .signerOnly
            case .intermediates: return .chain
            case .full: return .chainWithRoot
            }
        }
    }

    enum Output: Codable, Equatable {
        case adjacent
        case folder(bookmark: Data)

        var isAdjacent: Bool {
            if case .adjacent = self { return true }
            return false
        }
    }

    var attached: Bool = true
    var hash: Hash = .sha256
    var chain: Chain = .intermediates
    var output: Output = .adjacent
    var addTimestamp: Bool = false   // RFC 3161 — UI is wired but execution is not implemented yet

    func outputURL(for source: URL) -> URL {
        let ext = attached ? "p7m" : "p7s"
        switch output {
        case .adjacent:
            return source.appendingPathExtension(ext)
        case .folder(let bookmark):
            if let dir = SignOptions.resolve(bookmark: bookmark) {
                return dir
                    .appendingPathComponent(source.lastPathComponent)
                    .appendingPathExtension(ext)
            }
            return source.appendingPathExtension(ext)
        }
    }

    static func resolve(bookmark: Data) -> URL? {
        var stale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }
}

enum SignPreset: String, CaseIterable, Identifiable {
    case `default`, strict, minimal, custom
    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .default: return "options.preset.default"
        case .strict: return "options.preset.strict"
        case .minimal: return "options.preset.minimal"
        case .custom: return "options.preset.custom"
        }
    }

    func options() -> SignOptions {
        switch self {
        case .default:
            return SignOptions(attached: true, hash: .sha256, chain: .intermediates, output: .adjacent)
        case .strict:
            return SignOptions(attached: true, hash: .sha512, chain: .full, output: .adjacent)
        case .minimal:
            return SignOptions(attached: true, hash: .sha256, chain: .signerOnly, output: .adjacent)
        case .custom:
            return PreferenceStore.loadCustomOptions()
        }
    }

    static func match(_ options: SignOptions) -> SignPreset {
        for p in [SignPreset.default, .strict, .minimal] {
            let preset = p.options()
            if preset.attached == options.attached
                && preset.hash == options.hash
                && preset.chain == options.chain
                && preset.output.isAdjacent == options.output.isAdjacent
                && options.output.isAdjacent {
                return p
            }
        }
        return .custom
    }
}

enum PreferenceStore {
    private static let customKey = "PivSigner.customOptions"
    private static let presetKey = "PivSigner.selectedPreset"

    static func loadCustomOptions() -> SignOptions {
        guard let data = UserDefaults.standard.data(forKey: customKey),
              let opts = try? JSONDecoder().decode(SignOptions.self, from: data)
        else { return SignPreset.default.options() }
        return opts
    }

    static func saveCustomOptions(_ options: SignOptions) {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
    }

    static func loadSelectedPreset() -> SignPreset {
        if let raw = UserDefaults.standard.string(forKey: presetKey),
           let preset = SignPreset(rawValue: raw) {
            return preset
        }
        return .default
    }

    static func saveSelectedPreset(_ preset: SignPreset) {
        UserDefaults.standard.set(preset.rawValue, forKey: presetKey)
    }
}
