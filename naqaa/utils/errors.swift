import Foundation

enum APIError: LocalizedError {
    case invalidURL, invalidRequest, decoding(Error), networkError(Error), fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "The URL is invalid")
        case .invalidRequest:
            return String(localized: "Bad Request")
        case .decoding(let error):
            return String(localized: "Failed to decode response: \(error.localizedDescription)")
        case .networkError(let error):
            return String(localized: "Network Error: \(error.localizedDescription)")
        case .fileNotFound(let name):
            return String(localized: "Could not find \(name) in the app bundle")
        }
    }
}
