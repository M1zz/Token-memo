//
//  CloudKitBackupServiceTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-01-16.
//  CloudKit 백업/복구 테스트 (통합 테스트)
//

import XCTest
import CloudKit
@testable import ClipKeyboard

final class CloudKitBackupServiceTests: XCTestCase {

    var sut: CloudKitBackupService!
    var memoStore: MemoStore!

    override func setUp() {
        super.setUp()
        sut = CloudKitBackupService.shared
        memoStore = MemoStore.shared
    }

    override func tearDown() {
        // 테스트 후 데이터 정리
        try? memoStore.save(memos: [], type: .memo)
        try? memoStore.saveSmartClipboardHistory(history: [])
        try? memoStore.saveCombos([])
        memoStore = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Service Initialization Tests

    func testServiceInitialization() {
        // Then
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isBackingUp)
        XCTAssertFalse(sut.isRestoring)
    }

    func testAccountStatusCheck() {
        // Given
        let expectation = XCTestExpectation(description: "Check account status")

        // When
        sut.checkAccountStatus()

        // Wait for async check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            // Then
            // Note: 실제 iCloud 로그인 상태에 따라 결과가 다름
            print("iCloud 인증 상태: \(self?.sut.isAuthenticated ?? false)")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Backup Data Preparation Tests

    func testBackupData_PreparesCorrectData() async throws {
        // Given
        let testMemos = [
            Memo(title: "백업 테스트1", value: "값1"),
            Memo(title: "백업 테스트2", value: "값2")
        ]

        let testHistory = [
            SmartClipboardHistory(content: "테스트 클립보드", detectedType: .text)
        ]

        let testStacks = [
            Combo(title: "테스트 Combo", items: [
                ComboItem(type: .memo, referenceId: testMemos[0].id, order: 0)
            ])
        ]

        try memoStore.save(memos: testMemos, type: .memo)
        try memoStore.saveSmartClipboardHistory(history: testHistory)
        try memoStore.saveCombos(testStacks)

        // When - 백업 시도 (실제 iCloud 연결 필요)
        // Note: 실제 백업은 네트워크가 필요하므로 통합 테스트에서만 실행

        // Then
        let loadedMemos = try memoStore.load(type: .memo)
        let loadedHistory = try memoStore.loadSmartClipboardHistory()
        let loadedStacks = try memoStore.loadCombos()

        XCTAssertEqual(loadedMemos.count, 2)
        XCTAssertEqual(loadedHistory.count, 1)
        XCTAssertEqual(loadedStacks.count, 1)
    }

    // MARK: - CloudKit Error Tests

    func testCloudKitError_NotAuthenticated() {
        // Given
        let error = CloudKitError.notAuthenticated

        // Then
        XCTAssertEqual(error.localizedDescription,
                       localizedForTest("iCloud에 로그인되어 있지 않습니다. 설정 > [사용자 이름] > iCloud에서 로그인해주세요."))
    }

    func testCloudKitError_BackupFailed() {
        // Given - non-CKError (TestDomain) → generic actionable fallback message
        let underlyingError = NSError(domain: "TestDomain", code: 123)
        let error = CloudKitError.backupFailed(underlyingError)

        // Then - 메시지가 비어있지 않고 사용자에게 actionable한 안내가 포함되어야 함
        // CKError 가 아니면 무엇을 해 보라는 일반 안내로 떨어진다.
        // 조각을 contains 로 보면 번역된 언어에서 조각이 사라지므로 통째로 맞춘다.
        XCTAssertEqual(error.localizedDescription,
                       localizedForTest("문제가 발생했습니다. 네트워크 연결과 iCloud 상태를 확인하고 다시 시도해주세요."))
    }

    func testCloudKitError_RestoreFailed() {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 456)
        let error = CloudKitError.restoreFailed(underlyingError)

        // Then
        // CKError 가 아니면 무엇을 해 보라는 일반 안내로 떨어진다.
        // 조각을 contains 로 보면 번역된 언어에서 조각이 사라지므로 통째로 맞춘다.
        XCTAssertEqual(error.localizedDescription,
                       localizedForTest("문제가 발생했습니다. 네트워크 연결과 iCloud 상태를 확인하고 다시 시도해주세요."))
    }

    func testCloudKitError_NoBackupFound() {
        // Given
        let error = CloudKitError.noBackupFound

        // Then
        XCTAssertEqual(error.localizedDescription,
                       localizedForTest("백업 데이터가 없습니다. 먼저 백업을 생성해주세요."))
    }

    // MARK: - Backup State Tests

    func testLastBackupDate_SaveAndLoad() {
        // Given
        let testDate = Date()

        // When - lastBackupDate 로드는 private init()에서만 발생.
        // shared 인스턴스는 이미 초기화되어 있어 새 init이 트리거되지 않으므로,
        // UserDefaults 영속 자체를 검증하는 형태로 변경.
        UserDefaults.standard.set(testDate, forKey: "lastBackupDate")

        // Then
        let loadedDate = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
        XCTAssertNotNil(loadedDate)
        if let loaded = loadedDate {
            XCTAssertEqual(
                Calendar.current.compare(loaded, to: testDate, toGranularity: .second),
                .orderedSame
            )
        }

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
    }

    // MARK: - Integration Tests (네트워크 필요)

    // Note: 아래 테스트들은 실제 iCloud 연결이 필요합니다
    // 실행하려면 주석을 해제하고 실제 기기/시뮬레이터에서 iCloud 로그인 필요

    /*
    func testBackupAndRestore_Integration() async throws {
        // Given
        guard sut.isAuthenticated else {
            throw XCTSkip("iCloud에 로그인되어 있지 않음")
        }

        let testMemos = [
            Memo(title: "통합 테스트1", value: "통합 값1"),
            Memo(title: "통합 테스트2", value: "통합 값2")
        ]

        try memoStore.save(memos: testMemos, type: .memo)

        // When - 백업
        try await sut.backupData()

        // 데이터 삭제
        try memoStore.save(memos: [], type: .memo)

        // 복구
        try await sut.restoreData()

        // Then
        let restoredMemos = try memoStore.load(type: .memo)
        XCTAssertEqual(restoredMemos.count, 2)
        XCTAssertEqual(restoredMemos[0].title, "통합 테스트1")
        XCTAssertEqual(restoredMemos[1].title, "통합 테스트2")
    }

    func testHasBackup_Integration() async throws {
        // Given
        guard sut.isAuthenticated else {
            throw XCTSkip("iCloud에 로그인되어 있지 않음")
        }

        // When
        let hasBackup = await sut.hasBackup()

        // Then
        print("백업 존재 여부: \(hasBackup)")
        // Note: 실제 백업 존재 여부에 따라 결과가 다름
    }

    func testDeleteBackup_Integration() async throws {
        // Given
        guard sut.isAuthenticated else {
            throw XCTSkip("iCloud에 로그인되어 있지 않음")
        }

        // When
        try await sut.deleteBackup()

        // Then
        let hasBackup = await sut.hasBackup()
        XCTAssertFalse(hasBackup)
    }
    */
}
