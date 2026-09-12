//
//  DemoDataServiceTests.swift
//  ClipKeyboardTests
//
//  데모 데이터 토글(4.4.4)의 백업/복원 무결성 테스트.
//
//  시나리오: 데모를 켜면 사용자의 단축어/클립보드가 샘플로 통째로 대체된다.
//  끌 때 원본이 정확히 돌아오지 않으면 곧바로 데이터 손실 사고다.
//  이 스위트는 "켜고 끄면 원래대로"를 각 경로(정상·중복 호출·백업 없음)에서 못 박는다.
//

import XCTest
@testable import ClipKeyboard

final class DemoDataServiceTests: XCTestCase {

    private var sut: DemoDataService!
    private var store: MemoStore!

    private var groupDefaults: UserDefaults? {
        AppGroup.defaults
    }
    private var backupURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        )?.appendingPathComponent("demo.backup.data")
    }

    override func setUp() {
        super.setUp()
        sut = DemoDataService.shared
        store = MemoStore.shared
        resetState()
    }

    override func tearDown() {
        resetState()
        sut = nil
        store = nil
        super.tearDown()
    }

    /// 데모 플래그·백업 파일·저장소를 초기 상태로 되돌린다.
    private func resetState() {
        groupDefaults?.removeObject(forKey: DefaultsKey.demoDataActive)
        if let url = backupURL { try? FileManager.default.removeItem(at: url) }
        try? store.save(memos: [], type: .memo, recordHistory: false)
        try? store.saveSmartClipboardHistory(history: [])
    }

    /// 테스트용 "내 원본 데이터".
    private func seedOriginal() -> (memos: [Memo], clips: [SmartClipboardHistory]) {
        let memos = [
            Memo(title: "내 계좌", value: "1002-123-456789"),
            Memo(title: "내 메일", value: "me@example.com", isFavorite: true)
        ]
        let clips = [
            SmartClipboardHistory(content: "hello@example.com", detectedType: .email, confidence: 0.9)
        ]
        try? store.save(memos: memos, type: .memo, recordHistory: false)
        try? store.saveSmartClipboardHistory(history: clips)
        return (memos, clips)
    }

    // MARK: - 핵심 계약: 켜고 끄면 원래대로

    func testEnableThenDisableRestoresOriginalData() {
        let original = seedOriginal()

        XCTAssertTrue(sut.enable(), "데모 적용은 성공해야 한다")
        XCTAssertTrue(sut.isActive, "적용 후 isActive가 true여야 한다")

        // 데모 데이터로 대체됐는지
        let demoMemos = (try? store.load(type: .memo)) ?? []
        XCTAssertEqual(demoMemos.count, 6, "데모 단축어는 6개")
        XCTAssertFalse(demoMemos.contains { $0.title == original.memos[0].title },
                       "원본 단축어가 화면에 남아 있으면 안 된다")

        XCTAssertTrue(sut.disable(), "복원은 성공해야 한다")
        XCTAssertFalse(sut.isActive, "해제 후 isActive가 false여야 한다")

        // 원본이 그대로 돌아왔는지 (제목·값·즐겨찾기까지)
        let restored = (try? store.load(type: .memo)) ?? []
        XCTAssertEqual(restored.count, original.memos.count)
        XCTAssertEqual(Set(restored.map(\.title)), Set(original.memos.map(\.title)))
        XCTAssertEqual(Set(restored.map(\.value)), Set(original.memos.map(\.value)))
        XCTAssertEqual(restored.first { $0.title == "내 메일" }?.isFavorite, true,
                       "즐겨찾기 같은 부가 필드도 보존돼야 한다")

        let restoredClips = (try? store.loadSmartClipboardHistory()) ?? []
        XCTAssertEqual(restoredClips.map(\.content), original.clips.map(\.content))
    }

    /// 복원이 끝나면 백업 파일은 남지 않아야 한다(다음 켜기가 데모를 백업하는 사고 방지).
    func testBackupFileIsRemovedAfterRestore() {
        _ = seedOriginal()
        XCTAssertTrue(sut.enable())
        if let url = backupURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "데모 적용 중에는 백업이 존재해야 한다")
        }
        XCTAssertTrue(sut.disable())
        if let url = backupURL {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                           "복원 후 백업 파일은 지워져야 한다")
        }
    }

    /// enable을 두 번 호출해도 백업이 "데모 데이터"로 덮어써지면 안 된다.
    /// (덮어써지면 disable 시 원본 대신 데모가 복원되는 데이터 손실)
    func testDoubleEnableKeepsOriginalBackup() {
        let original = seedOriginal()

        XCTAssertTrue(sut.enable())
        XCTAssertTrue(sut.enable(), "이미 켜져 있으면 no-op으로 성공 처리")

        XCTAssertTrue(sut.disable())
        let restored = (try? store.load(type: .memo)) ?? []
        XCTAssertEqual(Set(restored.map(\.title)), Set(original.memos.map(\.title)),
                       "중복 호출 후에도 원본이 복원돼야 한다")
    }

    /// 데모가 꺼진 상태에서 disable을 불러도 데이터를 건드리면 안 된다.
    func testDisableWhenInactiveIsNoOp() {
        let original = seedOriginal()
        XCTAssertFalse(sut.isActive)

        XCTAssertTrue(sut.disable(), "꺼진 상태의 disable은 성공(no-op)")

        let memos = (try? store.load(type: .memo)) ?? []
        XCTAssertEqual(Set(memos.map(\.title)), Set(original.memos.map(\.title)),
                       "데이터가 그대로여야 한다")
    }

    /// 백업 파일이 사라진 채로 disable되면 원본을 되살릴 수 없다.
    /// 이때 데모 데이터를 남겨두면 사용자가 남의 데이터를 자기 것으로 착각하므로 비운다.
    func testDisableWithoutBackupClearsDemoData() {
        _ = seedOriginal()
        XCTAssertTrue(sut.enable())

        if let url = backupURL { try? FileManager.default.removeItem(at: url) }

        XCTAssertFalse(sut.disable(), "복원할 백업이 없으면 false를 반환한다")
        XCTAssertFalse(sut.isActive, "그래도 데모 상태는 해제돼야 한다")
        XCTAssertEqual((try? store.load(type: .memo))?.count, 0,
                       "데모 데이터가 내 데이터인 척 남으면 안 된다")
    }

    // MARK: - 데이터셋 자체 검증

    /// 무료 한도(10개)를 넘으면 데모 화면에 업셀 배너가 떠 시연이 지저분해진다.
    func testDemoMemosFitInFreeTier() {
        XCTAssertLessThanOrEqual(DemoDataService.demoMemos().count,
                                 ProFeatureManager.freeMemoLimit)
    }

    /// 앱의 기능 폭(즐겨찾기·템플릿·콤보·보안)이 한 화면에 드러나야 데모의 의미가 있다.
    func testDemoMemosCoverKeyFeatures() {
        let memos = DemoDataService.demoMemos()
        XCTAssertEqual(memos.filter(\.isFavorite).count, 2, "즐겨찾기 2개")
        XCTAssertTrue(memos.contains { $0.isTemplate }, "템플릿 포함")
        XCTAssertTrue(memos.contains { $0.isStack }, "콤보 포함")
        XCTAssertTrue(memos.contains { $0.isSecure }, "보안 단축어 포함")
        XCTAssertTrue(memos.allSatisfy { !($0.hint ?? "").isEmpty }, "모든 카드에 힌트")
    }

    /// 클립보드 데모는 자동 분류를 보여주는 게 목적이라 타입이 겹치면 안 된다.
    func testDemoClipboardHasDistinctTypes() {
        let clips = DemoDataService.demoClipboard()
        XCTAssertEqual(clips.count, 6)
        XCTAssertEqual(Set(clips.map(\.detectedType)).count, clips.count,
                       "타입이 서로 달라야 분류 능력이 드러난다")
    }
}
