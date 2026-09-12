//
//  CloudKitBackupService.swift
//  ClipKeyboard
//
//  Created by Claude on 2025-11-28.
//

import Foundation
import CloudKit
import Combine

/// 백업 시도의 실제 결과. "백업했다"고 뭉뚱그리지 않고, 실제로 올라간 개수/건너뛴
/// 이유를 사용자에게 정확히 알려 조용한 실패(성공처럼 보이는 무동작)를 없앤다.
enum BackupOutcome {
    case backedUp(memoCount: Int)
    case nothingToBackUp
    case skippedToProtectExisting(existing: Int, new: Int)
}

enum CloudKitError: Error {
    case notAuthenticated
    case backupFailed(Error)
    case restoreFailed(Error)
    case noBackupFound
    case encodingFailed
    case decodingFailed
    /// 이 백업이 기존 백업을 빈/훨씬 적은 데이터로 덮어써 데이터 손실 위험이 있을 때(수동 백업에서 사용자 동의 필요).
    case backupWouldReduceData(existing: Int, new: Int)

    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return NSLocalizedString("iCloud에 로그인되어 있지 않습니다. 설정 > [사용자 이름] > iCloud에서 로그인해주세요.",
                                   comment: "iCloud not authenticated error message")
        case .backupFailed(let error):
            return getActionableMessage(for: error, operation: "backup")
        case .restoreFailed(let error):
            return getActionableMessage(for: error, operation: "restore")
        case .noBackupFound:
            return NSLocalizedString("백업 데이터가 없습니다. 먼저 백업을 생성해주세요.",
                                   comment: "No backup found error message")
        case .encodingFailed:
            return NSLocalizedString("데이터를 준비하는 중 문제가 발생했습니다. 앱을 재시작하고 다시 시도해주세요.",
                                   comment: "Data encoding failed error message")
        case .decodingFailed:
            return NSLocalizedString("백업 데이터를 읽을 수 없습니다. 최신 버전의 앱을 사용하고 있는지 확인해주세요.",
                                   comment: "Data decoding failed error message")
        case .backupWouldReduceData(let existing, let new):
            return String(format: NSLocalizedString("기존 백업(단축어 %1$d개)을 %2$d개로 덮어쓰려고 합니다. 줄어든 데이터는 백업에서 사라집니다.", comment: "Backup would reduce data warning"), existing, new)
        }
    }

    // MARK: - Helper

    private func getActionableMessage(for error: Error, operation: String) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return NSLocalizedString("네트워크 연결을 확인하고 다시 시도해주세요.",
                                       comment: "Network error message")
            case .notAuthenticated:
                return NSLocalizedString("iCloud에 로그인되어 있지 않습니다. 설정 > [사용자 이름] > iCloud에서 로그인해주세요.",
                                       comment: "iCloud not authenticated error message")
            case .quotaExceeded:
                return NSLocalizedString("iCloud 저장 공간이 부족합니다. 설정 > [사용자 이름] > iCloud > 저장 공간 관리에서 확인해주세요.",
                                       comment: "iCloud quota exceeded error message")
            case .permissionFailure:
                return NSLocalizedString("iCloud Drive가 활성화되어 있는지 확인해주세요. 설정 > [사용자 이름] > iCloud > iCloud Drive를 켜주세요.",
                                       comment: "iCloud permission error message")
            case .serverResponseLost, .serviceUnavailable:
                return NSLocalizedString("iCloud 서버에 일시적인 문제가 있습니다. 잠시 후 다시 시도해주세요.",
                                       comment: "iCloud server error message")
            case .zoneBusy, .requestRateLimited:
                return NSLocalizedString("요청이 너무 많습니다. 잠시 후 다시 시도해주세요.",
                                       comment: "Rate limited error message")
            default:
                return NSLocalizedString("문제가 발생했습니다. 네트워크 연결과 iCloud 상태를 확인하고 다시 시도해주세요.",
                                       comment: "Generic iCloud error message")
            }
        }
        return NSLocalizedString("문제가 발생했습니다. 네트워크 연결과 iCloud 상태를 확인하고 다시 시도해주세요.",
                               comment: "Generic error message")
    }
}

// MARK: - CloudKit Database 추상화 (테스트 주입용)

/// CloudKit private DB 중 백업이 쓰는 연산만 추상화. 실제 CKDatabase가 그대로 채택하고,
/// 테스트는 인메모리 mock을 주입해 네트워크 없이 백업/복원 전 경로의 무결성을 검증한다.
protocol CloudKitBackupDatabase {
    func record(for recordID: CKRecord.ID) async throws -> CKRecord
    @discardableResult func save(_ record: CKRecord) async throws -> CKRecord
    @discardableResult func deleteRecord(withID recordID: CKRecord.ID) async throws -> CKRecord.ID
}

extension CKDatabase: CloudKitBackupDatabase {}

#if targetEnvironment(simulator)
/// 시뮬레이터 전용 no-op DB. 시뮬레이터에서는 iCloud 컨테이너/엔타이틀먼트가 적용되지 않아
/// CKContainer(identifier:)가 os_crash로 앱을 죽이므로, CloudKit을 아예 건드리지 않고
/// 타입만 만족시켜 UI/스크린샷 개발이 가능하게 한다. 실제 접근은 항상 실패로 처리.
private struct SimulatorNoopDatabase: CloudKitBackupDatabase {
    struct Unavailable: Error {}
    func record(for recordID: CKRecord.ID) async throws -> CKRecord { throw Unavailable() }
    @discardableResult func save(_ record: CKRecord) async throws -> CKRecord { throw Unavailable() }
    @discardableResult func deleteRecord(withID recordID: CKRecord.ID) async throws -> CKRecord.ID { throw Unavailable() }
}
#endif

