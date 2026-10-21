import Testing
@testable import ensat

@Suite(.tags(.offline))
struct DownloadRequestInfoTests {
    @Test func roundTripsThroughATaskDescription() throws {
        let info = DownloadRequestInfo(surahId: 18, item: TestFixtures.alafasy)

        let decoded = try #require(DownloadRequestInfo(taskDescription: info.taskDescription))

        #expect(decoded.surahId == 18)
        #expect(decoded.key == info.key)
        #expect(decoded.item == TestFixtures.alafasy)
    }

    @Test(.tags(.edgeCase), arguments: [nil, "not json", "{}"] as [String?])
    func anUnreadableTaskDescriptionIsRejected(description: String?) {
        #expect(DownloadRequestInfo(taskDescription: description) == nil)
    }

}
