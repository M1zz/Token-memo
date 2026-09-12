//
//  CloudKitBackupIntegrityTests.swift
//  ClipKeyboardTests
//
//  Created by Claude Code on 2026-06-11.
//  iCloud 백업/복원 무결성 테스트 - 네트워크 없이 mock DB로 전체 경로 검증.
//
//  CloudKitBackupService에 CloudKitBackupDatabase(프로토콜)를 주입해
//  실제 CKDatabase 호출만 인메모리로 대체하고, 인코딩→CKRecord/CKAsset 구성→
//  저장→복원 디코딩→MemoStore 반영까지 출시 코드 경로를 그대로 태운다.
//

import XCTest
import CloudKit
@testable import ClipKeyboard

// MARK: - Mock Database

/// 인메모리 CloudKit DB. 레코드 저장/조회/삭제 + 에러 주입(재시도 검증용)을 지원.
final class MockCloudKitDatabase: CloudKitBackupDatabase {
    var records: [CKRecord.ID: CKRecord] = [:]
    /// save 호출 시 앞에서부터 하나씩 꺼내 던질 에러 큐. 비면 정상 저장.
    var saveErrorQueue: [Error] = []
    private(set) var saveCallCount = 0

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        guard let record = records[recordID] else {
            throw CKError(.unknownItem)
        }
        return record
    }

    @discardableResult
    func save(_ record: CKRecord) async throws -> CKRecord {
        saveCallCount += 1
        if !saveErrorQueue.isEmpty {
            throw saveErrorQueue.removeFirst()
        }
        records[record.recordID] = record
        return record
    }

    @discardableResult
    func deleteRecord(withID recordID: CKRecord.ID) async throws -> CKRecord.ID {
        records.removeValue(forKey: recordID)
        return recordID
    }
}

// MARK: - Tests

final class CloudKitBackupIntegrityTests: XCTestCase {

    var mockDB: MockCloudKitDatabase!
    var sut: CloudKitBackupService!
    var memoStore: MemoStore!

    private let backupRecordID = CKRecord.ID(recordName: "TokenMemoBackup")
    private let appGroupDefaults = AppGroup.defaults

    override func setUp() {
        super.setUp()
        mockDB = MockCloudKitDatabase()
        sut = CloudKitBackupService(
            database: mockDB,
            accountStatus: { .available }
        )
        memoStore = MemoStore.shared
        clearLocalData()
    }

    override func tearDown() {
        clearLocalData()
        UserDefaults.standard.removeObject(forKey: "lastBackupDate")
        memoStore = nil
        sut = nil
        mockDB = nil
        super.tearDown()
    }

    private func clearLocalData() {
        try? memoStore.save(memos: [], type: .memo, recordHistory: false)
        try? memoStore.saveSmartClipboardHistory(history: [])
        try? memoStore.saveCombos([])
    }

    /// 모든 의미 있는 필드를 채운 메모 - 라운드트립에서 어느 필드가 유실돼도 잡아낸다.
    private func makeRichMemo() -> Memo {
        var memo = Memo(
            title: "계좌 안내",
            value: "{이름}님 국민 123-45 입금 부탁드립니다",
            isChecked: true,
            lastEdited: Date(timeIntervalSince1970: 1_750_000_000),
            isFavorite: true,
            category: "업무",
            isSecure: true,
            templateVariables: ["이름"],
            placeholderValues: ["이름": ["유미", "주디"]],
            stackValues: ["1단계 텍스트", "2단계 텍스트"],
            stackInterval: 1.5,
            autoDetectedType: .bankAccount,
            imageFileName: "legacy.jpg",
            imageFileNames: ["a.jpg", "b.jpg"],
            contentType: .text,
            lastUsedAt: Date(timeIntervalSince1970: 1_750_100_000),
            hint: "급여일에 사용"
        )
        memo.clipCount = 7
        return memo
    }

    // MARK: - 백업: 레코드 구성

