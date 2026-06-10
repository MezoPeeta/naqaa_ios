
import Foundation

enum RevelationPlace: String, Codable, CaseIterable {
    case meccan, medinan
}

extension RevelationPlace{
    var label: LocalizedStringResource{
        switch self {
        case .meccan: LocalizedStringResource("Meccan")
        case .medinan: LocalizedStringResource("Medinan")

        }
    }
}
