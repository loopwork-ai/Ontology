import Foundation

public struct DateTime: Hashable, Sendable {
    public var value: Date
    public var timeZone: TimeZone?

    public init(_ value: Date, timeZone: TimeZone? = nil) {
        self.value = value
        self.timeZone = timeZone
    }

    public init?(string: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: string) else { return nil }
        self.value = date
        self.timeZone = TimeZone(iso8601: string)
    }
}

extension DateTime: Codable {
    private enum CodingKeys: String, CodingKey {
        case value
        case timeZone
    }

    /// A user info key that allows overriding the TimeZone used when encoding DateTime values.
    ///
    /// When encoding a DateTime, the TimeZone is determined in the following priority order:
    /// 1. TimeZone from encoder.userInfo[DateTime.timeZoneOverrideKey] (if provided)
    /// 2. TimeZone from the DateTime instance (if specified)
    /// 3. GMT/UTC (default fallback)
    ///
    /// This is particularly useful for ensuring dates are interpreted correctly across different
    /// time zones, or when you want to present all dates in a specific time zone regardless
    /// of how they were originally stored.
    ///
    /// Example usage:
    /// ```
    /// let encoder = JSONEncoder()
    /// encoder.userInfo[DateTime.timeZoneOverrideKey] = TimeZone.current
    /// let encodedData = try encoder.encode(myDateTime)
    /// ```
    public static let timeZoneOverrideKey = CodingUserInfoKey(
        rawValue: "me.mattt.Ontology.DateTimeEncodingTimeZone")!

    public init(from decoder: Decoder) throws {
        do {
            // Try decoding as a JSON-LD object first
            let container = try decoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
            let string = try container.decode(String.self, forKey: .attribute(.value))
            guard let date = DateTime(string: string) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Invalid date format"
                    )
                )
            }
            self = date
        } catch {
            // Fall back to decoding as a bare string
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = DateTime(string: string) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Invalid date format"
                    )
                )
            }
            self = date
        }
    }

    public func encode(to encoder: Encoder) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Check if a TimeZone was provided in userInfo
        if let userInfoTimeZone = encoder.userInfo[DateTime.timeZoneOverrideKey] as? TimeZone {
            formatter.timeZone = userInfoTimeZone
        } else if let timeZone = timeZone {
            formatter.timeZone = timeZone
        } else {
            formatter.timeZone = .gmt
        }

        let string = formatter.string(from: value)

        // Check if we're being encoded as part of a JSON-LD document
        if encoder.codingPath.isEmpty {
            var container = encoder.container(keyedBy: JSONLDCodingKey<CodingKeys>.self)
            try container.encode(schema.org, forKey: .context)
            try container.encode(String(describing: Self.self), forKey: .type)
            try container.encode(string, forKey: .attribute(.value))
        } else {
            // Encode as a bare string
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }
    }
}
