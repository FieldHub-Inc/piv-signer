import Foundation
import Security
import SecurityInterface
import AppKit

enum CertificateInspector {
    @MainActor
    static func show(_ identity: SmartCardIdentity) {
        var cert: SecCertificate?
        guard SecIdentityCopyCertificate(identity.identity, &cert) == errSecSuccess,
              let cert
        else { return }
        show(cert)
    }

    @MainActor
    static func show(_ certificate: SecCertificate) {
        guard let panel = SFCertificatePanel.shared() else { return }
        _ = panel.runModal(forCertificates: [certificate], showGroup: true)
    }
}
