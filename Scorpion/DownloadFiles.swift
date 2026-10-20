import Foundation

enum DownloadFiles {
    static func safeName(_ suggested: String) -> String {
        let name = suggested.components(separatedBy: CharacterSet(charactersIn: "/\\")).last ?? ""
        let cleaned = name.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) && !"<>:\"|?*".unicodeScalars.contains($0)
        }.map(String.init).joined().trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        if cleaned.isEmpty || cleaned == "." || cleaned == ".." { return "download" }
        // Bound UTF-8 bytes, rather than characters, for filesystem limits.
        var result = ""
        for character in cleaned {
            if (result + String(character)).utf8.count > 180 { break }
            result.append(character)
        }
        return result.isEmpty ? "download" : result
    }

    static func uniqueURL(in directory: URL, name: String, exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        let safe = safeName(name)
        let original = directory.appendingPathComponent(safe)
        let ext = original.pathExtension
        let stem = original.deletingPathExtension().lastPathComponent
        var candidate = original
        var index = 1
        while exists(candidate) {
            let suffix = ext.isEmpty ? "" : "." + ext
            candidate = directory.appendingPathComponent("\(stem) (\(index))\(suffix)")
            index += 1
        }
        return candidate
    }
}