/// 버전 백업(타임머신) 한 항목의 메타데이터 - 복원 화면의 날짜별 목록에 쓰인다.
struct BackupSnapshotInfo: Codable, Identifiable, Equatable {
    var id: String { recordName }
    let recordName: String
    let date: Date
    let memoCount: Int
}

class CloudKitBackupService: ObservableObject {
    static let shared = CloudKitBackupService()

    /// CloudKit 배선 한 벌. 이걸 만드는 일이 곧 `CKContainer(identifier:)` 를 부르는 일이다.
    private struct Backend {
        let database: CloudKitBackupDatabase
        let accountStatus: () async throws -> CKAccountStatus
    }

    /// 미리 꽂아 둔 배선(테스트 mock · 시뮬레이터 noop). 있으면 CloudKit 을 아예 만들지 않는다.
    private let injectedBackend: Backend?

    /// iCloud 컨테이너 식별자. 이 값으로 컨테이너를 만드는 자리는 `CloudKitContainer` 뿐이다.
    private static let containerIdentifier = "iCloud.com.Ysoup.TokenMemo"

    /// 실제로 쓸 배선. **처음 물어보는 순간 컨테이너가 만들어진다.**
    ///
    /// ⚠️ 저장 프로퍼티가 아니라 `async` 접근자인 것이 핵심이다. 저장 프로퍼티였을 때는
    ///    `init()` 안에서 컨테이너를 만들었고, 그 `init()` 은 첫 화면을 그리는 메인 스레드에서
    ///    `swift_once` 로 불렸다. cloudd 가 대답하지 않던 기기에서 앱은 22초를 기다리다
    ///    워치독에 죽었다(4.4.6, `docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md`). 지금은 백업/복원처럼
    ///    실제로 CloudKit 이 필요한 순간에, 메인 스레드 밖에서 만들어진다.
    private var backend: Backend {
        get async {
            if let injectedBackend { return injectedBackend }
            let container = await CloudKitContainer.resolve(Self.containerIdentifier)
            return Backend(
                database: container.privateCloudDatabase,
                accountStatus: { try await container.accountStatus() }
            )
        }
    }

    @Published var isAuthenticated: Bool = false
    @Published var lastBackupDate: Date?
    @Published var isBackingUp: Bool = false
    @Published var isRestoring: Bool = false
    @Published var autoBackupEnabled: Bool = false

    private var autoBackupTimer: Timer?
    private let autoBackupInterval: TimeInterval = 300 // 5분마다 자동 백업

    // MARK: - Version Snapshots (타임머신)
    /// 스냅샷 목록(이름·날짜·개수)을 담는 인덱스 레코드. CKQuery 없이 단일 레코드 fetch로 목록을 읽는다.
    private let snapshotIndexRecordID = CKRecord.ID(recordName: "TokenMemoBackupIndex")
    /// 보관할 최대 스냅샷 개수(이보다 오래된 건 백업 시 자동 정리).
    private let maxSnapshots = 15

    /// ⚠️ **여기서 CloudKit 을 만들지 않는다.**
    ///
    /// 이 `init()` 은 `static let shared` 의 `swift_once` 안에서 돈다. 즉 누가 처음
    /// `.shared` 를 만지든 그 스레드가 여기를 통과해야 하고, 런치 경로에서 그 스레드는
    /// 메인 스레드다. 4.4.6 은 이 자리에서 `CKContainer(identifier:)` 를 불렀고,
    /// 그 한 줄이 첫 화면을 22초 붙잡아 워치독이 앱을 죽였다.
    /// 남은 것은 UserDefaults 읽기와 알림 구독뿐이라 밀리초 안에 끝난다.
    private init() {
        #if targetEnvironment(simulator)
        // 시뮬레이터에서는 iCloud 컨테이너/엔타이틀먼트가 적용되지 않아 CKContainer(identifier:)가
        // CloudKit 내부 os_crash(EXC_BREAKPOINT)로 앱을 런치 즉시 죽인다(try?로도 못 막음).
        // 백업은 실기기 전용 기능이므로, 시뮬레이터에서는 CloudKit 초기화·타이머·리스너를 전부
        // 건너뛰고 저장 프로퍼티만 세팅한다. 실기기/앱스토어 빌드에는 전혀 영향 없음.
        self.injectedBackend = Backend(
            database: SimulatorNoopDatabase(),
            accountStatus: { .couldNotDetermine }
        )
        #else
        self.injectedBackend = nil

        checkAccountStatus()
        loadLastBackupDate()
        loadAutoBackupSetting()

        // 데이터 변경 알림 리스너 등록
        setupDataChangeListener()
        #endif
    }

    /// 테스트 전용: mock DB/계정 상태를 주입한다.
    /// 타이머·데이터 변경 리스너·초기 자동 백업 등 부작용 없이 순수 백업/복원 로직만 동작.
    init(database: CloudKitBackupDatabase,
         accountStatus: @escaping () async throws -> CKAccountStatus) {
        self.injectedBackend = Backend(database: database, accountStatus: accountStatus)
    }

