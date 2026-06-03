import Foundation

/// Account-level identity returned by `/api/organizations`.
struct OrgInfo: Equatable {
    let uuid: String
    let name: String?
}

/// Fetches Clawd usage data via direct API calls.
/// Uses /api/organizations to get the org ID, then /api/organizations/{id}/usage
/// for utilization data and /api/organizations/{id}/rate_limits for tier info.
final class UsageScraper {
    private let sessionKey: String
    private var cachedOrgInfo: OrgInfo?

    init(sessionKey: String) {
        self.sessionKey = sessionKey
    }

    func updateSessionKey(_ key: String) -> UsageScraper {
        return UsageScraper(sessionKey: key)
    }

    /// Fetches the active org's UUID and display name. Cached for the scraper's lifetime.
    /// Used by AccountStore to add or migrate accounts.
    func fetchOrgInfo() async throws -> OrgInfo {
        if let cached = cachedOrgInfo { return cached }
        let (data, status) = try await apiGet(path: "/api/organizations")
        if status == 401 || status == 403 { throw ClawdAPIError.unauthorized }
        guard let orgs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstOrg = orgs.first,
              let uuid = firstOrg["uuid"] as? String else {
            throw ClawdAPIError.invalidResponse("Could not parse organization ID")
        }
        let name = (firstOrg["name"] as? String).flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        let info = OrgInfo(uuid: uuid, name: name)
        cachedOrgInfo = info
        return info
    }

    // MARK: - Public

    func scrape() async throws -> ClawdUsageData {
        let orgId = try await fetchOrgInfo().uuid

        // Fetch usage and rate limits in parallel
        async let usageResult = fetchUsage(orgId: orgId)
        async let tierResult = fetchTier(orgId: orgId)
        async let prepaidResult = fetchPrepaidCredits(orgId: orgId)
        async let spendLimitResult = fetchOverageSpendLimit(orgId: orgId)

        let usage = try await usageResult
        let tier = try? await tierResult
        let prepaid = try? await prepaidResult
        let spendLimit = try? await spendLimitResult

return ClawdUsageData(
            fiveHour: usage.fiveHour,
            sevenDay: usage.sevenDay,
            sevenDayOpus: usage.sevenDayOpus,
            sevenDaySonnet: usage.sevenDaySonnet,
            sevenDayOAuthApps: usage.sevenDayOAuthApps,
            sevenDayCowork: usage.sevenDayCowork,
            extraUsage: usage.extraUsage,
            extraUsageDetail: usage.extraUsageDetail,
            rateLimitTier: tier,
            sevenDayOmelette: usage.sevenDayOmelette,
            sevenDayOmelettePromotional: usage.sevenDayOmelettePromotional,
            iguanaNecktie: usage.iguanaNecktie,
            prepaidCredits: prepaid ?? nil,
            overageSpendLimit: spendLimit ?? nil
        )
    }

