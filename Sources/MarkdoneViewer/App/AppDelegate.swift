import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var openFileHandler: ((URL) -> Void)?
    private var shouldTerminateHandler: (() -> Bool)?
    private var pendingOpenURLs: [URL] = []

    func install(
        openFileHandler: @escaping (URL) -> Void,
        shouldTerminateHandler: @escaping () -> Bool
    ) {
        self.openFileHandler = openFileHandler
        self.shouldTerminateHandler = shouldTerminateHandler

        let pending = pendingOpenURLs
        pendingOpenURLs.removeAll()
        pending.forEach(openFileHandler)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let openFileHandler else {
            pendingOpenURLs.append(contentsOf: urls.prefix(1))
            return
        }

        urls.prefix(1).forEach(openFileHandler)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shouldTerminateHandler?() == false {
            return .terminateCancel
        }

        return .terminateNow
    }
}