    func testBackup_RecordContainsAssetsAndMetadata() async throws {
        // Given
        try memoStore.save(memos: [makeRichMemo()], type: .memo)
        try memoStore.saveSmartClipboardHistory(history: [
            SmartClipboardHistory(content: "test@example.com", detectedType: .email, confidence: 0.95)
        ])

        // When
        try await sut.backupData()

        // Then - 메인 백업 레코드(Backup)는 1개에 3개 Asset + 메타데이터
        // (버전 스냅샷/인덱스는 별도 recordType이므로 메인 Backup만 센다)
        XCTAssertEqual(mockDB.records.values.filter { $0.recordType == "Backup" }.count, 1)
        let record = try XCTUnwrap(mockDB.records[backupRecordID])
        XCTAssertNotNil(record["memosAsset"] as? CKAsset)
        XCTAssertNotNil(record["smartClipboardAsset"] as? CKAsset)
        XCTAssertNotNil(record["combosAsset"] as? CKAsset)
        XCTAssertNotNil(record["backupDate"] as? Date)
        XCTAssertNotNil(record["version"] as? String)

        // Asset 안의 메모 데이터가 실제로 디코딩 가능하고 내용이 일치해야 함
        let asset = try XCTUnwrap(record["memosAsset"] as? CKAsset)
        let data = try Data(contentsOf: try XCTUnwrap(asset.fileURL))
        let backedUp = try JSONDecoder().decode([Memo].self, from: data)
        XCTAssertEqual(backedUp.count, 1)
        XCTAssertEqual(backedUp[0].title, "계좌 안내")

        // 성공한 백업은 lastBackupDate를 갱신
        XCTAssertNotNil(sut.lastBackupDate)
    }

    func testBackup_SecondBackupUpdatesExistingRecord() async throws {
        // Given - 1차 백업
        try memoStore.save(memos: [Memo(title: "v1", value: "값1")], type: .memo)
        try await sut.backupData()

        // When - 데이터 변경 후 2차 백업
        try memoStore.save(memos: [Memo(title: "v2", value: "값2"), Memo(title: "v2-2", value: "값")], type: .memo)
        try await sut.backupData()

        // Then - 메인 백업 레코드(Backup)는 여전히 1개(덮어쓰기), 내용은 최신
        XCTAssertEqual(mockDB.records.values.filter { $0.recordType == "Backup" }.count, 1)
        let record = try XCTUnwrap(mockDB.records[backupRecordID])
        let asset = try XCTUnwrap(record["memosAsset"] as? CKAsset)
        let data = try Data(contentsOf: try XCTUnwrap(asset.fileURL))
        let backedUp = try JSONDecoder().decode([Memo].self, from: data)
        XCTAssertEqual(backedUp.count, 2)
        XCTAssertEqual(backedUp[0].title, "v2")
    }

    // MARK: - 데이터 손실 방지 가드 (자동 백업이 기존 백업을 파괴하지 못하게)

    private func backedUpMemoCount() throws -> Int {
        let record = try XCTUnwrap(mockDB.records[backupRecordID])
        let asset = try XCTUnwrap(record["memosAsset"] as? CKAsset)
        let data = try Data(contentsOf: try XCTUnwrap(asset.fileURL))
        return try JSONDecoder().decode([Memo].self, from: data).count
    }

    /// 빈 로컬(재설치 직후)에서 자동 백업은 기존 백업을 덮어쓰면 안 된다.
    func testAutoBackup_EmptyLocal_DoesNotOverwriteExistingBackup() async throws {
        try memoStore.save(memos: [makeRichMemo()], type: .memo)
        try await sut.backupData()
        let savesAfterFirst = mockDB.saveCallCount

        clearLocalData()
        try await sut.backupData(isAutomatic: true)

        XCTAssertEqual(mockDB.saveCallCount, savesAfterFirst, "빈 로컬 자동 백업은 저장하면 안 됨")
        XCTAssertEqual(try backedUpMemoCount(), 1, "기존 백업이 빈 데이터로 덮어써지면 안 됨")
    }

    /// 시드 샘플만 있는 로컬(재설치 첫 실행)에서 자동 백업은 기존 백업을 덮어쓰면 안 된다.
    func testAutoBackup_SampleOnly_DoesNotOverwriteExistingBackup() async throws {
        try memoStore.save(memos: [makeRichMemo(), makeRichMemo()], type: .memo)
        try await sut.backupData()
        let savesAfterFirst = mockDB.saveCallCount

        let samples = [Memo(title: "샘플1", value: "s1"), Memo(title: "샘플2", value: "s2")]
        try memoStore.save(memos: samples, type: .memo)
        SampleMemoStorage.save(ids: samples.map { $0.id })
        defer { SampleMemoStorage.clear() }
        try await sut.backupData(isAutomatic: true)

        XCTAssertEqual(mockDB.saveCallCount, savesAfterFirst, "샘플뿐 자동 백업은 저장하면 안 됨")
        XCTAssertEqual(try backedUpMemoCount(), 2, "샘플뿐인 상태가 기존 백업을 덮어쓰면 안 됨")
    }

