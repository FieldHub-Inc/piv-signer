import Foundation
import SwiftUI

struct Profile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var options: SignOptions

    init(id: UUID = UUID(), name: String, options: SignOptions) {
        self.id = id
        self.name = name
        self.options = options
    }
}

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var profiles: [Profile] {
        didSet { persistProfiles() }
    }

    @Published var selectedID: UUID? {
        didSet { persistSelection() }
    }

    private let profilesKey = "PivSigner.profiles.v1"
    private let selectedKey = "PivSigner.profiles.selected"

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data),
           !decoded.isEmpty {
            self.profiles = decoded
        } else {
            self.profiles = ProfileStore.seedProfiles()
        }
        if let raw = defaults.string(forKey: selectedKey),
           let uuid = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == uuid }) {
            self.selectedID = uuid
        } else {
            self.selectedID = profiles.first?.id
        }
    }

    var selected: Profile? {
        profiles.first { $0.id == selectedID }
    }

    func add(named name: String, options: SignOptions) -> Profile {
        let new = Profile(name: name, options: options)
        profiles.append(new)
        selectedID = new.id
        return new
    }

    func duplicate(_ profile: Profile) -> Profile {
        let copyName = "\(profile.name) — copy"
        let copy = Profile(name: copyName, options: profile.options)
        if let idx = profiles.firstIndex(of: profile) {
            profiles.insert(copy, at: idx + 1)
        } else {
            profiles.append(copy)
        }
        selectedID = copy.id
        return copy
    }

    func delete(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if profiles.isEmpty {
            profiles = ProfileStore.seedProfiles()
        }
        if selectedID == id || !profiles.contains(where: { $0.id == selectedID }) {
            selectedID = profiles.first?.id
        }
    }

    func update(_ profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
    }

    private func persistProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }

    private func persistSelection() {
        UserDefaults.standard.set(selectedID?.uuidString, forKey: selectedKey)
    }

    private static func seedProfiles() -> [Profile] {
        [
            Profile(
                name: L.s("profile.default.name"),
                options: SignOptions(
                    attached: true,
                    hash: .sha256,
                    chain: .signerOnly,
                    output: .adjacent,
                    addTimestamp: false
                )
            )
        ]
    }
}
