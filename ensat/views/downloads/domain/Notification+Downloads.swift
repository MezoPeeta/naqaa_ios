import Foundation

extension Notification.Name {
    /// Posted when a downloaded file is deleted outside the manager (it failed to play).
    /// `userInfo`: `surahId: Int`, `itemId: String`.
    static let downloadedFileRemoved = Notification.Name("ensat.downloadedFileRemoved")
}