    /// 자동 백업은 급감 시 차단. 수동 백업은 동의 없이는 backupWouldReduceData를 던지고, 동의(allowReduce)하면 진행.
    func testDrasticShrink_AutoBlocks_ManualNeedsConsent() async throws {
        let many = (0..<10).map { Memo(title: "m\($0)", value: "v\($0)") }
        try memoStore.save(memos: many, type: .memo)
        try await sut.backupData()
        let savesAfterFirst = mockDB.saveCallCount

        // 자동 백업: 10 → 1 급감은 조용히 차단
        try memoStore.save(memos: [Memo(title: "only", value: "v")], type: .memo)
        try await sut.backupData(isAutomatic: true)
        XCTAssertEqual(mockDB.saveCallCount, savesAfterFirst, "급감 자동 백업은 차단되어야 함")
        XCTAssertEqual(try backedUpMemoCount(), 10, "기존 백업 10개가 유지되어야 함")

        // 수동 백업(동의 전): 데이터 손실 경고를 던져야 함(저장 안 함)
        do {
            try await sut.backupData()
            XCTFail("동의 없는 축소 수동 백업은 backupWouldReduceData를 던져야 함")
        } catch CloudKitError.backupWouldReduceData(let existing, let new) {
            XCTAssertEqual(existing, 10)
            XCTAssertEqual(new, 1)
        }
        XCTAssertEqual(try backedUpMemoCount(), 10, "동의 전에는 기존 백업이 유지돼야 함")

        // 수동 백업(동의함): 축소 반영
        try await sut.backupData(allowReduce: true)
        XCTAssertEqual(try backedUpMemoCount(), 1, "동의 후 수동 백업은 축소 반영")
    }

    // MARK: - 버전 백업(타임머신) 스냅샷

    func testBackup_CreatesVersionSnapshot() async throws {
        try memoStore.save(memos: [Memo(title: "a", value: "1"), Memo(title: "b", value: "2")], type: .memo)
        try await sut.backupData()

        let snaps = await sut.listSnapshots()
        XCTAssertEqual(snaps.count, 1)
        XCTAssertEqual(snaps.first?.memoCount, 2)
    }

    func testBackup_PrunesToMaxSnapshots() async throws {
        for i in 0..<17 {
            try memoStore.save(memos: [Memo(title: "m\(i)", value: "v")], type: .memo)
            try await sut.backupData()
        }
        let snaps = await sut.listSnapshots()
        XCTAssertEqual(snaps.count, 15, "최신 15개만 보관(오래된 건 정리)")
    }

    /// 타임머신: 과거 스냅샷으로 그 시점 상태를 복원할 수 있다.
    func testRestore_FromOldSnapshot_RecoversThatVersion() async throws {
        let v1 = [Memo(title: "v1a", value: "1"), Memo(title: "v1b", value: "2"), Memo(title: "v1c", value: "3")]
        try memoStore.save(memos: v1, type: .memo)
        try await sut.backupData()
        let firstSnaps = await sut.listSnapshots()
        let oldSnap = try XCTUnwrap(firstSnaps.first)

        // 이후 1개로 줄여 다시 백업(수동)
        try memoStore.save(memos: [Memo(title: "v2", value: "x")], type: .memo)
        try await sut.backupData()

        // 과거 스냅샷(3개)으로 복원
        clearLocalData()
        try await sut.restoreData(forceOverwrite: true, snapshotName: oldSnap.recordName)
        XCTAssertEqual(try memoStore.load(type: .memo).count, 3, "과거 버전(3개)으로 복원돼야 함")
    }