    /// Retries scrape() on transient failures with exponential backoff.
    func scrapeWithRetry(maxAttempts: Int = 3) async throws -> ClawdUsageData {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await scrape()
            } catch let error as ClawdAPIError where error.isRetryable {
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

    private func fetchUsage(orgId: String) async throws -> ClawdUsageData {
        let (data, status) = try await apiGet(path: "/api/organizations/\(orgId)/usage")

        if status == 401 || status == 403 {
            throw ClawdAPIError.unauthorized
        }
        if status == 429 {
            throw ClawdAPIError.rateLimited
        }
        if status >= 500 {
            throw ClawdAPIError.serverError(status)
        }

        guard status == 200,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClawdAPIError.invalidResponse("Usage endpoint returned status \(status)")
        }
        
        return ClawdUsageData(
            fiveHour: parseLimit(dict["five_hour"], required: true),
            sevenDay: parseLimit(dict["seven_day"], required: true),
            sevenDayOpus: parseLimit(dict["seven_day_opus"]),
            sevenDaySonnet: parseLimit(dict["seven_day_sonnet"]),
            sevenDayOAuthApps: parseLimit(dict["seven_day_oauth_apps"]),
            sevenDayCowork: parseLimit(dict["seven_day_cowork"]),
            extraUsage: parseLimit(dict["extra_usage"]),
            extraUsageDetail: parseExtraUsage(dict["extra_usage"]),
            rateLimitTier: nil,
            sevenDayOmelette: parseLimit(dict["seven_day_omelette"]),
            sevenDayOmelettePromotional: parseLimit(dict["omelette_promotional"]),
            iguanaNecktie: parseLimit(dict["iguana_necktie"]),
            prepaidCredits: nil,
            overageSpendLimit: nil
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

    /// Prepaid balance. 404/4xx is non-fatal — accounts without prepaid credits
    /// simply don't have this endpoint populated.
    private func fetchPrepaidCredits(orgId: String) async throws -> PrepaidCreditsInfo? {
        let (data, status) = try await apiGet(path: "/api/organizations/\(orgId)/prepaid/credits")
        guard status == 200,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let amount = dict["amount"] as? Double else {
            return nil
        }
        let currency = (dict["currency"] as? String) ?? "USD"
        return PrepaidCreditsInfo(amountCents: amount, currency: currency)
    }

    /// Overage spend-limit object. 404/4xx is non-fatal — accounts without
    /// overage billing return nothing useful here.
    private func fetchOverageSpendLimit(orgId: String) async throws -> OverageSpendLimitInfo? {
        let (data, status) = try await apiGet(path: "/api/organizations/\(orgId)/overage_spend_limit")
        guard status == 200,
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let isEnabled = dict["is_enabled"] as? Bool ?? false
        let monthly = dict["monthly_credit_limit"] as? Double
        let used = dict["used_credits"] as? Double
        let currency = (dict["currency"] as? String) ?? "USD"
        let disabledReason = dict["disabled_reason"] as? String
        let outOfCredits = dict["out_of_credits"] as? Bool ?? false
        let period = dict["period"] as? String
        // Skip when nothing meaningful is reported
        if !isEnabled && monthly == nil && used == nil && disabledReason == nil {
            return nil
        }
        return OverageSpendLimitInfo(
            isEnabled: isEnabled,
            monthlyLimitCents: monthly,
            usedCreditsCents: used,
            currency: currency,
            disabledReason: disabledReason,
            outOfCredits: outOfCredits,
            period: period
        )
    }

    // MARK: - Parse

    // required=true: return a zero RateLimitInfo even when utilization=0 and
    // resets_at=null (team org Enterprise accounts). required=false (default):
    // suppress those rows to avoid empty UI clutter (e.g. omelette_promotional).
    private func parseLimit(_ value: Any?, required: Bool = false) -> RateLimitInfo? {
        guard let dict = value as? [String: Any] else { return nil }

        guard let utilization = dict["utilization"] as? Double else { return nil }

        let percent = utilization >= 1 ? utilization / 100.0 : utilization

        let rawReset = dict["resets_at"] as? String
        guard let str = rawReset else {
            if percent <= 0 && !required { return nil }
            return makeRateLimitInfo(percent: percent, resetsAt: .distantFuture)
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let resetsAt = iso.date(from: str) {
            return makeRateLimitInfo(percent: percent, resetsAt: resetsAt)
        }
        iso.formatOptions = [.withInternetDateTime]
        guard let resetsAt = iso.date(from: str) else { return nil }
        return makeRateLimitInfo(percent: percent, resetsAt: resetsAt)
    }

    /// Pay-as-you-go credit accounting. Returned even when `utilization` is null so
    /// enterprise/credit-based plans can be displayed in the popover.
    private func parseExtraUsage(_ value: Any?) -> ExtraUsageInfo? {
        guard let dict = value as? [String: Any] else { return nil }
        let isEnabled = dict["is_enabled"] as? Bool ?? false
        let credits = dict["used_credits"] as? Double
        let monthlyLimit = dict["monthly_limit"] as? Double
        let currency = dict["currency"] as? String
        // Skip when nothing meaningful is reported
        if !isEnabled && credits == nil && monthlyLimit == nil { return nil }
        return ExtraUsageInfo(
            isEnabled: isEnabled,
            usedCredits: credits,
            monthlyLimit: monthlyLimit,
            currency: currency
        )
    }
    
    private func makeRateLimitInfo(percent: Double, resetsAt: Date) -> RateLimitInfo {
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
            throw ClawdAPIError.networkError(error)
        }
    }
}