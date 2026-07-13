import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case requestFailed(status: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid API URL"
        case .unauthorized:
            "Session expired. Please log in again."
        case .requestFailed(_, let message):
            message
        case .emptyResponse:
            "The server returned an empty response."
        }
    }
}

struct MoneyManagerAPI {
    let baseURL: URL
    var session: URLSession = .shared

    init(baseURL: URL = AppConfiguration.apiBaseURL) {
        self.baseURL = baseURL
    }

    func healthCheck() async throws {
        let request = try makeRequest(path: "/health")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    func getCurrentUser(token: String) async throws -> User {
        try await request(path: "/me", token: token)
    }

    func deleteAccount(token: String) async throws {
        let _: EmptyResponse = try await request(path: "/me", method: "DELETE", token: token)
    }

    func register(email: String, password: String) async throws -> AuthResult {
        try await auth(path: "/auth/register", email: email, password: password)
    }

    func login(email: String, password: String) async throws -> AuthResult {
        try await auth(path: "/auth/login", email: email, password: password)
    }

    func getSummary(token: String, month: String) async throws -> TransactionSummary {
        try await request(path: "/transactions/summary", token: token, queryItems: [
            URLQueryItem(name: "month", value: month)
        ])
    }

    func getTransactions(token: String, month: String, type: String? = nil, category: String? = nil) async throws -> [Transaction] {
        var queryItems = [URLQueryItem(name: "month", value: month)]
        if let type, !type.isEmpty {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        if let category, !category.isEmpty {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        return try await request(path: "/transactions", token: token, queryItems: queryItems)
    }

    func getCategories(token: String, type: String) async throws -> [Category] {
        try await request(path: "/categories", token: token, queryItems: [
            URLQueryItem(name: "type", value: type)
        ])
    }

    func createCategory(token: String, type: String, name: String) async throws -> Category {
        try await request(
            path: "/categories",
            method: "POST",
            token: token,
            body: CategoryRequest(type: type, name: name)
        )
    }

    func deleteCategory(token: String, id: Int) async throws {
        let _: EmptyResponse = try await request(path: "/categories/\(id)", method: "DELETE", token: token)
    }

    func createTransaction(token: String, transaction: TransactionRequest) async throws -> Transaction {
        try await request(path: "/transactions", method: "POST", token: token, body: transaction)
    }

    func updateTransaction(token: String, id: Int, transaction: TransactionRequest) async throws -> Transaction {
        try await request(path: "/transactions/\(id)", method: "PUT", token: token, body: transaction)
    }

    func deleteTransaction(token: String, id: Int) async throws {
        let _: EmptyResponse = try await request(path: "/transactions/\(id)", method: "DELETE", token: token)
    }

    func exportTransactionsCSV(token: String, from: String, to: String) async throws -> String {
        let request = try makeRequest(
            path: "/transactions/export",
            method: "GET",
            token: token,
            queryItems: [
                URLQueryItem(name: "from", value: from),
                URLQueryItem(name: "to", value: to)
            ]
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func importRevolutCSV(token: String, data: Data) async throws -> ImportResult {
        var request = try makeRequest(path: "/transactions/import/revolut", method: "POST", token: token)
        request.setValue("text/csv", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        request.timeoutInterval = 30
        let (responseData, response) = try await session.data(for: request)
        try validate(response: response, data: responseData)
        return try JSONDecoder().decode(ImportResult.self, from: responseData)
    }

    func makeRequest(
        path: String,
        method: String = "GET",
        token: String? = nil,
        queryItems: [URLQueryItem] = []
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func auth(path: String, email: String, password: String) async throws -> AuthResult {
        try await request(path: path, method: "POST", body: ["email": email, "password": password])
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        token: String? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let request = try makeRequest(path: path, method: method, token: token, queryItems: queryItems)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        guard !data.isEmpty else {
            throw APIError.emptyResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        token: String? = nil,
        body: Body
    ) async throws -> T {
        var request = try makeRequest(path: path, method: method, token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw APIError.unauthorized
            }
            let message = serverErrorMessage(from: data) ?? "Request failed with HTTP \(http.statusCode)"
            throw APIError.requestFailed(status: http.statusCode, message: message)
        }
    }

    private func serverErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["error"] as? String,
            !message.isEmpty
        else {
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return message
    }
}

private struct EmptyResponse: Decodable {}
