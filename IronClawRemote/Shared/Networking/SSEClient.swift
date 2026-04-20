import Foundation

struct SSEEventEnvelope: Equatable {
    let id: String?
    let event: String?
    let data: String
}

final class SSEClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func stream(url: URL) -> AsyncThrowingStream<SSEEventEnvelope, Error> {
        let session = self.session

        return AsyncThrowingStream { continuation in
            let task = Task {
                var request = URLRequest(url: url)
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                let (bytes, response) = try await session.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
                    throw GatewayError.invalidResponse
                }
                var currentID: String?
                var currentEvent: String?
                var currentData: [String] = []

                for try await line in bytes.lines {
                    if line.isEmpty {
                        if !currentData.isEmpty {
                            continuation.yield(SSEEventEnvelope(id: currentID, event: currentEvent, data: currentData.joined(separator: "\n")))
                        }
                        currentID = nil
                        currentEvent = nil
                        currentData = []
                        continue
                    }
                    if line.hasPrefix("id:") {
                        currentID = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("event:") {
                        currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        currentData.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
