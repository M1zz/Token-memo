//
//  ComboExecutionServiceTests.swift
//  ClipKeyboardTests
//
//  Combo 실행 서비스 테스트 (통합 모델: 콤보 = stackValues 단계를 가진 Memo)
//

import XCTest
@testable import ClipKeyboard

final class StackExecutionServiceTests: XCTestCase {

    var sut: StackExecutionService!
    var memoStore: MemoStore!
    var testMemos: [Memo]!

    override func setUp() {
        super.setUp()
        sut = StackExecutionService.shared
        memoStore = MemoStore.shared

        // 싱글톤 격리: 이전 테스트가 비-idle 상태로 끝났으면 startCombo가 막힌다.
        sut.stopStack()

        testMemos = [
            Memo(title: "메모1", value: "값1"),
            Memo(title: "메모2", value: "값2"),
            Memo(title: "메모3", value: "값3")
        ]
        try? memoStore.save(memos: testMemos, type: .memo)
    }

    override func tearDown() {
        sut.stopStack()
        try? memoStore.save(memos: [], type: .memo)
        testMemos = nil
        memoStore = nil
        sut = nil
        super.tearDown()
    }

    /// testMemos 값으로 콤보 단계(stackValues)를 구성해 콤보 Memo 생성.
    private func makeStack(_ indexes: [Int], interval: TimeInterval = 0.1) -> Memo {
        let values = indexes.map { testMemos[$0].value }
        return Memo(id: UUID(), title: "테스트", value: values.first ?? "",
                    stackValues: values, stackInterval: interval)
    }

    // MARK: - State Tests

    func testInitialState() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.currentItemIndex, 0)
    }

    func testStartStack_ChangesStateToRunning() {
        sut.startStack(makeStack([0, 1], interval: 0.1))
        if case .running = sut.state {} else { XCTFail("State should be running") }
    }

    func testStopStack_ResetsToIdle() {
        sut.startStack(makeStack([0, 1], interval: 0.1))
        sut.stopStack()
        XCTAssertEqual(sut.state, .idle)
        XCTAssertEqual(sut.currentItemIndex, 0)
    }

    func testPauseStack() {
        sut.startStack(makeStack([0, 1], interval: 5.0))
        sut.pauseStack()
        if case .paused = sut.state {} else { XCTFail("State should be paused") }
    }

    func testResumeStack() {
        sut.startStack(makeStack([0, 1], interval: 5.0))
        sut.pauseStack()
        sut.resumeStack()
        if case .running = sut.state {} else { XCTFail("State should be running after resume") }
    }

    func testSingleItemStack_CompletesImmediately() {
        sut.startStack(makeStack([0], interval: 0.1))
        // 단일 항목은 startCombo 내에서 즉시 completeExecution → .completed
        XCTAssertEqual(sut.state, .completed)
    }

    func testProgress() {
        sut.startStack(makeStack([0, 1, 2], interval: 5.0))
        XCTAssertEqual(sut.progress, 0.0, accuracy: 0.001)
    }

    func testConcurrentStart_IsIgnored() {
        let first = makeStack([0, 1], interval: 5.0)
        sut.startStack(first)
        let firstState = sut.state
        sut.startStack(makeStack([2], interval: 5.0)) // 실행 중 → 무시
        XCTAssertEqual(sut.state, firstState)
    }

    func testStackWithEmptyStep_StillRuns() {
        // 중간에 빈 단계가 섞여도 실행은 진행된다(크래시 없이).
        let stack = Memo(id: UUID(), title: "테스트", value: "값1",
                         stackValues: ["값1", "", "값3"], stackInterval: 0.1)
        sut.startStack(stack)
        XCTAssertNotEqual(sut.state, .idle)
    }

    func testEmptyStack_DoesNotStart() {
        sut.startStack(Memo(title: "빈 콤보", value: ""))  // stackValues 없음
        XCTAssertEqual(sut.state, .idle)
    }

    func testCompletion_IncrementsClipCount() {
        var stack = makeStack([0], interval: 0.1)
        stack.title = "사용 횟수"
        // 콤보 메모도 저장돼 있어야 incrementClipCount가 찾는다.
        var all = (try? memoStore.load(type: .memo)) ?? []
        all.append(stack)
        try? memoStore.save(memos: all, type: .memo)

        sut.startStack(stack)   // 단일 항목 → 즉시 완료 → incrementClipCount

        let exp = expectation(description: "clipCount incremented")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let reloaded = (try? self.memoStore.load(type: .memo)) ?? []
            let saved = reloaded.first(where: { $0.id == stack.id })
            XCTAssertEqual(saved?.clipCount, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }
}
