import Foundation

struct AppVersionClient {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = Bundle.main.priceLensAPIBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchPolicy(currentVersion: String) async throws -> AppVersionPolicy {
        var components = URLComponents(url: baseURL.appendingPathComponent("app-version/ios"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "version", value: currentVersion)]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppVersionPolicy.self, from: data)
    }
}