    /// 잘못된(축소) 백업이 끼어도 과거 스냅샷은 남아 복원 가능 - 핵심 안전망.
    func testShrinkBackup_KeepsOldSnapshotRecoverable() async throws {
        let many = (0..<10).map { Memo(title: "m\($0)", value: "v") }
        try memoStore.save(memos: many, type: .memo)
        try await sut.backupData()
        let bigSnaps = await sut.listSnapshots()
        let bigSnap = try XCTUnwrap(bigSnaps.first)

        // 수동으로 1개만 백업(동의 후 - 메인은 덮어써지지만 과거 스냅샷은 보존)
        try memoStore.save(memos: [Memo(title: "only", value: "v")], type: .memo)
        try await sut.backupData(allowReduce: true)

        clearLocalData()
        try await sut.restoreData(forceOverwrite: true, snapshotName: bigSnap.recordName)
        XCTAssertEqual(try memoStore.load(type: .memo).count, 10, "과거 10개 스냅샷에서 복원 가능해야 함")
    }

    // MARK: - 라운드트립 무결성 (핵심)

    func testBackupThenRestore_PreservesAllMemoFields() async throws {
        // Given - 모든 필드가 채워진 메모 + 클립보드 + 콤보
        let original = makeRichMemo()
        let clipboard = SmartClipboardHistory(content: "010-1234-5678", detectedType: .phone, confidence: 0.9)
        let stack = Combo(title: "출근 콤보", items: [
            ComboItem(type: .memo, referenceId: original.id, order: 0)
        ], interval: 3.0)

        try memoStore.save(memos: [original], type: .memo)
        try memoStore.saveSmartClipboardHistory(history: [clipboard])
        try memoStore.saveCombos([stack])

        // When - 백업 → 로컬 전체 삭제(기기 변경 시나리오) → 복원
        try await sut.backupData()
        clearLocalData()
        XCTAssertTrue(try memoStore.load(type: .memo).isEmpty, "사전 조건: 로컬이 비어 있어야 함")
        try await sut.restoreData(forceOverwrite: true)

        // Then - 메모의 모든 필드가 보존되어야 함
        let restored = try memoStore.load(type: .memo)
        XCTAssertEqual(restored.count, 1)
        let memo = try XCTUnwrap(restored.first)
        XCTAssertEqual(memo.id, original.id)
        XCTAssertEqual(memo.title, original.title)
        XCTAssertEqual(memo.value, original.value)
        XCTAssertEqual(memo.isChecked, original.isChecked)
        XCTAssertEqual(memo.isFavorite, original.isFavorite)
        XCTAssertEqual(memo.clipCount, original.clipCount)
        XCTAssertEqual(memo.category, original.category)
        XCTAssertEqual(memo.isSecure, original.isSecure)
        XCTAssertEqual(memo.templateVariables, original.templateVariables)
        XCTAssertEqual(memo.placeholderValues, original.placeholderValues)
        XCTAssertEqual(memo.stackValues, original.stackValues)
        XCTAssertEqual(memo.stackInterval, original.stackInterval)
        XCTAssertEqual(memo.autoDetectedType, original.autoDetectedType)
        XCTAssertEqual(memo.imageFileName, original.imageFileName)
        XCTAssertEqual(memo.imageFileNames, original.imageFileNames)
        XCTAssertEqual(memo.contentType, original.contentType)
        XCTAssertEqual(memo.hint, original.hint)
        XCTAssertTrue(memo.isTemplate, "템플릿 판정(계산형)이 복원 후에도 유지")
        XCTAssertTrue(memo.isStack, "콤보 판정(계산형)이 복원 후에도 유지")
        // 날짜는 JSON 인코딩 정밀도 내에서 일치
        XCTAssertEqual(memo.lastEdited.timeIntervalSince1970,
                       original.lastEdited.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(memo.lastUsedAt).timeIntervalSince1970,
                       try XCTUnwrap(original.lastUsedAt).timeIntervalSince1970, accuracy: 0.001)

        // 클립보드/콤보도 보존
        let restoredClipboard = try memoStore.loadSmartClipboardHistory()
        XCTAssertEqual(restoredClipboard.count, 1)
        XCTAssertEqual(restoredClipboard[0].content, clipboard.content)
        XCTAssertEqual(restoredClipboard[0].detectedType, .phone)

        let restoredStacks = try memoStore.loadCombos()
        XCTAssertEqual(restoredStacks.count, 1)
        XCTAssertEqual(restoredStacks[0].title, stack.title)
        XCTAssertEqual(restoredStacks[0].items.count, 1)
        XCTAssertEqual(restoredStacks[0].items[0].referenceId, original.id)
    }

