import Foundation

public struct CaptureResult: Sendable {
    public let savedURLs: [URL]

    public var firstSavedURL: URL? {
        savedURLs.first
    }
}
