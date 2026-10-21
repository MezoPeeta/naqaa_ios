import Foundation

nonisolated enum DownloadEvent: Sendable {
    case progress(key: String, fraction: Double)
    case finished(DownloadRequestInfo, byteCount: Int64)
    case failed(key: String)
    case cancelled(key: String)
}

/// Runs on the session's background queue. The finished file is moved inside the callback
/// because the system deletes it as soon as the callback returns.
nonisolated final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let files: DownloadFileStore
    private let onEvent: @Sendable (DownloadEvent) -> Void

    init(files: DownloadFileStore, onEvent: @escaping @Sendable (DownloadEvent) -> Void) {
        self.files = files
        self.onEvent = onEvent
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0,
              let info = DownloadRequestInfo(taskDescription: downloadTask.taskDescription)
        else { return }
        onEvent(.progress(key: info.key, fraction: Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let info = DownloadRequestInfo(taskDescription: downloadTask.taskDescription) else { return }
        let itemId = info.item.id

        guard let http = downloadTask.response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            onEvent(.failed(key: info.key))
            return
        }
        let size = Int64((try? location.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let expected = downloadTask.countOfBytesExpectedToReceive
        guard size > 0, expected <= 0 || size == expected else {
            onEvent(.failed(key: info.key))
            return
        }
        do {
            try files.move(from: location, surahId: info.surahId, itemId: itemId)
            onEvent(.finished(info, byteCount: size))
        } catch {
            onEvent(.failed(key: info.key))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let info = DownloadRequestInfo(taskDescription: task.taskDescription) else { return }
        if (error as? URLError)?.code == .cancelled {
            onEvent(.cancelled(key: info.key))
        } else {
            onEvent(.failed(key: info.key))
        }
    }
}
