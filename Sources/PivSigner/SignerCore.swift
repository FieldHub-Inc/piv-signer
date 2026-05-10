import Foundation
import Security

struct SmartCardIdentity: Identifiable, Hashable {
    let id: String
    let identity: SecIdentity
    let commonName: String
    let notAfter: Date?

    static func == (l: SmartCardIdentity, r: SmartCardIdentity) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct VerifiedSigner: Identifiable {
    let id = UUID()
    let commonName: String
    let issuer: String
    let signedAt: Date?
    let trusted: Bool
    let statusOK: Bool
    let certificate: SecCertificate?
}

struct VerificationResult {
    let allValid: Bool
    let signers: [VerifiedSigner]
    let payload: Data
}

struct BatchSignResult {
    struct Item {
        let source: URL
        let output: URL?
        let error: Error?
        var ok: Bool { error == nil && output != nil }
    }
    let items: [Item]
    var succeeded: [Item] { items.filter { $0.ok } }
    var failed: [Item] { items.filter { !$0.ok } }
}

enum SignerError: LocalizedError {
    case cms(OSStatus, kind: Kind)
    case read(String)
    case notCMS
    case noContent

    enum Kind { case sign, verify }

    var errorDescription: String? {
        switch self {
        case .cms(let s, let kind):
            let msg = SecCopyErrorMessageString(s, nil) as String? ?? "OSStatus \(s)"
            return L.s(kind == .sign ? "error.signing" : "error.verifying", msg)
        case .read(let path):
            return L.s("error.readFile", path)
        case .notCMS:
            return L.s("error.notCMS")
        case .noContent:
            return L.s("error.noContent")
        }
    }
}

enum SignerCore {
    // MARK: - Identities

    static func discoverIdentities() -> [SmartCardIdentity] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true,
            kSecAttrAccessGroup as String: kSecAttrAccessGroupToken,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let arr = out as? [SecIdentity] else { return [] }
        return arr.compactMap(buildModel)
    }

    private static func buildModel(_ ident: SecIdentity) -> SmartCardIdentity? {
        var cert: SecCertificate?
        guard SecIdentityCopyCertificate(ident, &cert) == errSecSuccess, let cert else { return nil }
        let cn = certificateCommonName(cert)
        let notAfter = certificateNotAfter(cert)
        let fp = SecCertificateCopyData(cert) as Data
        return SmartCardIdentity(
            id: fp.base64EncodedString(),
            identity: ident,
            commonName: cn,
            notAfter: notAfter
        )
    }

    private static func certificateCommonName(_ cert: SecCertificate) -> String {
        var cn: CFString?
        SecCertificateCopyCommonName(cert, &cn)
        return (cn as String?)
            ?? (SecCertificateCopySubjectSummary(cert) as String?)
            ?? "Unknown"
    }

    private static func certificateIssuer(_ cert: SecCertificate) -> String {
        let keys = [kSecOIDX509V1IssuerName] as CFArray
        guard let dict = SecCertificateCopyValues(cert, keys, nil) as? [String: [String: Any]],
              let issuer = dict[kSecOIDX509V1IssuerName as String]?["value"] as? [[String: Any]]
        else { return "" }
        let parts: [String] = issuer.compactMap { entry in
            guard let label = entry["label"] as? String,
                  let value = entry["value"] as? String,
                  label == "2.5.4.3" || label == "CN" else { return nil }
            return value
        }
        if !parts.isEmpty { return parts.joined(separator: ", ") }
        return (SecCertificateCopySubjectSummary(cert) as String?) ?? ""
    }

    private static func certificateNotAfter(_ cert: SecCertificate) -> Date? {
        let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
        guard let dict = SecCertificateCopyValues(cert, keys, nil) as? [String: [String: Any]],
              let ts = dict[kSecOIDX509V1ValidityNotAfter as String]?["value"] as? Double
        else { return nil }
        return Date(timeIntervalSinceReferenceDate: ts)
    }

    // MARK: - Sign

