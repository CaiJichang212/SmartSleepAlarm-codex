import Foundation

public struct WatchMessageCodec {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.encoder = encoder
        self.decoder = decoder
    }

    public func encode(_ message: WatchMessageEnvelope) throws -> Data {
        try encoder.encode(message)
    }

    public func decode(_ data: Data) throws -> WatchMessageEnvelope {
        try decoder.decode(WatchMessageEnvelope.self, from: data)
    }
}