    func testRestore_ResetsStackMigrationFlag() async throws {
        // Given - 마이그레이션 완료 상태에서 옛 백업을 복원하는 상황
        appGroupDefaults?.set(true, forKey: "comboModelUnifyMigrated_v1")
        try memoStore.save(memos: [Memo(title: "백업", value: "값")], type: .memo)
        try await sut.backupData()

        // When
        try await sut.restoreData(forceOverwrite: true)

        // Then - 복원된 레거시 데이터가 다음 실행에 재변환되도록 플래그 리셋
        XCTAssertEqual(appGroupDefaults?.bool(forKey: "comboModelUnifyMigrated_v1"), false)
    }

    // MARK: - 복원: 사용자 보호 장치

    func testRestore_WithLocalData_RequiresConfirmationAndKeepsData() async throws {
        // Given - 백업 존재 + 로컬에 다른 데이터 존재
        try memoStore.save(memos: [Memo(title: "백업본", value: "값")], type: .memo)
        try await sut.backupData()
        let localOnly = [Memo(title: "로컬 신규 메모", value: "아직 백업 안 됨")]
        try memoStore.save(memos: localOnly, type: .memo)

        // When/Then - forceOverwrite 없이 복원하면 거부(사용자 확인 필요)
        do {
            try await sut.restoreData(forceOverwrite: false)
            XCTFail("로컬 데이터가 있으면 확인 없이 덮어쓰면 안 됨")
        } catch {
            // 거부 후 로컬 데이터는 그대로여야 함 (무결성)
            let memos = try memoStore.load(type: .memo)
            XCTAssertEqual(memos.count, 1)
            XCTAssertEqual(memos[0].title, "로컬 신규 메모")
        }
    }

    func testRestore_NoBackup_ThrowsNoBackupFound() async throws {
        // Given - mock DB에 레코드 없음
        // When/Then
        do {
            try await sut.restoreData(forceOverwrite: true)
            XCTFail("백업이 없으면 noBackupFound를 던져야 함")
        } catch let error as CloudKitError {
            guard case .noBackupFound = error else {
                return XCTFail("noBackupFound 기대, 실제: \(error)")
            }
        }
    }

    func testRestore_CorruptedMemoAsset_FailsAndKeepsLocalData() async throws {
        // Given - 깨진 JSON이 든 백업 레코드 + 로컬 데이터
        let record = CKRecord(recordType: "Backup", recordID: backupRecordID)
        let corruptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-memos.json")
        try Data("이건 JSON이 아님 {{{".utf8).write(to: corruptURL)
        record["memosAsset"] = CKAsset(fileURL: corruptURL)
        mockDB.records[backupRecordID] = record

        let sentinel = [Memo(title: "지켜야 할 메모", value: "값")]
        try memoStore.save(memos: sentinel, type: .memo)

        // When/Then - 복원은 실패하고 로컬 데이터는 손대지 않아야 함
        do {
            try await sut.restoreData(forceOverwrite: true)
            XCTFail("깨진 백업은 복원에 실패해야 함")
        } catch {
            let memos = try memoStore.load(type: .memo)
            XCTAssertEqual(memos.count, 1)
            XCTAssertEqual(memos[0].title, "지켜야 할 메모")
        }
    }

    // MARK: - 레거시 백업 포맷 호환

    func testRestore_LegacyDataFieldRecord_StillWorks() async throws {
        // Given - CKAsset 도입 전, Data 필드에 직접 저장하던 옛 백업 레코드
        let legacyMemos = [Memo(title: "옛 백업 메모", value: "레거시 값", category: "여행")]
        let record = CKRecord(recordType: "Backup", recordID: backupRecordID)
        record["memos"] = try JSONEncoder().encode(legacyMemos) as NSData
        record["smartClipboardHistory"] = try JSONEncoder().encode(
            [SmartClipboardHistory(content: "legacy@example.com", detectedType: .email, confidence: 0.9)]
        ) as NSData
        mockDB.records[backupRecordID] = record

        // When
        try await sut.restoreData(forceOverwrite: true)

        // Then
        let memos = try memoStore.load(type: .memo)
        XCTAssertEqual(memos.count, 1)
        XCTAssertEqual(memos[0].title, "옛 백업 메모")
        XCTAssertEqual(memos[0].category, "여행")

        let clipboard = try memoStore.loadSmartClipboardHistory()
        XCTAssertEqual(clipboard.count, 1)
        XCTAssertEqual(clipboard[0].content, "legacy@example.com")
    }

