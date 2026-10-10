import Foundation
import Vision

/// A line of text found by Vision, with its normalized bounding box (origin bottom-left).
struct RecognizedLine: Identifiable, Hashable, Sendable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

enum TextRecognizer {
    enum Failure: LocalizedError {
        case noText
        var errorDescription: String? { "No text found in this image." }
    }

    /// Runs Vision's accurate text recognition off the main thread.
    static func recognize(at url: URL) async throws -> [RecognizedLine] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(url: url, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            let lines = observations.compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return RecognizedLine(text: candidate.string, boundingBox: observation.boundingBox)
            }
            // Reading order: top to bottom, then left to right.
            return lines.sorted { a, b in
                if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.01 {
                    return a.boundingBox.midY > b.boundingBox.midY
                }
                return a.boundingBox.minX < b.boundingBox.minX
            }
        }.value
    }

    /// Recognizes text in several images and joins the results.
    static func text(from urls: [URL]) async -> (text: String, imageCount: Int) {
        var chunks: [String] = []
        var count = 0
        for url in urls {
            if let lines = try? await recognize(at: url), !lines.isEmpty {
                chunks.append(lines.map(\.text).joined(separator: "\n"))
                count += 1
            }
        }
        return (chunks.joined(separator: "\n\n"), count)
    }
}
