import Foundation
import CryptoTokenKit

final class SmartCardWatcher {
    static let changedNotification = Notification.Name("PivSigner.SmartCardChanged")
    static let shared = SmartCardWatcher()
    private let watcher = TKTokenWatcher()

    private init() {
        watcher.setInsertionHandler { [weak self] tokenID in
            guard let self else { return }
            NotificationCenter.default.post(name: Self.changedNotification, object: tokenID)
            self.watcher.addRemovalHandler({ _ in
                NotificationCenter.default.post(name: Self.changedNotification, object: nil)
            }, forTokenID: tokenID)
        }
    }
}
