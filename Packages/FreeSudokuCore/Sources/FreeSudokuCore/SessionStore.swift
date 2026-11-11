import Foundation

/// Local-only persistence. Reading never repairs, deletes, or overwrites a save.
public struct SessionStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> SavedSession? {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && (error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError)
        {
            return nil
        }
        defer { try? handle.close() }
        // Read at most one byte beyond the supported size, never the whole untrusted file.
        var data = Data()
        while data.count <= SavedSession.maximumBytes {
            let chunk = try handle.read(upToCount: min(64 * 1024, SavedSession.maximumBytes + 1 - data.count))
            guard let chunk, !chunk.isEmpty else { break }
            data.append(chunk)
        }
        return try SavedSession.decode(data)
    }

    public func save(_ session: SavedSession) throws {
        let data = try session.encoded()
        guard data.count <= SavedSession.maximumBytes else { throw GameError.invalidSave }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
