import Foundation


enum APIError: LocalizedError{
    case invalidURL, invalidRequest, decoding(Error), networkError(Error), fileNotFound(String)

    var errorDescription: String?{
        switch self {
        case .invalidURL:
            return "The Url is invalid"
        case .invalidRequest:
            return "Bad Request"
        case .decoding(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .fileNotFound(let name):
            return "Could not find \(name) in the app bundle"
        }
    }
}
