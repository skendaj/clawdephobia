import Foundation

/// Sends push notifications to phone via ntfy.sh (free, open-source push service).
/// Users install the ntfy app on their phone (iOS or Android) and subscribe to a topic.
/// This service POSTs to that topic whenever a notification fires.
final class PushNotificationService {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    /// Send a push notification via ntfy.sh.
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body text
    ///   - topic: The ntfy topic the user subscribed to on their phone
    ///   - serverURL: The ntfy server URL (default: https://ntfy.sh)
    ///   - priority: ntfy priority (1=min, 3=default, 5=urgent)
    func send(title: String, body: String, topic: String, serverURL: String = "https://ntfy.sh", priority: Int = 3) {
        guard !topic.isEmpty else { return }

        let baseURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Validate topic: only allow alphanumeric, hyphens, underscores
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitizedTopic = topic.unicodeScalars.filter { allowedChars.contains($0) }.map { Character($0) }
        let safeTopic = String(sanitizedTopic)
        guard !safeTopic.isEmpty else { return }

        guard let url = URL(string: "\(baseURL)/\(safeTopic)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(String(min(max(priority, 1), 5)), forHTTPHeaderField: "Priority")
        request.setValue("claudephobia", forHTTPHeaderField: "Tags")
        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { _, response, error in
            if let error = error {
                print("[ntfy] Failed to send: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                print("[ntfy] Server returned \(http.statusCode)")
            }
        }.resume()
    }

    /// Send a test notification to verify the topic works.
    func sendTest(topic: String, serverURL: String = "https://ntfy.sh") {
        send(
            title: "Claudephobia — Test",
            body: "Phone notifications are working! 🎉",
            topic: topic,
            serverURL: serverURL,
            priority: 3
        )
    }
}