    static func sign(urls: [URL], identity: SecIdentity, options: SignOptions) -> BatchSignResult {
        let items = urls.map { url -> BatchSignResult.Item in
            do {
                let out = try signOne(fileURL: url, identity: identity, options: options)
                return BatchSignResult.Item(source: url, output: out, error: nil)
            } catch {
                return BatchSignResult.Item(source: url, output: nil, error: error)
            }
        }
        return BatchSignResult(items: items)
    }

    private static func signOne(fileURL: URL, identity: SecIdentity, options: SignOptions) throws -> URL {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw SignerError.read(fileURL.lastPathComponent)
        }

        var enc: CMSEncoder?
        try check(CMSEncoderCreate(&enc), .sign)
        let encoder = enc!

        try check(CMSEncoderAddSigners(encoder, identity), .sign)
        try check(CMSEncoderSetSignerAlgorithm(encoder, options.hash.cmsAlgorithm), .sign)
        try check(CMSEncoderSetCertificateChainMode(encoder, options.chain.cmsMode), .sign)
        try check(CMSEncoderSetHasDetachedContent(encoder, !options.attached), .sign)
        try check(CMSEncoderAddSignedAttributes(encoder, CMSSignedAttributes.attrSigningTime), .sign)

        try data.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            try check(CMSEncoderUpdateContent(encoder, base, buf.count), .sign)
        }

        var signed: CFData?
        try check(CMSEncoderCopyEncodedContent(encoder, &signed), .sign)

        let outURL = options.outputURL(for: fileURL)
        try FileManager.default.createDirectory(
            at: outURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try (signed! as Data).write(to: outURL)
        return outURL
    }

    // MARK: - Verify

    static func verify(fileURL: URL) throws -> VerificationResult {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw SignerError.read(fileURL.lastPathComponent)
        }

        var dec: CMSDecoder?
        try check(CMSDecoderCreate(&dec), .verify)
        let decoder = dec!

        try data.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            try check(CMSDecoderUpdateMessage(decoder, base, buf.count), .verify)
        }
        try check(CMSDecoderFinalizeMessage(decoder), .verify)

        var numSigners: size_t = 0
        try check(CMSDecoderGetNumSigners(decoder, &numSigners), .verify)
        guard numSigners > 0 else { throw SignerError.notCMS }

        let policy = SecPolicyCreateBasicX509()

        var signers: [VerifiedSigner] = []
        var allOK = true

        for i in 0..<numSigners {
            var status: CMSSignerStatus = .unsigned
            var trust: SecTrust?
            var certVerifyStatus: OSStatus = errSecSuccess
            CMSDecoderCopySignerStatus(decoder, i, policy, true, &status, &trust, &certVerifyStatus)

            var cert: SecCertificate?
            CMSDecoderCopySignerCert(decoder, i, &cert)

            var signingTime: CFAbsoluteTime = 0
            let timeStatus = CMSDecoderCopySignerSigningTime(decoder, i, &signingTime)
            let date: Date? = timeStatus == errSecSuccess
                ? Date(timeIntervalSinceReferenceDate: signingTime)
                : nil

            let cn = cert.map(certificateCommonName) ?? "Unknown"
            let issuer = cert.map(certificateIssuer) ?? ""
            let trusted = certVerifyStatus == errSecSuccess
            let ok = status == .valid

            if !ok { allOK = false }

            signers.append(VerifiedSigner(
                commonName: cn,
                issuer: issuer,
                signedAt: date,
                trusted: trusted,
                statusOK: ok,
                certificate: cert
            ))
        }

        var payload: CFData?
        CMSDecoderCopyContent(decoder, &payload)
        guard let payloadData = payload as Data? else { throw SignerError.noContent }

        return VerificationResult(allValid: allOK, signers: signers, payload: payloadData)
    }

    static func saveExtracted(_ data: Data, suggested name: String, to url: URL) throws {
        try data.write(to: url)
    }

    // MARK: - Helpers

    private static func check(_ status: OSStatus, _ kind: SignerError.Kind) throws {
        if status != errSecSuccess { throw SignerError.cms(status, kind: kind) }
    }
}
