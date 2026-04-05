import Foundation

/// Fetches Claude usage data via direct API calls.
/// Uses /api/organizations to get the org ID, then /api/organizations/{id}/usage
/// for utilization data and /api/organizations/{id}/rate_limits for tier info.
final class UsageScraper {
    private let sessionKey: String
    private var cachedOrgId: String?

    init(sessionKey: String) {
        self.sessionKey = sessionKey
    }

    func updateSessionKey(_ key: String) -> UsageScraper {
        return UsageScraper(sessionKey: key)
    }

    // MARK: - Public

    func scrape() async throws -> ClaudeUsageData {
        let orgId: String
        if let cached = cachedOrgId {
            orgId = cached
        } else {
            orgId = try await fetchOrgId()
            cachedOrgId = orgId
        }

        // Fetch usage and rate limits in parallel
        async let usageResult = fetchUsage(orgId: orgId)
        async let tierResult = fetchTier(orgId: orgId)

        let usage = try await usageResult
        let tier = try? await tierResult

        return ClaudeUsageData(
            fiveHour: usage.fiveHour,
            sevenDay: usage.sevenDay,
            sevenDayOpus: usage.sevenDayOpus,
            sevenDaySonnet: usage.sevenDaySonnet,
            sevenDayOAuthApps: usage.sevenDayOAuthApps,
            sevenDayCowork: usage.sevenDayCowork,
            extraUsage: usage.extraUsage,
            rateLimitTier: tier
        )
    }

    /// Retries scrape() on transient failures with exponential backoff.
    func scrapeWithRetry(maxAttempts: Int = 3) async throws -> ClaudeUsageData {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await scrape()
            } catch let error as ClaudeAPIError where error.isRetryable {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = UInt64(pow(2.0, Double(attempt + 1))) * 1_000_000_000
                    try await Task.sleep(nanoseconds: delay)
                }
            } catch {
                throw error // Non-retryable errors propagate immediately
            }
        }
        throw lastError!
    }

    // MARK: - API Calls

    private func fetchOrgId() async throws -> String {
        let (data, status) = try await apiGet(path: "/api/organizations")

        if status == 401 || status == 403 {
            throw ClaudeAPIError.unauthorized
        }

        guard let orgs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstOrg = orgs.first,
              let orgId = firstOrg["uuid"] as? String else {
            throw ClaudeAPIError.invalidResponse("Could not parse organization ID")
        }

        return orgId
    }

    private func fetchUsage(orgId: String) async throws -> ClaudeUsageData {
        let (data, status) = try await apiGet(path: "/api/organizations/\(orgId)/usage")

        if status == 401 || status == 403 {
            throw ClaudeAPIError.unauthorized
        }
        if status == 429 {
            throw ClaudeAPIError.rateLimited
        }
        if status >= 500 {
            throw ClaudeAPIError.serverError(status)
        }

        guard status == 200,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.invalidResponse("Usage endpoint returned status \(status)")
        }

        return ClaudeUsageData(
            fiveHour: parseLimit(dict["five_hour"]),
            sevenDay: parseLimit(dict["seven_day"]),
            sevenDayOpus: parseLimit(dict["seven_day_opus"]),
            sevenDaySonnet: parseLimit(dict["seven_day_sonnet"]),
            sevenDayOAuthApps: parseLimit(dict["seven_day_oauth_apps"]),
            sevenDayCowork: parseLimit(dict["seven_day_cowork"]),
            extraUsage: parseLimit(dict["extra_usage"]),
            rateLimitTier: nil
        )
    }

    private func fetchTier(orgId: String) async throws -> String? {
        let (data, status) = try await apiGet(path: "/api/organizations/\(orgId)/rate_limits")

        guard status == 200,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tier = dict["rate_limit_tier"] as? String else {
            return nil
        }

        return tier
    }

    // MARK: - Parse

    private func parseLimit(_ value: Any?) -> RateLimitInfo? {
        guard let dict = value as? [String: Any] else { return nil }

        guard let utilization = dict["utilization"] as? Double else { return nil }

        let percent = utilization > 1 ? utilization / 100.0 : utilization

        let resetsAt: Date = {
            if let str = dict["resets_at"] as? String {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: str) { return d }
                iso.formatOptions = [.withInternetDateTime]
                if let d = iso.date(from: str) { return d }
            }
            return Date().addingTimeInterval(3600)
        }()

        let clamped = percent.isFinite ? max(0, percent) : 0
        return RateLimitInfo(percentUsed: clamped, resetsAt: resetsAt)
    }

    // MARK: - HTTP

    private func apiGet(path: String) async throws -> (Data, Int) {
        let url = URL(string: "https://claude.ai\(path)")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (data, status)
        } catch {
            throw ClaudeAPIError.networkError(error)
        }
    }
}
