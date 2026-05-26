import Foundation

struct BackendRatesResponse: Decodable {
    let baseCurrency: String
    let provider: String
    let effectiveDate: String
    let providerLastUpdateAt: Date?
    let providerLastUpdateUnix: Int?
    let providerNextUpdateAt: Date?
    let providerNextUpdateUnix: Int?
    let fetchedAt: Date
    let nextUpdateAt: Date
    let rates: [String: Double]
}

struct BackendRateClient {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = Bundle.main.priceLensAPIBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchLatestRates() async throws -> BackendRatesResponse {
        let url = baseURL.appendingPathComponent("rates/latest")

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackendRatesResponse.self, from: data)
    }
}

extension Bundle {
    var priceLensAPIBaseURL: URL {
        let value = object(forInfoDictionaryKey: "PRICE_LENS_API_BASE_URL") as? String
        return URL(string: value ?? "http://127.0.0.1:8787")!
    }
}