    deinit {
        autoBackupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Account Status

    /// iCloud 로그인 상태를 확인해 `isAuthenticated` 에 반영한다.
    ///
    /// ⚠️ 예전에는 저장해 둔 컨테이너에 바로 물었다. 그러려면 컨테이너가 `init()` 시점에
    ///    있어야 했고, 그것이 런치를 붙잡은 원인이었다. 지금은 배선을 얻는 일부터
    ///    메인 스레드 밖에서 하고, 화면에 닿는 값만 메인으로 돌려준다.
    func checkAccountStatus() {
        Task { [weak self] in
            guard let self else { return }
            let status = (try? await self.backend.accountStatus()) ?? .couldNotDetermine
            await MainActor.run {
                self.isAuthenticated = (status == .available)
                AppLog.info(.backup, "📱 [CloudKit] Account Status: \(status.rawValue)")
            }
        }
    }

    private func loadLastBackupDate() {
        if let timestamp = UserDefaults.standard.object(forKey: DefaultsKey.lastBackupDate) as? Date {
            self.lastBackupDate = timestamp
        }
    }

    private func saveLastBackupDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: DefaultsKey.lastBackupDate)
        self.lastBackupDate = date
    }

    private func loadAutoBackupSetting() {
        let defaults = UserDefaults.standard
        // 자동 백업 기본값 ON: 한 번도 설정한 적 없으면 켠다. 다른 기기(맥)에서
        // 시작 시 바로 복원할 수 있도록 항상 최신 백업이 존재하게 한다.
        // 이미 켜거나 끈 사용자의 명시적 선택은 그대로 존중한다.
        if defaults.object(forKey: DefaultsKey.autoBackupEnabled) == nil {
            defaults.set(true, forKey: DefaultsKey.autoBackupEnabled)
            AppLog.info(.backup, "🔄 [CloudKit] 자동 백업 기본 활성화 (최초 실행)")
        }
        self.autoBackupEnabled = defaults.bool(forKey: DefaultsKey.autoBackupEnabled)
        if autoBackupEnabled {
            startAutoBackupTimer()
            performInitialBackupIfNeeded()
        }
    }

    /// 시작 직후 최신 백업을 한 번 보장한다 - 맥/다른 기기가 바로 복원할 수 있게.
    /// 인증이 확정될 때까지 잠깐 대기하고, 최근(1시간 내) 백업이 있으면 생략한다.
    private func performInitialBackupIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            // init의 accountStatus 콜백이 비동기라 인증 확정까지 최대 5초 대기.
            for _ in 0..<10 {
                if self.isAuthenticated { break }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard self.autoBackupEnabled, self.isAuthenticated, !self.isBackingUp else { return }
            if let last = self.lastBackupDate, Date().timeIntervalSince(last) < 3600 {
                AppLog.info(.backup, "ℹ️ [CloudKit] 최근 백업 존재 - 시작 초기 백업 생략")
                return
            }
            do {
                try await self.backupData(isAutomatic: true)
                AppLog.info(.backup, "✅ [CloudKit] 시작 직후 초기 백업 완료")
            } catch {
                AppLog.warning(.backup, "⚠️ [CloudKit] 시작 초기 백업 실패: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Auto Backup

    func enableAutoBackup() {
        AppLog.info(.backup, "🔄 [CloudKit] 자동 백업 활성화")
        UserDefaults.standard.set(true, forKey: DefaultsKey.autoBackupEnabled)
        DispatchQueue.main.async { [weak self] in
            self?.autoBackupEnabled = true
        }
        startAutoBackupTimer()
    }

    func disableAutoBackup() {
        AppLog.info(.backup, "⏸️ [CloudKit] 자동 백업 비활성화")
        UserDefaults.standard.set(false, forKey: DefaultsKey.autoBackupEnabled)
        DispatchQueue.main.async { [weak self] in
            self?.autoBackupEnabled = false
        }
        stopAutoBackupTimer()
    }

    private func startAutoBackupTimer() {
        stopAutoBackupTimer() // 기존 타이머 제거

        autoBackupTimer = Timer.scheduledTimer(withTimeInterval: autoBackupInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isAuthenticated && !self.isBackingUp else { return }

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.backupData(isAutomatic: true)
                    AppLog.info(.backup, "✅ [CloudKit] 자동 백업 성공")
                } catch {
                    AppLog.warning(.backup, "⚠️ [CloudKit] 자동 백업 실패: \(error.localizedDescription)")
                }
            }
        }

        AppLog.info(.backup, "⏰ [CloudKit] 자동 백업 타이머 시작 (간격: \(Int(autoBackupInterval))초)")
    }

    private func stopAutoBackupTimer() {
        autoBackupTimer?.invalidate()
        autoBackupTimer = nil
        AppLog.info(.backup, "⏹️ [CloudKit] 자동 백업 타이머 중지")
    }

    private func setupDataChangeListener() {
        // MemoStore에서 데이터 변경 알림을 받으면 자동 백업 트리거
        NotificationCenter.default.addObserver(
            forName: Notification.Name.memoDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            guard self.autoBackupEnabled && self.isAuthenticated && !self.isBackingUp else { return }

            AppLog.info(.backup, "📢 [CloudKit] 데이터 변경 감지 - 자동 백업 예약")

            // 변경사항이 연속으로 발생할 수 있으므로 디바운스 (5초 후 실행)
            self.scheduleAutoBackup()
        }
    }

    private var autoBackupWorkItem: DispatchWorkItem?

    private func scheduleAutoBackup() {
        // 기존 예약된 백업 취소
        autoBackupWorkItem?.cancel()

        // 새로운 백업 예약 (5초 후)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.backupData(isAutomatic: true)
                    AppLog.info(.backup, "✅ [CloudKit] 변경사항 자동 백업 완료")
                } catch {
                    AppLog.warning(.backup, "⚠️ [CloudKit] 자동 백업 실패: \(error.localizedDescription)")
                }
            }
        }

        autoBackupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    // MARK: - Helper Methods

    /// Data를 CKAsset으로 변환 (대용량 데이터 저장용)
    private func createAsset(from data: Data, filename: String) throws -> CKAsset {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try data.write(to: fileURL)

        return CKAsset(fileURL: fileURL)
    }

    // MARK: - Image Backup (App Group Images/ ↔ CKAsset)

    /// App Group 내 이미지 폴더.
    private var imagesBackupDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("Images")
    }

    /// 메모들이 참조하는 PNG들을 백업 레코드에 CKAsset 배열로 첨부(존재하는 파일만).
    /// 이미지가 없으면 필드를 비워 이전 백업의 잔존 이미지를 정리한다.
    private func attachImages(to record: inout CKRecord, memos: [Memo]) {
        var names = Set<String>()
        for memo in memos {
            names.formUnion(memo.imageFileNames)
            if let single = memo.imageFileName, !single.isEmpty { names.insert(single) }
        }
        guard let dir = imagesBackupDirectory else { return }
        var assets: [CKAsset] = []
        var attachedNames: [String] = []
        for name in names.sorted() {
            let url = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                assets.append(CKAsset(fileURL: url))
                attachedNames.append(name)
            }
        }
        if assets.isEmpty {
            record["imageAssets"] = nil
            record["imageNames"] = nil
        } else {
            record["imageAssets"] = assets as CKRecordValue
            record["imageNames"] = attachedNames as CKRecordValue
        }
        AppLog.info(.backup, "🖼️ [CloudKit] 백업 이미지: \(attachedNames.count)개")
    }

    /// 백업 레코드의 이미지 CKAsset들을 App Group Images/에 복원(덮어쓰기).
    private func restoreImages(from record: CKRecord) {
        guard let assets = record["imageAssets"] as? [CKAsset],
              let names = record["imageNames"] as? [String],
              let dir = imagesBackupDirectory else {
            AppLog.info(.backup, "ℹ️ [CloudKit] 복원할 이미지 없음")
            return
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var restored = 0
        for (asset, name) in zip(assets, names) {
            guard let src = asset.fileURL else { continue }
            let dest = dir.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dest)   // 덮어쓰기
            do { try FileManager.default.copyItem(at: src, to: dest); restored += 1 }
            catch { AppLog.warning(.backup, "⚠️ [CloudKit] 이미지 복원 실패 \(name): \(error.localizedDescription)") }
        }
        AppLog.info(.backup, "🖼️ [CloudKit] 이미지 \(restored)개 복원 완료")
    }

    /// CKAsset에서 Data 읽기
    private func readAsset(_ asset: CKAsset) throws -> Data {
        guard let fileURL = asset.fileURL else {
            throw CloudKitError.decodingFailed
        }

        return try Data(contentsOf: fileURL)
    }

    // MARK: - Backup

    /// 호출 시점에 계정 상태를 새로 확인. init의 async 콜백이 아직 돌아오지
    /// 않은 상태에서 첫 버튼 클릭으로 .notAuthenticated 오탐이 나던 race를 제거.
    private func ensureAuthenticated() async throws {
        let status = try await backend.accountStatus()
        await MainActor.run { self.isAuthenticated = (status == .available) }
        guard status == .available else {
            AppLog.warning(.backup, "⚠️ [CloudKit] accountStatus = \(status.rawValue) (not available)")
            throw CloudKitError.notAuthenticated
        }
    }

    /// - Parameters:
    ///   - isAutomatic: 자동 백업(시작/타이머/데이터변경) 여부.
    ///   - allowReduce: 기존 백업을 빈/훨씬 적은 데이터로 덮어쓰는 것을 사용자가 동의했는지(수동 백업에서 확인 후 true).
    ///
    ///   데이터 손실 방지 정책:
    ///   · 자동 백업: 기존 백업을 빈/대폭(절반 이하)으로 축소하지 못한다(조용히 건너뜀).
    ///   · 수동 백업: 같은 상황이면 `backupWouldReduceData`를 던져 **사용자 동의**를 받는다(동의 시 allowReduce=true로 재호출).
    @discardableResult
    func backupData(isAutomatic: Bool = false, allowReduce: Bool = false) async throws -> BackupOutcome {
        AppLog.info(.backup, "☁️ [CloudKit] 백업 시작... (자동=\(isAutomatic), 축소동의=\(allowReduce))")

        try await ensureAuthenticated()

        await MainActor.run { isBackingUp = true }
        defer { Task { @MainActor [weak self] in self?.isBackingUp = false } }

        do {
            let (memos, smartClipboard, combos) = try loadDataForBackup()

            // 시드 샘플을 제외한 "실데이터" 개수.
            let sampleIDs = SampleMemoStorage.load()
            let realMemos = memos.filter { !sampleIDs.contains($0.id) }
            let newCount = memos.count

            var record = try await fetchOrCreateRecord()
            let existingCount = Self.existingMemoCount(from: record) ?? 0

            // ⚠️ 데이터 손실 방지 정책 (백업은 단일 레코드를 덮어쓰므로):
            //  · 빈/샘플뿐 + 기존 백업 없음 → 백업할 게 없으니 건너뜀.
            //  · "파괴적"(실데이터 0 또는 기존 백업의 절반 이하로 축소) →
            //      - 자동 백업: 조용히 건너뜀(절대 기존 백업을 망가뜨리지 않음).
            //      - 수동 백업: backupWouldReduceData를 던져 사용자 동의를 받음(allowReduce로 재호출).
            let nothingReal = realMemos.isEmpty
            let drasticReduce = existingCount >= 4 && newCount * 2 < existingCount
            let destructive = nothingReal || drasticReduce

            if nothingReal && existingCount == 0 {
                AppLog.info(.backup, "🛑 [CloudKit] 실데이터 없음 + 기존 백업 없음. 백업할 것 없음")
                return .nothingToBackUp
            }
            if destructive {
                if isAutomatic {
                    AppLog.info(.backup, "🛑 [CloudKit] 자동 백업 보호: 빈/대폭축소(기존 \(existingCount)→\(newCount)), 건너뜀(기존 백업 보존)")
                    return .skippedToProtectExisting(existing: existingCount, new: newCount)
                }
                if !allowReduce {
                    AppLog.warning(.backup, "⚠️ [CloudKit] 수동 백업이 기존 \(existingCount)→\(newCount)로 축소, 사용자 동의 필요")
                    throw CloudKitError.backupWouldReduceData(existing: existingCount, new: newCount)
                }
                AppLog.info(.backup, "✅ [CloudKit] 사용자 동의됨. 축소 백업 진행(\(existingCount)→\(newCount))")
            }

            let (memosData, smartClipboardData, combosData) = try encodeDataForBackup(
                memos: memos, smartClipboard: smartClipboard, combos: combos
            )
            // ⚠️ 한 번만 만들어 **메인 레코드와 버전 스냅샷에 같은 것을** 싣는다.
            //    예전에는 메인 레코드에서만 만들어, 타임머신으로 되돌리면 카테고리가
            //    통째로 사라졌다(백업엔 있는데 그 시점 스냅샷엔 없으니).
            let categoriesData = try? JSONEncoder().encode(CategorySnapshotStore.current())
            try configureRecord(&record, memosData: memosData, smartClipboardData: smartClipboardData,
                                combosData: combosData, categoriesData: categoriesData)
            record["memoCount"] = memos.count as CKRecordValue  // 다음 백업의 축소 가드용(저렴한 비교 필드)
            attachImages(to: &record, memos: memos)   // 첨부 이미지(PNG)도 함께 백업

            _ = try await saveRecordWithRetry(record, maxRetries: 3)

            let backupDate = Date()
            await MainActor.run { saveLastBackupDate(backupDate) }

            // 버전 스냅샷(타임머신) 보관 - 메인 백업 성공 직후 타임스탬프 스냅샷을 쌓는다.
            // 실패해도 메인 백업은 정상 처리(스냅샷은 추가 안전망일 뿐 메인 백업을 막지 않는다).
            do {
                try await writeVersionSnapshot(
                    memosData: memosData, smartClipboardData: smartClipboardData, combosData: combosData,
                    categoriesData: categoriesData,
                    memos: memos, memoCount: memos.count, date: backupDate
                )
            } catch {
                AppLog.warning(.backup, "⚠️ [CloudKit] 버전 스냅샷 저장 실패(메인 백업은 정상): \(error.localizedDescription)")
            }
            AppLog.info(.backup, "✅ [CloudKit] 백업 완료: \(backupDate)")
            return .backedUp(memoCount: memos.count)

        } catch let ckError as CloudKitError {
            // 정책상 던진 CloudKitError(backupWouldReduceData 등)는 그대로 전달(backupFailed로 감싸지 않음).
            throw ckError
        } catch let error as CKError {
            AppLog.error(.backup, "❌ [CloudKit] 백업 실패: \(error)")
            AppLog.info(.backup, "   코드: \(error.code.rawValue)")
            AppLog.info(.backup, "   설명: \(error.localizedDescription)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
                AppLog.info(.backup, "   Underlying Error: \(underlyingError)")
            }
            throw CloudKitError.backupFailed(error)
        } catch {
            AppLog.error(.backup, "❌ [CloudKit] 백업 실패 (일반 에러): \(error)")
            throw CloudKitError.backupFailed(error)
        }
    }

    private func loadDataForBackup() throws -> (memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]) {
        let memos = try MemoStore.shared.load(type: .memo)
        let smartClipboard = try MemoStore.shared.loadSmartClipboardHistory()
        let combos = try MemoStore.shared.loadCombos()
        AppLog.info(.backup, "📦 [CloudKit] 백업할 메모: \(memos.count)개")
        AppLog.info(.backup, "📦 [CloudKit] 백업할 스마트 클립보드: \(smartClipboard.count)개")
        AppLog.info(.backup, "📦 [CloudKit] 백업할 Combo: \(combos.count)개")
        return (memos, smartClipboard, combos)
    }

    private func encodeDataForBackup(
        memos: [Memo], smartClipboard: [SmartClipboardHistory], combos: [Combo]
    ) throws -> (memosData: Data, smartClipboardData: Data, combosData: Data) {
        guard let memosData = try? JSONEncoder().encode(memos),
              let smartClipboardData = try? JSONEncoder().encode(smartClipboard),
              let combosData = try? JSONEncoder().encode(combos) else {
            AppLog.error(.backup, "❌ [CloudKit] JSON 인코딩 실패")
            throw CloudKitError.encodingFailed
        }
        AppLog.info(.backup, "📊 [CloudKit] 메모 데이터 크기: \(ByteCountFormatter.string(fromByteCount: Int64(memosData.count), countStyle: .file))")
        AppLog.info(.backup, "📊 [CloudKit] 스마트 클립보드 크기: \(ByteCountFormatter.string(fromByteCount: Int64(smartClipboardData.count), countStyle: .file))")
        AppLog.info(.backup, "📊 [CloudKit] Combo 데이터 크기: \(ByteCountFormatter.string(fromByteCount: Int64(combosData.count), countStyle: .file))")
        return (memosData, smartClipboardData, combosData)
    }

    /// 기존 백업 레코드의 메모 개수. memoCount 필드(빠름) 우선, 없으면(레거시 백업) memosAsset/
    /// memos를 디코드해 센다. 알 수 없으면 nil(가드 미적용 → 통과).
    private static func existingMemoCount(from record: CKRecord) -> Int? {
        if let n = record["memoCount"] as? Int { return n }
        var data: Data?
        if let asset = record["memosAsset"] as? CKAsset, let url = asset.fileURL {
            data = try? Data(contentsOf: url)
        }
        if data == nil, let legacy = record["memos"] as? Data { data = legacy }
        guard let d = data, let memos = try? JSONDecoder().decode([Memo].self, from: d) else { return nil }
        return memos.count
    }

    private func fetchOrCreateRecord() async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
        do {
            let record = try await backend.database.record(for: recordID)
            AppLog.info(.backup, "🔄 [CloudKit] 기존 백업 레코드 업데이트")
            return record
        } catch let error as CKError where error.code == .unknownItem {
            AppLog.info(.backup, "✨ [CloudKit] 새 백업 레코드 생성")
            return CKRecord(recordType: "Backup", recordID: recordID)
        }
    }

    private func configureRecord(_ record: inout CKRecord, memosData: Data, smartClipboardData: Data,
                                combosData: Data, categoriesData: Data?) throws {
        record["memosAsset"] = try createAsset(from: memosData, filename: "memos.json")
        record["smartClipboardAsset"] = try createAsset(from: smartClipboardData, filename: "smartClipboard.json")
        record["combosAsset"] = try createAsset(from: combosData, filename: "combos.json")
        // 카테고리 설정(목록·아이콘·색·순서·숨김)은 App Group UserDefaults 에만 있어
        // 예전엔 백업에서 통째로 빠졌다 → 새 기기 복원 시 탭이 사라졌다.
        if let categoriesData {
            record["categoriesAsset"] = try createAsset(from: categoriesData, filename: "categories.json")
        }
        record["backupDate"] = Date() as CKRecordValue
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        record["version"] = appVersion as CKRecordValue
        AppLog.info(.backup, "💾 [CloudKit] 레코드 데이터 업데이트 완료")
    }

    /// 재시도 로직이 포함된 레코드 저장
    private func saveRecordWithRetry(_ record: CKRecord, maxRetries: Int) async throws -> CKRecord {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                AppLog.info(.backup, "💾 [CloudKit] 저장 시도 \(attempt)/\(maxRetries)...")
                let savedRecord = try await backend.database.save(record)
                AppLog.info(.backup, "✅ [CloudKit] 저장 성공 (시도 \(attempt))")
                return savedRecord
            } catch let error as CKError {
                lastError = error
                AppLog.warning(.backup, "⚠️ [CloudKit] 저장 실패 (시도 \(attempt)): \(error.code.rawValue)")

                // 재시도 가능한 에러인지 확인
                switch error.code {
                case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy, .requestRateLimited:
                    if attempt < maxRetries {
                        // 지수 백오프: 1초, 2초, 4초
                        let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                        AppLog.info(.backup, "   ⏳ \(attempt)초 후 재시도...")
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                default:
                    // 재시도 불가능한 에러는 즉시 throw
                    throw error
                }
            } catch {
                lastError = error
                throw error
            }
        }

        // 모든 재시도 실패
        throw lastError ?? CloudKitError.backupFailed(NSError(domain: "CloudKitBackup", code: -1))
    }

    // MARK: - Restore

    /// 로컬에 데이터가 있는지 확인
    func hasLocalData() -> Bool {
        do {
            let memos = try MemoStore.shared.load(type: .memo)
            let smartClipboard = try MemoStore.shared.loadSmartClipboardHistory()
            let combos = try MemoStore.shared.loadCombos()

            let totalCount = memos.count + smartClipboard.count + combos.count
            AppLog.info(.backup, "📊 [CloudKit] 로컬 데이터 확인: 메모 \(memos.count)개, 클립보드 \(smartClipboard.count)개, Combo \(combos.count)개")

            return totalCount > 0
        } catch {
            AppLog.warning(.backup, "⚠️ [CloudKit] 로컬 데이터 확인 실패: \(error)")
            return false
        }
    }

    /// 복원 (기존 데이터 덮어쓰기 여부를 외부에서 확인 필요)
    /// - Parameter forceOverwrite: true면 확인 없이 덮어쓰기, false면 호출 전에 hasLocalData()로 확인 필요
    // MARK: - Version Snapshots (타임머신)

    /// 보관 중인 버전 스냅샷 목록(최신순). 복원 화면의 날짜별 목록에 사용.
    func listSnapshots() async -> [BackupSnapshotInfo] {
        await loadSnapshotIndex()
    }

    /// 현재 iCloud 백업(최신 레코드)에 들어있는 메모 개수 - "무엇이 백업돼 있는지" 한눈에 확인용.
    func currentBackupMemoCount() async -> Int? {
        guard let record = try? await backend.database.record(for: CKRecord.ID(recordName: "TokenMemoBackup")) else { return nil }
        return Self.existingMemoCount(from: record)
    }

    /// 메인 백업 성공 후 타임스탬프 스냅샷을 따로 저장하고, 최신 maxSnapshots개만 남기고 정리한다.
    /// 단일 레코드를 덮어쓰던 구조의 약점(이전 백업 소실)을 보완 - 잘못된 백업이 끼어도 과거로 복원 가능.
    private func writeVersionSnapshot(memosData: Data, smartClipboardData: Data, combosData: Data,
                                      categoriesData: Data?,
                                      memos: [Memo], memoCount: Int, date: Date) async throws {
        let snapName = "TokenMemoBackup_snap_\(UUID().uuidString)"
        var snap = CKRecord(recordType: "BackupSnapshot", recordID: CKRecord.ID(recordName: snapName))
        // 스냅샷마다 고유 파일명으로 asset 생성(임시파일 충돌 방지).
        snap["memosAsset"] = try createAsset(from: memosData, filename: "\(snapName)_memos.json")
        snap["smartClipboardAsset"] = try createAsset(from: smartClipboardData, filename: "\(snapName)_smart.json")
        snap["combosAsset"] = try createAsset(from: combosData, filename: "\(snapName)_combos.json")
        // ⚠️ 카테고리도 함께. 이게 빠져 있어서 타임머신으로 되돌리면 탭이 다 사라졌다.
        if let categoriesData {
            snap["categoriesAsset"] = try createAsset(from: categoriesData, filename: "\(snapName)_categories.json")
        }
        snap["backupDate"] = date as CKRecordValue
        snap["memoCount"] = memoCount as CKRecordValue
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        snap["version"] = appVersion as CKRecordValue
        attachImages(to: &snap, memos: memos)
        _ = try await saveRecordWithRetry(snap, maxRetries: 2)

        // 인덱스 갱신 + 오래된 스냅샷 정리(최신 maxSnapshots개 유지).
        var infos = await loadSnapshotIndex()
        infos.append(BackupSnapshotInfo(recordName: snapName, date: date, memoCount: memoCount))
        infos.sort { $0.date > $1.date }
        let keep = Array(infos.prefix(maxSnapshots))
        // 정리 실패는 백업 자체를 실패시키지 않는다(이미 저장은 끝났다) - 대신 반드시 로그로 남긴다.
        // 삭제에 실패한 스냅샷은 인덱스에서 빠지므로 다시 정리되지 않는 고아 레코드로 남는다(용량만 차지, 데이터 손실 아님).
        for old in infos.dropFirst(maxSnapshots) {
            do {
                _ = try await backend.database.deleteRecord(withID: CKRecord.ID(recordName: old.recordName))
            } catch {
                AppLog.warning(.backup, "⚠️ [CloudKitBackupService.writeVersionSnapshot] 오래된 스냅샷 삭제 실패(\(old.recordName)), 고아 레코드로 남음: \(error.localizedDescription)")
            }
        }
        try await saveSnapshotIndex(keep)
        AppLog.info(.backup, "📚 [CloudKit] 버전 스냅샷 저장(메모 \(memoCount)개) · 보관 \(keep.count)개")
    }

    private func loadSnapshotIndex() async -> [BackupSnapshotInfo] {
        guard let record = try? await backend.database.record(for: snapshotIndexRecordID),
              let data = record["snapshots"] as? Data,
              let infos = try? JSONDecoder().decode([BackupSnapshotInfo].self, from: data) else {
            return []
        }
        return infos.sorted { $0.date > $1.date }
    }

    private func saveSnapshotIndex(_ infos: [BackupSnapshotInfo]) async throws {
        let record = (try? await backend.database.record(for: snapshotIndexRecordID))
            ?? CKRecord(recordType: "BackupIndex", recordID: snapshotIndexRecordID)
        record["snapshots"] = try JSONEncoder().encode(infos) as CKRecordValue
        _ = try await saveRecordWithRetry(record, maxRetries: 2)
    }

    /// - Parameter snapshotName: 특정 버전 스냅샷에서 복원할 때 그 레코드명. nil이면 최신 백업.
    func restoreData(forceOverwrite: Bool = false, snapshotName: String? = nil) async throws {
        AppLog.info(.backup, "☁️ [CloudKit] 복구 시작... (스냅샷=\(snapshotName ?? "최신"))")

        try await ensureAuthenticated()

        if !forceOverwrite && hasLocalData() {
            AppLog.warning(.backup, "⚠️ [CloudKit] 기존 데이터 존재 - 사용자 확인 필요")
            throw CloudKitError.restoreFailed(
                NSError(domain: "CloudKitBackup", code: -2, userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString(
                        "기존 데이터가 있습니다. 복원하면 현재 데이터가 모두 삭제됩니다. 계속하시겠습니까?",
                        comment: "Restore confirmation message"
                    )
                ])
            )
        }

        await MainActor.run { isRestoring = true }
        defer { Task { @MainActor [weak self] in self?.isRestoring = false } }

        do {
            let recordID = CKRecord.ID(recordName: snapshotName ?? "TokenMemoBackup")
            let record = try await backend.database.record(for: recordID)
            AppLog.info(.backup, "📦 [CloudKit] 백업 레코드 찾음")
            if let version = record["version"] as? String {
                AppLog.info(.backup, "📦 [CloudKit] 백업 버전: \(version)")
            }

            let memos = try fetchMemos(from: record)
            let smartClipboard = fetchSmartClipboardHistory(from: record)
            let combos = fetchStacks(from: record)

            // 메모 본문을 저장하기 전에 첨부 이미지를 Images/에 먼저 복원(깨진 참조 방지).
            restoreImages(from: record)
            try saveRestoredData(memos: memos, smartClipboard: smartClipboard, combos: combos)
            // 카테고리는 메모를 저장한 **뒤에** 복원한다 - 옛 백업 폴백이 메모의
            // category 값을 읽어 역산하므로 메모가 먼저 자리를 잡아야 한다.
            restoreCategories(from: record, memos: memos)
            // 카테고리는 `.memoDataChanged` 로 안 딸려 온다(그건 memos.data 이야기다).
            // 여기서 알려야 `CategoryStore` 와 목록이 되살린 값을 다시 읽는다.
            // ⚠️ 부르는 쪽에 맡기지 않는다. 복원 경로가 늘 때마다 빠뜨리게 된다.
            NotificationCenter.postOnMain(name: .dataRestored)
            AppLog.info(.backup, "🎉 [CloudKit] 전체 복구 완료!")

        } catch let error as CKError where error.code == .unknownItem {
            AppLog.error(.backup, "❌ [CloudKit] 백업 데이터 없음")
            throw CloudKitError.noBackupFound
        } catch {
            AppLog.error(.backup, "❌ [CloudKit] 복구 실패: \(error)")
            throw CloudKitError.restoreFailed(error)
        }
    }

    // MARK: - restoreData Helpers

    /// 카테고리 설정 복원.
    /// ① 백업에 `categoriesAsset` 이 있으면 그대로 적용(순서·아이콘·숨김까지 살아난다)
    /// ② 없으면(= 이 기능 이전에 만든 옛 백업) 메모의 `category` 값에서 이름만 역산해 구제
    private func restoreCategories(from record: CKRecord, memos: [Memo]) {
        if let asset = record["categoriesAsset"] as? CKAsset,
           let data = try? readAsset(asset),
           let snapshot = try? JSONDecoder().decode(CategorySnapshot.self, from: data),
           !snapshot.isEmpty {
            // 복원은 "이 백업 상태로 되돌린다"는 뜻이므로 순서까지 그대로 가져온다.
            CategorySnapshotStore.apply(snapshot, strategy: .replace)
            AppLog.info(.backup, "🗂 [CloudKit] 카테고리 설정 복원: \(snapshot.categories.count)개")
            return
        }

        let rebuilt = CategorySnapshotStore.rebuildFromMemos(memos)
        if rebuilt.isEmpty {
            AppLog.info(.backup, "🗂 [CloudKit] 백업에 카테고리 정보 없음. 메모에서도 복구할 것 없음")
        } else {
            AppLog.info(.backup, "🗂 [CloudKit] 옛 백업, 메모에서 카테고리 \(rebuilt.count)개 복구")
        }
    }

    private func fetchMemos(from record: CKRecord) throws -> [Memo] {
        var memosData: Data?

        if let asset = record["memosAsset"] as? CKAsset {
            memosData = try? readAsset(asset)
            AppLog.info(.backup, "📦 [CloudKit] 메모 데이터 (Asset): \(memosData != nil ? "성공" : "실패")")
        }
        if memosData == nil, let legacyData = record["memos"] as? Data {
            memosData = legacyData
            AppLog.info(.backup, "📦 [CloudKit] 메모 데이터 (레거시): 성공")
        }

        guard let data = memosData else {
            AppLog.error(.backup, "❌ [CloudKit] 메모 데이터 없음")
            throw CloudKitError.noBackupFound
        }
        guard let memos = try? JSONDecoder().decode([Memo].self, from: data) else {
            AppLog.error(.backup, "❌ [CloudKit] 메모 디코딩 실패")
            throw CloudKitError.decodingFailed
        }
        AppLog.info(.backup, "📦 [CloudKit] 복구할 메모: \(memos.count)개")
        return memos
    }

    private func fetchSmartClipboardHistory(from record: CKRecord) -> [SmartClipboardHistory] {
        if let asset = record["smartClipboardAsset"] as? CKAsset,
           let data = try? readAsset(asset),
           let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: data) {
            AppLog.info(.backup, "📦 [CloudKit] 복구할 스마트 클립보드 (Asset): \(decoded.count)개")
            return decoded
        }
        if let legacyData = record["smartClipboardHistory"] as? Data,
           let decoded = try? JSONDecoder().decode([SmartClipboardHistory].self, from: legacyData) {
            AppLog.info(.backup, "📦 [CloudKit] 복구할 스마트 클립보드 (레거시): \(decoded.count)개")
            return decoded
        }
        AppLog.info(.backup, "ℹ️ [CloudKit] 스마트 클립보드 데이터 없음")
        return []
    }

    private func fetchStacks(from record: CKRecord) -> [Combo] {
        if let asset = record["combosAsset"] as? CKAsset,
           let data = try? readAsset(asset),
           let decoded = try? JSONDecoder().decode([Combo].self, from: data) {
            AppLog.info(.backup, "📦 [CloudKit] 복구할 Combo (Asset): \(decoded.count)개")
            return decoded
        }
        if let legacyData = record["combos"] as? Data,
           let decoded = try? JSONDecoder().decode([Combo].self, from: legacyData) {
            AppLog.info(.backup, "📦 [CloudKit] 복구할 Combo (레거시): \(decoded.count)개")
            return decoded
        }
        AppLog.info(.backup, "ℹ️ [CloudKit] Combo 데이터 없음")
        return []
    }

    private func saveRestoredData(
        memos: [Memo],
        smartClipboard: [SmartClipboardHistory],
        combos: [Combo]
    ) throws {
        AppLog.info(.backup, "💾 [CloudKit] 로컬 저장 시작...")
        try MemoStore.shared.save(memos: memos, type: .memo)
        AppLog.info(.backup, "✅ [CloudKit] 메모 \(memos.count)개 저장 완료")

        if !smartClipboard.isEmpty {
            try MemoStore.shared.saveSmartClipboardHistory(history: smartClipboard)
            AppLog.info(.backup, "✅ [CloudKit] 스마트 클립보드 \(smartClipboard.count)개 저장 완료")
        }
        if !combos.isEmpty {
            try MemoStore.shared.saveCombos(combos)
            AppLog.info(.backup, "✅ [CloudKit] Combo \(combos.count)개 저장 완료")
        }

        // 옛 백업을 복원하면 레거시 포맷(combos.data / isStack / attachedTemplateId)이 되살아날 수 있다.
        // 콤보 통합 마이그레이션 플래그를 리셋해 다음 실행 시 신 모델(childMemoIds)로 재변환되게 한다.
        // (마이그레이션은 hasLegacyComboData()로도 자동 감지하지만, 플래그 리셋으로 명시 보장.)
        AppGroup.defaults?
            .set(false, forKey: DefaultsKey.comboModelUnifyMigratedV1)
    }

    // MARK: - Check Backup Existence

    func hasBackup() async -> Bool {
        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            _ = try await backend.database.record(for: recordID)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Delete Backup

    func deleteBackup() async throws {
        AppLog.info(.backup, "🗑️ [CloudKit] 백업 삭제 시작...")

        do {
            let recordID = CKRecord.ID(recordName: "TokenMemoBackup")
            _ = try await backend.database.deleteRecord(withID: recordID)

            await MainActor.run {
                lastBackupDate = nil
                UserDefaults.standard.removeObject(forKey: DefaultsKey.lastBackupDate)
            }

            AppLog.info(.backup, "✅ [CloudKit] 백업 삭제 완료")
        } catch {
            AppLog.error(.backup, "❌ [CloudKit] 백업 삭제 실패: \(error)")
            throw error
        }
    }
}
