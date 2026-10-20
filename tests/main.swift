import Foundation

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}
check(DownloadFiles.safeName("../../secret.txt") == "secret.txt", "Unix traversal")
check(DownloadFiles.safeName("C:\\folder\\name.mp4") == "name.mp4", "Windows traversal")
for name in ["", " ", ".", "..", "/", "\\", "\u{0000}\n"] {
    check(DownloadFiles.safeName(name) == "download", "Empty or special filename")
}
check(DownloadFiles.safeName("a\u{0000}b\nc.mp4") == "abc.mp4", "Control characters")
check(DownloadFiles.safeName(".hidden") == "hidden", "Completed files remain visible")
check(!DownloadFiles.safeName("a:b?c*").contains(":"), "Reserved characters")
check(DownloadFiles.safeName(String(repeating: "🦂", count: 100)).utf8.count <= 180, "UTF-8 byte limit")
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let first = directory.appendingPathComponent("movie.mp4")
let second = directory.appendingPathComponent("movie (1).mp4")
try Data([1]).write(to: first)
try Data([2]).write(to: second)
check(DownloadFiles.uniqueURL(in: directory, name: "movie.mp4").lastPathComponent == "movie (2).mp4", "No duplicate overwrite")
let originalData = try Data(contentsOf: first)
check(originalData == Data([1]), "Original preserved")
check(DownloadFiles.uniqueURL(in: directory, name: "../../new").deletingLastPathComponent() == directory, "Destination containment")
check(NavigationRules.isSite(URL(string: "https://cobalt.meowing.de:443/a")!), "Exact HTTPS origin")
for address in ["http://cobalt.meowing.de/", "https://cobalt.meowing.de.evil.test/", "https://cobalt.meowing.de:444/", "https://elsewhere.test/"] {
    check(!NavigationRules.isSite(URL(string: address)!), "Reject foreign origin")
}
for address in ["file:///etc/passwd", "javascript:alert(1)", "tel:123", "data:text/html,hello", "blob:https://evil.test/id"] {
    check(!NavigationRules.allowsInternalURL(URL(string: address)!), "Reject custom/local URL")
}
check(NavigationRules.allowsInternalURL(URL(string: "blob:https://cobalt.meowing.de/id")!), "Same-origin blob")
check(NavigationRules.allowsInternalURL(URL(string: "https://download.test/file.mp4")!), "Allow external response inspection")
let external = URL(string: "https://download.test/file")!
for mime in ["video/mp4", "audio/mpeg", "image/jpeg"] {
    check(NavigationRules.responseDisposition(url: external, mime: mime, canDisplay: true, attachment: false, mainFrame: true) == .download, "Displayable external media downloads")
}
check(NavigationRules.responseDisposition(url: external, mime: "text/html", canDisplay: true, attachment: false, mainFrame: true) == .external, "External HTML opens Safari after response inspection")
check(NavigationRules.responseDisposition(url: NavigationRules.home, mime: "text/html", canDisplay: true, attachment: false, mainFrame: true) == .display, "Site navigation stays inside app")
check(NavigationRules.responseDisposition(url: external, mime: "text/html", canDisplay: true, attachment: true, mainFrame: true) == .download, "Attachment wins over external browser routing")
check(NavigationRules.responseDisposition(url: external, mime: "application/octet-stream", canDisplay: false, attachment: false, mainFrame: true) == .download, "Non-displayable response downloads")
check(NavigationRules.responseDisposition(url: external, mime: "application/octet-stream", canDisplay: false, attachment: true, mainFrame: false) == .cancel, "Subframes cannot trigger response download")
print("Passed \(checks) Swift filesystem and navigation checks")
