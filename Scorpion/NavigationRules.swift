import Foundation

enum NavigationRules {
    enum ResponseDisposition { case display, download, external, cancel }
    static let home = URL(string: "https://cobalt.meowing.de/")!

    static func isSite(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host?.lowercased() == "cobalt.meowing.de" && (url.port == nil || url.port == 443)
    }

    static func isWeb(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "")
    }

    static func allowsInternalURL(_ url: URL) -> Bool {
        if isWeb(url) { return true }
        if url.absoluteString == "about:blank" { return true }
        if url.scheme == "blob", let origin = URL(string: String(url.absoluteString.dropFirst(5))) {
            return isSite(origin)
        }
        return false
    }

    static func responseDisposition(url: URL?, mime: String?, canDisplay: Bool, attachment: Bool, mainFrame: Bool) -> ResponseDisposition {
        let mime = mime?.lowercased() ?? ""
        let externalMedia = url.map { !isSite($0) } == true && ["video/", "audio/", "image/"].contains { mime.hasPrefix($0) }
        if !canDisplay || attachment || externalMedia { return mainFrame ? .download : .cancel }
        if mainFrame, let url, isWeb(url), !isSite(url) { return .external }
        return .display
    }
}
