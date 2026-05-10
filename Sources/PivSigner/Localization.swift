import Foundation

enum L {
    static func s(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    static func s(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: .module, comment: "")
        return String(format: format, locale: .current, arguments: args)
    }
}
