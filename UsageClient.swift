import Foundation

protocol UsageFetching {
    func fetchUsage() async throws -> UsageData
}

enum UsageError: LocalizedError {
    case notAuthenticated
    case missingOrgUUID
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in. Paste your sessionKey in Settings."
        case .missingOrgUUID:   return "Organization UUID not set. Open Settings to add it."
        case .invalidResponse:  return "Unexpected response from Claude."
        case .httpStatus(let c): return "Claude returned HTTP \(c)."
        case .decoding(let e):  return "Couldn't parse response: \(e.localizedDescription)"
        }
    }
}

final class ClaudeUsageClient: UsageFetching {
    private let sessionStore: SessionStore

    /// Key for the org UUID stored in UserDefaults. The user enters it in Settings.
    static let orgUUIDDefaultsKey = "claudeusage.orgUUID"

    private var orgUUID: String? {
        let value = (UserDefaults.standard.string(forKey: Self.orgUUIDDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var endpoint: URL? {
        guard let uuid = orgUUID else { return nil }
        return URL(string: "https://claude.ai/api/organizations/\(uuid)/usage")
    }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func fetchUsage() async throws -> UsageData {
        guard let sessionKey = sessionStore.sessionKey, !sessionKey.isEmpty else {
            throw UsageError.notAuthenticated
        }
        guard let endpoint = endpoint else {
            throw UsageError.missingOrgUUID
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UsageError.invalidResponse }

        switch http.statusCode {
        case 200...299: break
        case 401, 403:  throw UsageError.notAuthenticated
        default:        throw UsageError.httpStatus(http.statusCode)
        }

        do {
            let raw = try JSONDecoder.claudeDecoder.decode(RawUsageResponse.self, from: data)
            return raw.toUsageData()
        } catch {
            throw UsageError.decoding(error)
        }
    }
}

// Matches claude.ai's /api/organizations/{org}/usage shape (May 2026).
// Utilization is an integer 0..100 — we convert to 0.0..1.0 in toUsageData().
private struct RawUsageResponse: Decodable {
    struct RawWindow: Decodable {
        let utilization: Double
        let resetsAt: Date?
        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    let fiveHour: RawWindow
    let sevenDay: RawWindow
    let sevenDayOpus: RawWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
    }

    func toUsageData() -> UsageData {
        func toWindow(_ raw: RawWindow) -> UsageWindow {
            UsageWindow(
                utilization: raw.utilization / 100.0,
                resetsAt: raw.resetsAt ?? Date().addingTimeInterval(3600)
            )
        }
        return UsageData(
            session: toWindow(fiveHour),
            week: toWindow(sevenDay),
            opus: sevenDayOpus.map(toWindow),
            lastUpdated: Date()
        )
    }
}

private extension JSONDecoder {
    static let claudeDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)

            let withFrac = ISO8601DateFormatter()
            withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFrac.date(from: str) { return date }

            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: str) { return date }

            if let dot = str.firstIndex(of: ".") {
                let after = str.index(after: dot)
                var end = after
                while end < str.endIndex, str[end].isNumber {
                    end = str.index(after: end)
                }
                let digits = str[after..<end]
                if digits.count > 3 {
                    let trimmed = str.replacingCharacters(in: after..<end, with: String(digits.prefix(3)))
                    if let date = withFrac.date(from: trimmed) { return date }
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(str)"
            )
        }
        return d
    }()
}

// Mock client used during development. To enable: ClaudeUsageApp.swift → useMock: true
final class MockUsageClient: UsageFetching {
    private var tick = 0
    func fetchUsage() async throws -> UsageData {
        try await Task.sleep(nanoseconds: 300_000_000)
        tick += 1
        let session = min(0.05 + Double(tick) * 0.07, 0.98)
        return UsageData(
            session: UsageWindow(utilization: session, resetsAt: Date().addingTimeInterval(2 * 3600 + 17 * 60)),
            week:    UsageWindow(utilization: 0.41,    resetsAt: Date().addingTimeInterval(4 * 24 * 3600)),
            opus:    UsageWindow(utilization: 0.78,    resetsAt: Date().addingTimeInterval(4 * 24 * 3600)),
            lastUpdated: Date()
        )
    }
}