    // MARK: - 인증

    func testBackup_NotAuthenticated_Throws() async throws {
        // Given - iCloud 미로그인
        let unauthSut = CloudKitBackupService(database: mockDB, accountStatus: { .noAccount })
        try memoStore.save(memos: [Memo(title: "메모", value: "값")], type: .memo)

        // When/Then
        do {
            try await unauthSut.backupData()
            XCTFail("미인증 상태에서 백업은 실패해야 함")
        } catch let error as CloudKitError {
            guard case .notAuthenticated = error else {
                return XCTFail("notAuthenticated 기대, 실제: \(error)")
            }
            XCTAssertEqual(mockDB.saveCallCount, 0, "인증 실패 시 네트워크 저장 시도 자체가 없어야 함")
        }
    }

    func testRestore_NotAuthenticated_Throws() async throws {
        // Given
        let unauthSut = CloudKitBackupService(database: mockDB, accountStatus: { .restricted })

        // When/Then
        do {
            try await unauthSut.restoreData(forceOverwrite: true)
            XCTFail("미인증 상태에서 복원은 실패해야 함")
        } catch let error as CloudKitError {
            guard case .notAuthenticated = error else {
                return XCTFail("notAuthenticated 기대, 실제: \(error)")
            }
        }
    }

    // MARK: - 재시도 정책

    func testBackup_RetriesOnTransientNetworkFailure() async throws {
        // Given - 첫 저장은 네트워크 실패, 두 번째는 성공
        mockDB.saveErrorQueue = [CKError(.networkFailure)]
        try memoStore.save(memos: [Memo(title: "재시도", value: "값")], type: .memo)

        // When
        try await sut.backupData()

        // Then - 1회 재시도 후 성공, 레코드 저장됨
        // (saveCallCount는 메인+스냅샷+인덱스 저장을 모두 포함하므로 정확한 값 대신 의도를 검증)
        XCTAssertGreaterThanOrEqual(mockDB.saveCallCount, 2, "전송 실패 1회 후 재시도해야 함")
        XCTAssertTrue(mockDB.saveErrorQueue.isEmpty, "주입한 전송 오류가 소비(재시도)돼야 함")
        XCTAssertNotNil(mockDB.records[backupRecordID])
    }

    func testBackup_NonRetryableError_FailsImmediately() async throws {
        // Given - 권한 오류는 재시도해도 소용없음
        mockDB.saveErrorQueue = [CKError(.permissionFailure)]
        try memoStore.save(memos: [Memo(title: "메모", value: "값")], type: .memo)

        // When/Then
        do {
            try await sut.backupData()
            XCTFail("재시도 불가 에러는 즉시 실패해야 함")
        } catch {
            XCTAssertEqual(mockDB.saveCallCount, 1, "재시도 없이 1회만 시도해야 함")
        }
    }

    // MARK: - 백업 존재 확인 / 삭제

    func testHasBackup_ReflectsRecordExistence() async throws {
        // Given/When/Then - 백업 전엔 false
        let before = await sut.hasBackup()
        XCTAssertFalse(before)

        // 백업 후엔 true
        try memoStore.save(memos: [Memo(title: "메모", value: "값")], type: .memo)
        try await sut.backupData()
        let after = await sut.hasBackup()
        XCTAssertTrue(after)
    }

    func testDeleteBackup_RemovesRecordAndClearsDate() async throws {
        // Given - 백업 존재
        try memoStore.save(memos: [Memo(title: "메모", value: "값")], type: .memo)
        try await sut.backupData()
        XCTAssertNotNil(sut.lastBackupDate)

        // When
        try await sut.deleteBackup()

        // Then
        let exists = await sut.hasBackup()
        XCTAssertFalse(exists)
        await MainActor.run {
            XCTAssertNil(sut.lastBackupDate)
        }
        XCTAssertNil(UserDefaults.standard.object(forKey: "lastBackupDate"))
    }
}
