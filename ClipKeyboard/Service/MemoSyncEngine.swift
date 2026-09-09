//
//  MemoSyncEngine.swift
//  ClipKeyboard
//
//  메모 실시간 동기화(iPhone ↔ Mac) - CKSyncEngine 기반 레코드 단위 동기화.
//  로컬 JSON 저장소(MemoStore)는 그대로 두고, 그 위에서 CloudKit 프라이빗 DB의
//  커스텀 존을 동기화한다. 충돌은 id 단위 최신 우선 + 툼스톤(소프트 삭제)으로 해결.
//  순수 로직은 MemoSyncCore(단위 테스트 완비), 여기서는 CloudKit 연결만 담당한다.
//  iOS·macOS(.tap) 두 타겟이 공유한다(AppGroup.swift 패턴).
//
//  ⚠️ 기본 비활성(MemoSyncFlags.enabled = false). Pro + 플래그 ON일 때만 start().
//

import Foundation
import CloudKit
import CryptoKit   // 카테고리 스냅샷 지문(SHA256) - 실행 간 안정적인 해시가 필요하다
import os

enum MemoSyncFlags {
    /// 마스터 스위치. **이 기기의 값만** 본다(App Group).
    ///
    /// ⚠️ 예전에는 iCloud KV 값도 함께 봤다. 그런데 KV 는 **앱을 지워도 남고 계정을 따라
    ///    다닌다.** 그래서 앱을 지웠다 깐 사람, 새 아이폰을 켠 사람의 **첫 실행**에 이미
    ///    켜져 있었고, 런치가 끝나기도 전에 엔진이 원격을 통째로 당겨왔다.
    ///    "기존 단축어를 불러올까요"에 **나중에**를 눌러도 이미 들어와 있던 이유가 이것이다.
    ///    (설정의 토글은 App Group 값을 그리므로 화면에는 꺼짐으로 보였다. 보이는 것과
    ///     도는 것이 어긋난 셈이다.)
    ///
    /// ⚠️ 남의 데이터를 이 기기로 당겨오는 일은 **이 기기에서 예라고 한 뒤**에만 한다.
    ///    다른 기기의 설정은 "이 기능을 원한다"는 뜻이지, 아직 아무것도 담기지 않은
    ///    기기가 계정 전체를 내려받아도 좋다는 뜻이 아니다.
    static var enabled: Bool {
        AppGroup.defaults?.bool(forKey: DefaultsKey.memoSyncEnabled) == true
    }

    /// 토글 시 양쪽(App Group + iCloud KV)에 기록 - 다른 기기로 전파.
    static func setEnabled(_ on: Bool) {
        AppGroup.defaults?.set(on, forKey: DefaultsKey.memoSyncEnabled)
        // 사람이 이 기기에서 직접 골랐다 - 아래 승계 판정이 이 선택을 덮지 않도록 못박는다.
        AppGroup.defaults?.set(true, forKey: DefaultsKey.memoSyncCloudAdoptedV1)
        NSUbiquitousKeyValueStore.default.set(on, forKey: DefaultsKey.memoSyncEnabled)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    /// iCloud KV 에 켜져 있는 설정을 **이 기기가 이어받을지** 한 번만 판정한다.
    ///
    /// 이어받는 경우는 하나뿐이다: **이 기기가 이미 동기화를 돌린 적이 있다.**
    /// 그 표식(마지막 수신·전송 시각)이 남아 있다면 이 기기에는 이미 계정 데이터가 있고,
    /// 더 받아온다고 놀랄 일이 없다. 켜 둔 채로 업데이트한 사람의 동기화가 이 변경으로
    /// 조용히 멎지 않게 하는 것이 이 함수의 몫이다.
    ///
    /// 갓 설치한 기기에는 그 표식이 없다 - 그래서 아무것도 이어받지 않고, 사람이
    /// 설정에서 직접 켤 때까지 엔진은 잠들어 있다.
    static func adoptCloudPreferenceIfNeeded() {
        guard let defaults = AppGroup.defaults else { return }
        guard !defaults.bool(forKey: DefaultsKey.memoSyncCloudAdoptedV1) else { return }
        defaults.set(true, forKey: DefaultsKey.memoSyncCloudAdoptedV1)

        guard NSUbiquitousKeyValueStore.default.bool(forKey: DefaultsKey.memoSyncEnabled) else { return }

        let hasSyncedHere = defaults.object(forKey: DefaultsKey.syncLastPullAt) != nil
            || defaults.object(forKey: DefaultsKey.syncLastPushAt) != nil
        guard hasSyncedHere else {
            print("🔒 [MemoSync] iCloud 설정은 켜져 있지만 이 기기는 처음이다. 사람이 켤 때까지 쉰다")
            return
        }
        defaults.set(true, forKey: DefaultsKey.memoSyncEnabled)
        print("🔄 [MemoSync] 이미 동기화하던 기기, iCloud 설정 승계")
    }
}

/// 동기화가 실제로 돌고 있는지 보여주기 위한 최소 기록.
/// "지금 다른 기기(아이폰) 데이터를 받아오고 있나?"에 답하는 화면(맥 앱의 동기화 상태)이 이 값을 읽는다.
/// 마지막 수신/전송/확인/오류는 App Group에 남겨 앱을 다시 켜도 유지되고,
/// 엔진 실행 여부만 프로세스 메모리에 둔다(실행 때마다 새로 시작하므로).
enum MemoSyncStatus {
    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 이번 실행에서 엔진이 시작됐는지 - false면 게이트(플래그/Pro)에 막혀 아예 안 돌고 있는 것.
    nonisolated(unsafe) private static var running = false
    static var isRunning: Bool { running }

    /// 마지막으로 원격 변경을 이 기기에 적용한 시각과 건수 - "받아오고 있다"의 직접 증거.
    static var lastPullAt: Date? { defaults?.object(forKey: DefaultsKey.syncLastPullAt) as? Date }
    static var lastPullCount: Int { defaults?.integer(forKey: DefaultsKey.syncLastPullCount) ?? 0 }
    /// 마지막으로 이 기기 변경을 올린 시각과 건수.
    static var lastPushAt: Date? { defaults?.object(forKey: DefaultsKey.syncLastPushAt) as? Date }
    static var lastPushCount: Int { defaults?.integer(forKey: DefaultsKey.syncLastPushCount) ?? 0 }
    /// 받을 게 없어도 갱신되는 마지막 확인 시각 - 연결이 살아있다는 근거.
    static var lastCheckAt: Date? { defaults?.object(forKey: DefaultsKey.syncLastCheckAt) as? Date }
    /// 마지막 오류(성공하면 지워진다).
    static var lastError: String? { defaults?.string(forKey: DefaultsKey.syncLastError) }
    static var lastErrorAt: Date? { defaults?.object(forKey: DefaultsKey.syncLastErrorAt) as? Date }

    // MARK: - 기록 (엔진 전용)

    static func markRunning() { running = true }

    static func recordPull(count: Int, at date: Date = Date()) {
        defaults?.set(date, forKey: DefaultsKey.syncLastPullAt)
        defaults?.set(count, forKey: DefaultsKey.syncLastPullCount)
    }

    static func recordPush(count: Int, at date: Date = Date()) {
        defaults?.set(date, forKey: DefaultsKey.syncLastPushAt)
        defaults?.set(count, forKey: DefaultsKey.syncLastPushCount)
    }

    static func recordCheck(at date: Date = Date()) {
        defaults?.set(date, forKey: DefaultsKey.syncLastCheckAt)
    }

    static func recordError(_ message: String, at date: Date = Date()) {
        defaults?.set(message, forKey: DefaultsKey.syncLastError)
        defaults?.set(date, forKey: DefaultsKey.syncLastErrorAt)
    }

    static func clearError() {
        defaults?.removeObject(forKey: DefaultsKey.syncLastError)
        defaults?.removeObject(forKey: DefaultsKey.syncLastErrorAt)
    }
}

@available(iOS 17.0, macOS 14.0, *)
final class MemoSyncEngine: NSObject, CKSyncEngineDelegate {
    static let shared = MemoSyncEngine()

    private let log = Logger(subsystem: "com.Ysoup.TokenMemo", category: "MemoSync")
    private let containerID = "iCloud.com.Ysoup.TokenMemo"
    static let zoneName = "MemosZone"
    static let recordType = "Memo"

    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // 싱글톤 직렬 사용(메인 흐름 + CKSyncEngine 콜백). Sendable 경고 의도적 수용.
    nonisolated(unsafe) private var engine: CKSyncEngine?
    nonisolated(unsafe) private var started = false
    /// 배선을 만드는 중인 작업. `engine` 이 생기는 시점이 `startIfEnabled()` 리턴보다
    /// 뒤이므로, 곧바로 이어지는 `syncNow()` 가 이걸 기다렸다가 엔진을 본다.
    nonisolated(unsafe) private var startTask: Task<Void, Never>?
    /// 원격 변경을 로컬에 적용하는 동안 true - 이 사이의 .memoDataChanged는 무시(에코 루프 차단).
    nonisolated(unsafe) private var isApplyingRemoteChanges = false

    private var defaults: UserDefaults? { AppGroup.defaults }

    // MARK: - Lifecycle

    /// 권한 + 플래그가 켜져 있을 때만 동기화를 시작한다. 멱등. (맥은 권한 게이트 없음)
    func startIfEnabled() {
        // 켜 둔 채로 업데이트한 기기를 먼저 건져낸다 - 게이트를 보기 전에 한 번만 돈다.
        MemoSyncFlags.adoptCloudPreferenceIfNeeded()
        guard MemoSyncFlags.enabled else { log.info("sync disabled by flag"); return }
        // 원격 킬스위치 - 동기화가 사고를 냈을 때 심사 없이 끌 수 있는 경로.
        // 조회 실패 시엔 true(켬)라 네트워크가 없다고 동기화가 막히지는 않는다.
        guard RemoteFlagsService.cachedValue(.syncEnabled) else {
            log.info("sync disabled by remote flag"); return
        }
        guard hasSyncEntitlement else { log.info("sync gated: no entitlement"); return }
        guard !started else { return }
        // ⚠️ 실제 시작은 아래 Task 안에서 끝나지만, 이 표식은 **여기서** 세운다.
        //    포그라운드 복귀가 잇따라 오면 Task 가 뜨기 전에 다시 불릴 수 있고,
        //    그러면 엔진이 두 개 만들어진다.
        started = true
        MemoSyncStatus.markRunning()

        // ⚠️ **CloudKit 배선을 메인 스레드에서 만들지 않는다.**
        //    `CKContainer(identifier:)` 도 `CKSyncEngine(_:)` 도 cloudd 와 XPC 를 주고받는다.
        //    이 메서드는 런치 시퀀스와 포그라운드 복귀(`scenePhase == .active`) 양쪽에서
        //    메인 액터로 불리는데, 그 자리에서 데몬이 대답하지 않으면 화면이 통째로 멈춘다.
        //    같은 종류의 한 줄이 4.4.6 런치를 22초 붙잡아 워치독에 죽었다.
        //    기록: docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md
        startTask = Task { [weak self] in
            guard let self else { return }
            let database = await CloudKitContainer.privateDatabase(self.containerID)
            let config = CKSyncEngine.Configuration(
                database: database,
                stateSerialization: self.loadState(),
                delegate: self
            )
            let engine = CKSyncEngine(config)
            self.engine = engine
            // 존 생성(이미 있으면 무시됨) - CKSyncEngine이 처리.
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: self.zoneID))])

            NotificationCenter.default.addObserver(
                self, selector: #selector(self.localDataChanged),
                name: .memoDataChanged, object: nil)

            self.log.info("MemoSyncEngine started")
            // 시작 시 한 번: 로컬 미동기 변경을 큐에 올리고, 원격을 당겨온다.
            self.enqueueLocalChanges()
            try? await engine.fetchChanges()
        }
    }

    /// 동기화 권한 - ProFeatureManager의 키를 직접 읽어 양 타겟 의존을 피한다.
    ///
    /// ⚠️ **맥은 게이트가 없다.** 맥 앱은 스토어 유료 다운로드라 구매 자체가 전체 권한이다
    ///    (`ClipKeyboardTapSpec.monetization = .paidUpfront`). 아이폰 결제 키를 보던 시절엔
    ///    맥만 산 사용자가 토글을 켜도 엔진이 조용히 거부해 아무것도 올라가지 않았다.
    ///
    /// ⚠️ 결제 키(`proStatus`) 하나만 보면 안 된다. 이 앱은 **결제 외 경로**로도 전체 접근 권한을 준다:
    /// v4.0 이전 유료 구매자(`wasProAtV3`) · v3.x 기존 사용자(`existingFreeUser`) · TestFlight/체험
    /// (`syncEntitled` 로 미러링). 설정의 동기화 토글은 `hasFullAccess` 로 열리는데 엔진만 결제를
    /// 요구하던 탓에, 그랜드파더 사용자는 **토글이 켜져 있는데도 엔진이 조용히 거부**해
    /// 아이폰에서 아무것도 올라가지 않았다.
    private var hasSyncEntitlement: Bool {
        #if os(macOS)
        return true
        #else
        // App Group + iCloud KV 어느 쪽이든 켜져 있으면 인정(기존 백업 게이팅과 동일 취지).
        let keys = [DefaultsKey.proStatus, DefaultsKey.wasProAtV3,
                    DefaultsKey.existingFreeUser, DefaultsKey.syncEntitled]
        for key in keys {
            if defaults?.bool(forKey: key) == true { return true }
            if NSUbiquitousKeyValueStore.default.bool(forKey: key) { return true }
        }
        return false
        #endif
    }

    /// 외부(포그라운드/푸시)에서 즉시 동기화를 요청.
    ///
    /// ⚠️ 엔진이 아직 만들어지는 중일 수 있다. 배선을 메인 스레드 밖으로 옮긴 뒤로
    ///    `startIfEnabled()` 는 엔진을 만들기 전에 리턴한다. 기다리지 않으면 콜드 런치
    ///    직후 첫 요청이 조용히 아무 일도 안 하고 끝난다.
    func syncNow() {
        Task { [weak self] in
            guard let self else { return }
            await self.startTask?.value
            guard let engine = self.engine else { return }
            self.enqueueLocalChanges()
            try? await engine.fetchChanges()
            try? await engine.sendChanges()
        }
    }

    // MARK: - Local change detection (push)

    @objc private func localDataChanged() {
        guard !isApplyingRemoteChanges else { return }
        enqueueLocalChanges()
    }

    /// 동기화 대상 메모 - **시드 샘플은 제외한다.**
    ///
    /// ⚠️ 샘플은 기기마다 **새 UUID로** 심기고 내용이 기기 언어를 따른다(영어 폰은 영어 샘플,
    ///    한국어 폰은 한국어 샘플). 그대로 올리면 동기화가 서로 다른 메모로 보고 양쪽에
    ///    퍼뜨려서, 폰 2대를 쓰거나 맥·아이폰을 함께 쓰면 "모르는 단축어가 섞여" 보인다.
    ///    샘플은 온보딩 장식이지 사용자 데이터가 아니다 - 백업도 이미 실데이터에서 제외한다.
    ///
    /// ⚠️ **병합(applyFetched)의 기준 목록에는 쓰지 말 것.** 거기서 샘플을 빼면
    ///    병합 결과를 저장할 때 로컬 샘플이 통째로 지워진다. 업로드 산출에만 쓴다.
    private func syncableMemos() -> [Memo] {
        let all = (try? MemoStore.shared.load(type: .memo)) ?? []
        let sampleIDs = SampleMemoStorage.load()
        guard !sampleIDs.isEmpty else { return all }
        return all.filter { !sampleIDs.contains($0.id) }
    }

    private func enqueueLocalChanges() {
        guard let engine else { return }
        enqueueCategorySettingsIfChanged()

        let current = syncableMemos()
        let changes = MemoSyncCore.localChanges(
            current: current, shadow: loadShadow(),
            knownTombstones: loadTombstones(), now: Date())
        guard !changes.isEmpty else { return }

        var tombstones = loadTombstones()
        for (id, at) in changes.newTombstones { tombstones[id] = at }
        // 살아있는 단축어의 툼스톤은 남아 있으면 안 된다 - 남으면 그 id 로 오는 원격 메모를
        // "이미 지운 것"으로 보고 계속 무시한다(되살린 단축어가 다른 기기에서 안 보이는 원인).
        let aliveIDs = Set(((try? MemoStore.shared.load(type: .memo)) ?? []).map(\.id))
        tombstones = tombstones.filter { !aliveIDs.contains($0.key) }
        saveTombstones(tombstones)

        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        for memo in changes.upserts { pending.append(.saveRecord(recordID(memo.id))) }
        for id in changes.newTombstones.keys { pending.append(.saveRecord(recordID(id))) }
        engine.state.add(pendingRecordZoneChanges: pending)

        // ⚠️ 여기서 섀도를 갱신하지 않는다 - 서버 저장이 확정된 뒤(confirmSent)에만 기록한다.
        // 예전엔 큐에 넣자마자 갱신해서, 전송 전에 앱이 종료되면 큐는 사라지고 섀도는 "보냄"으로
        // 남아 그 변경이 **영영 재전송되지 않았다**(메모를 다시 고치기 전까지 조용히 누락).
        log.info("enqueued \(changes.upserts.count) upserts, \(changes.newTombstones.count) deletes")
    }

    // MARK: - CKSyncEngineDelegate

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let e):
            saveState(e.stateSerialization)
        case .fetchedRecordZoneChanges(let e):
            await applyFetched(modifications: e.modifications.map { $0.record },
                               deletionIDs: e.deletions.map { $0.recordID })
        case .sentRecordZoneChanges(let e):
            if !e.failedRecordSaves.isEmpty {
                log.error("failed record saves: \(e.failedRecordSaves.count)")
                if let first = e.failedRecordSaves.first {
                    MemoSyncStatus.recordError(first.error.localizedDescription)
                }
                handleFailedSaves(e.failedRecordSaves, syncEngine: syncEngine)
            }
            let sent = e.savedRecords.count + e.deletedRecordIDs.count
            if sent > 0 { MemoSyncStatus.recordPush(count: sent) }
            // 서버가 돌려준 레코드의 변경 태그를 기억해 둔다 - 다음 수정·삭제가 거절당하지 않으려면 필수.
            cacheRecordMetas(e.savedRecords)
            // 서버 저장이 확정된 것만 섀도에 반영한다.
            if !e.savedRecords.isEmpty { confirmSent(e.savedRecords) }
        case .sentDatabaseChanges(let e):
            // 존(MemosZone) 생성 실패가 여기로 온다 - Production 스키마 미배포처럼
            // "아무것도 못 올리는" 상황의 유일한 단서라 반드시 기록한다.
            if let failure = e.failedZoneSaves.first {
                log.error("failed zone save: \(failure.error.localizedDescription)")
                MemoSyncStatus.recordError(failure.error.localizedDescription)
            }
        case .didFetchRecordZoneChanges(let e):
            // 존 단위 fetch 결과 - 성공하면 이전 오류를 지워 상태 화면이 낡은 오류를 보여주지 않게 한다.
            if let error = e.error {
                log.error("fetch zone changes failed: \(error.localizedDescription)")
                MemoSyncStatus.recordError(error.localizedDescription)
            } else {
                MemoSyncStatus.clearError()
            }
        case .didFetchChanges:
            // 받을 변경이 없어도 도달한다 - "언제 마지막으로 확인했는지"의 근거.
            MemoSyncStatus.recordCheck()
        case .accountChange(let e):
            handleAccountChange(e)
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                   syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        let current = syncableMemos()
        let byId = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let tombstones = loadTombstones()

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [weak self] recordID in
            guard let self else { return nil }
            // 카테고리 설정은 UUID 가 아닌 고정 이름이라 메모 경로보다 먼저 가른다.
            if recordID.recordName == Self.categoryRecordName {
                return self.makeCategoryRecord()
            }
            guard let id = UUID(uuidString: recordID.recordName) else { return nil }
            if let memo = byId[id] {
                return self.makeRecord(id: recordID, memo: memo, deletedAt: nil)
            } else if let at = tombstones[id] {
                return self.makeRecord(id: recordID, memo: nil, deletedAt: at)
            } else {
                // 양쪽에서 사라짐 - 보낼 게 없으니 큐에서 제거.
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
        }
    }

    /// 서버 저장이 확정된 레코드만 섀도에 기록한다 - 확정 전에는 계속 "보낼 것"으로 남겨 재시도되게 한다.
    private func confirmSent(_ records: [CKRecord]) {
        let current = syncableMemos()
        let byId = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        var shadow = loadShadow()
        for record in records {
            // 카테고리 설정 업로드 확정 - 지문을 기록해 같은 내용이 다시 올라가지 않게 한다.
            if record.recordID.recordName == Self.categoryRecordName {
                AppGroup.defaults?
                    .set(categoryFingerprint(currentSyncableCategories()), forKey: Self.categoryShadowKey)
                continue
            }
            guard let id = UUID(uuidString: record.recordID.recordName) else { continue }
            if let memo = byId[id] {
                shadow[id] = MemoSyncCore.fingerprint(memo)
            } else {
                shadow.removeValue(forKey: id)   // 툼스톤 확정 - 살아있는 목록에 없음
            }
        }
        saveShadow(shadow)
    }

    // MARK: - Apply remote → local

    private func applyFetched(modifications: [CKRecord], deletionIDs: [CKRecord.ID]) async {
        guard !modifications.isEmpty || !deletionIDs.isEmpty else { return }
        // 서버 버전을 기억해 둔다 - 이 기기가 나중에 이 레코드를 고치거나 지울 때 필요하다.
        cacheRecordMetas(modifications)

        var remotes: [RemoteMemo] = []
        for record in modifications {
            // 카테고리 설정 레코드는 메모가 아니므로 따로 처리하고 넘어간다.
            if record.recordID.recordName == Self.categoryRecordName {
                applyRemoteCategories(record)
                continue
            }
            guard let id = UUID(uuidString: record.recordID.recordName) else { continue }
            if let deletedAt = record["deletedAt"] as? Date {
                remotes.append(RemoteMemo(id: id, memo: nil, lastEdited: deletedAt))
            } else if let payload = record["payload"] as? Data,
                      let memo = try? JSONDecoder().decode(Memo.self, from: payload) {
                // 메모 본문을 적용하기 전에 첨부 이미지를 먼저 Images/에 기록(깨진 참조 방지).
                writeImages(from: record)
                remotes.append(RemoteMemo(id: id, memo: memo, lastEdited: memo.lastEdited))
            }
        }
        // 하드 삭제(존재 시) - deletedAt 정보가 없으므로 distantFuture로 처리해 삭제 우선.
        for recordID in deletionIDs {
            forgetRecordMeta(recordID)   // 서버에서 사라진 레코드의 태그는 들고 있으면 안 된다
            guard let id = UUID(uuidString: recordID.recordName) else { continue }
            remotes.append(RemoteMemo(id: id, memo: nil, lastEdited: Date()))
        }

        let local = (try? MemoStore.shared.load(type: .memo)) ?? []
        let result = MemoSyncCore.merge(local: local, localTombstones: loadTombstones(), remote: remotes)

        isApplyingRemoteChanges = true
        // ⚠️ 저장이 보내는 .memoDataChanged 는 **메인 큐에 예약**돼 이 함수가 끝난 뒤 도착한다.
        //    여기서 곧바로 false 로 되돌리면 그 알림이 "로컬 변경"으로 오해돼 방금 받은 것을
        //    되올린다(에코). 예약된 알림이 다 지나간 뒤에 풀어 준다.
        defer { DispatchQueue.main.async { self.isApplyingRemoteChanges = false } }

        // ⚠️ 저장에 실패하면 **섀도/툼스톤을 갱신하면 안 된다.**
        //    갱신해 버리면 "이미 반영했다"고 기록되어 다음 동기화에서 이 원격 변경을
        //    다시 받아오지 않는다 → 사용자 눈에는 데이터가 조용히 사라진 것으로 보인다.
        //    실패 시엔 그대로 두어 다음 동기화가 다시 시도하게 한다.
        do {
            try MemoStore.shared.save(memos: result.memos, type: .memo)
        } catch {
            log.error("원격 병합 결과 저장 실패, 섀도 갱신을 건너뛰고 다음 동기화에서 재시도: \(error.localizedDescription, privacy: .public)")
            return
        }
        saveTombstones(result.tombstones)
        // ⚠️ 섀도는 **올릴 대상과 같은 목록**(시드 샘플 제외)으로 만들어야 한다.
        //    전체로 만들면 다음 비교에서 샘플이 "사라진 단축어"로 잡혀 엉뚱한 툼스톤이 올라간다.
        let sampleIDs = SampleMemoStorage.load()
        let syncable = sampleIDs.isEmpty ? result.memos : result.memos.filter { !sampleIDs.contains($0.id) }
        saveShadow(MemoSyncCore.buildShadow(syncable))

        // 로컬이 이긴 항목(원격 삭제를 로컬 최신편집이 덮음)은 다시 올린다.
        if let engine, !result.toReupload.isEmpty {
            engine.state.add(pendingRecordZoneChanges: result.toReupload.map { .saveRecord(recordID($0.id)) })
        }

        MemoSyncStatus.recordPull(count: remotes.count)
        NotificationCenter.postOnMain(name: .dataRestored)
        log.info("applied remote: \(remotes.count) records → \(result.memos.count) local memos")
    }

    private func handleAccountChange(_ event: CKSyncEngine.Event.AccountChange) {
        // 로그아웃/계정 전환 시 로컬 상태는 보존(파괴하지 않음). 상태만 초기화해 재시작에 대비.
        log.info("account change: \(String(describing: event.changeType))")
    }

    // MARK: - Record materialization

    private func recordID(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
    }

    /// memo가 있으면 살아있는 레코드, nil이면 툼스톤(deletedAt 설정, payload 없음).
    /// 첨부 이미지(PNG)는 메모 레코드에 CKAsset 배열로 함께 올린다(메모와 원자적으로 이동).
    ///
    /// ⚠️ **반드시 서버가 준 레코드(변경 태그) 위에 얹어 올린다.** 태그 없는 새 CKRecord 로
    ///    이미 있는 레코드를 저장하면 CloudKit 이 `serverRecordChanged` 로 거절한다.
    ///    예전엔 매번 새 레코드를 만들었던 탓에 **첫 업로드만 성공하고, 그 뒤의 수정·삭제는
    ///    조용히 버려졌다**. 아이폰에서 지운 단축어가 맥에서 영영 안 사라지고,
    ///    고친 내용도 반대편에 반영되지 않았다(사용자 눈엔 "추가만 되는 동기화").
    private func makeRecord(id: CKRecord.ID, memo: Memo?, deletedAt: Date?) -> CKRecord? {
        let record = cachedRecord(for: id) ?? CKRecord(recordType: Self.recordType, recordID: id)
        if let memo, let payload = try? JSONEncoder().encode(memo) {
            record["payload"] = payload as CKRecordValue
            record["lastEdited"] = memo.lastEdited as CKRecordValue
            record["deletedAt"] = nil          // 되살린 경우 - 툼스톤 표시를 지운다
            attachImages(of: memo, to: record)
        } else if let deletedAt {
            record["deletedAt"] = deletedAt as CKRecordValue
            record["lastEdited"] = deletedAt as CKRecordValue
            // 툼스톤엔 본문·이미지를 남기지 않는다(용량 + 실수로 되살아나는 것 방지).
            record["payload"] = nil
            record["images"] = nil
            record["imageNames"] = nil
        } else {
            return nil
        }
        return record
    }

    // MARK: - 서버 레코드 메타(변경 태그) 캐시
    //
    // CloudKit 은 "내가 알고 있는 서버 버전" 위에서만 덮어쓰기를 허용한다. 그 버전을 알려면
    // 서버가 준 레코드의 **시스템 필드**(recordID·타입·변경 태그)를 보관했다가 재사용해야 한다.
    // 값 필드는 담기지 않으므로(암호화된 payload 포함) 여기 저장해도 내용이 새지 않는다.

    private static let recordMetaKey = "memo.sync.recordMeta"
    /// serverRecordChanged 재시도 횟수 - 서버와 계속 어긋날 때 무한 재전송을 막는다.
    nonisolated(unsafe) private var conflictRetries: [String: Int] = [:]
    private static let maxConflictRetries = 3

    /// 디스크(App Group)에 있는 것과 같은 내용의 메모리 사본.
    /// 배치 전송은 레코드마다 조회하므로, 매번 디스크에서 통째로 디코드하면 건수² 로 느려진다.
    nonisolated(unsafe) private var recordMetaCache: [String: Data]?

    private func loadRecordMeta() -> [String: Data] {
        if let recordMetaCache { return recordMetaCache }
        let raw: [String: Data]
        if let data = defaults?.data(forKey: Self.recordMetaKey),
           let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            raw = decoded
        } else {
            raw = [:]
        }
        recordMetaCache = raw
        return raw
    }

    private func saveRecordMeta(_ meta: [String: Data]) {
        recordMetaCache = meta
        defaults?.set(try? JSONEncoder().encode(meta), forKey: Self.recordMetaKey)
    }

    /// 서버가 준 레코드의 시스템 필드만 저장한다.
    private func cacheRecordMeta(_ record: CKRecord) {
        cacheRecordMetas([record])
    }

    /// 여러 건을 한 번에 - 첫 동기화처럼 수백 건이 몰릴 때 건건이 전체 사전을 다시 쓰지 않도록.
    private func cacheRecordMetas(_ records: [CKRecord]) {
        guard !records.isEmpty else { return }
        var meta = loadRecordMeta()
        for record in records {
            let coder = NSKeyedArchiver(requiringSecureCoding: true)
            record.encodeSystemFields(with: coder)
            coder.finishEncoding()
            meta[record.recordID.recordName] = coder.encodedData
        }
        saveRecordMeta(meta)
    }

    private func forgetRecordMeta(_ recordID: CKRecord.ID) {
        var meta = loadRecordMeta()
        guard meta.removeValue(forKey: recordID.recordName) != nil else { return }
        saveRecordMeta(meta)
    }

    /// 캐시된 시스템 필드로 되살린 빈 레코드(값 필드는 비어 있다).
    private func cachedRecord(for recordID: CKRecord.ID) -> CKRecord? {
        guard let data = loadRecordMeta()[recordID.recordName],
              let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true
        let record = CKRecord(coder: coder)
        coder.finishDecoding()
        return record
    }

    /// 저장 실패 처리 - 특히 `serverRecordChanged` 는 **버리면 안 되는** 실패다.
    /// 서버 레코드를 받아 태그를 갱신하고, 내 변경이 더 최신일 때만 다시 올린다.
    private func handleFailedSaves(_ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave],
                                   syncEngine: CKSyncEngine) {
        var retry: [CKSyncEngine.PendingRecordZoneChange] = []
        for failure in failures {
            let recordID = failure.record.recordID
            let name = recordID.recordName
            switch failure.error.code {
            case .serverRecordChanged:
                guard let serverRecord = failure.error.serverRecord else { continue }
                cacheRecordMeta(serverRecord)
                // 서버 쪽이 더 최신이면 내 변경은 접는다 - 다음 fetch 가 서버 값을 가져온다.
                let serverEdited = serverRecord["lastEdited"] as? Date ?? .distantPast
                let mineEdited = failure.record["lastEdited"] as? Date ?? .distantPast
                guard mineEdited >= serverEdited else {
                    conflictRetries[name] = nil
                    continue
                }
                let count = (conflictRetries[name] ?? 0) + 1
                guard count <= Self.maxConflictRetries else {
                    log.error("conflict retry limit reached: \(name, privacy: .public)")
                    conflictRetries[name] = nil
                    continue
                }
                conflictRetries[name] = count
                retry.append(.saveRecord(recordID))
            case .unknownItem:
                // 들고 있던 태그가 가리키는 레코드가 서버에 없다(존 삭제·계정 전환 등).
                // 태그를 버리고 새 레코드로 다시 올린다.
                forgetRecordMeta(recordID)
                retry.append(.saveRecord(recordID))
            default:
                break
            }
        }
        guard !retry.isEmpty else { return }
        syncEngine.state.add(pendingRecordZoneChanges: retry)
        log.info("re-queued \(retry.count) records after save conflict")
    }

    // MARK: - 카테고리 설정 동기화
    //
    // 메모 레코드는 id(UUID)당 하나지만, 카테고리 설정은 **기기당 하나**의 단일 레코드로
    // 같은 존에 올린다. 목록·아이콘·순서·숨김이 메모와 함께 기기 간에 따라다니게 하기 위함이다.
    // (예전엔 App Group UserDefaults 에만 있어 새 기기에서 탭이 통째로 사라졌다.)

    static let categoryRecordType = "CategorySettings"
    private static let categoryRecordName = "category-settings"
    /// 마지막으로 올린 스냅샷 지문 - 안 바뀌었으면 다시 올리지 않는다(불필요한 쓰기 방지).
    private static let categoryShadowKey = "memo.sync.categoryShadow"

    /// 동기화에 실을 카테고리 - 실제 쓰이는 것만(페르소나 시드·언어별 중복 방지).
    private func currentSyncableCategories() -> CategorySnapshot {
        CategorySnapshotStore.syncable(memos: (try? MemoStore.shared.load(type: .memo)) ?? [],
                                       sampleIDs: SampleMemoStorage.load())
    }

    private var categoryRecordID: CKRecord.ID {
        CKRecord.ID(recordName: Self.categoryRecordName, zoneID: zoneID)
    }

    private func categoryFingerprint(_ snapshot: CategorySnapshot) -> String {
        // updatedAt 은 매번 달라지므로 지문에서 뺀다 - 넣으면 내용이 같아도 계속 올라간다.
        var stable = snapshot
        stable.updatedAt = .distantPast
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]   // 딕셔너리 키 순서까지 결정적으로
        let data = (try? encoder.encode(stable)) ?? Data()
        // ⚠️ `hashValue` 를 쓰면 안 된다 - Swift 의 Hasher 는 프로세스마다 시드가 달라
        //    실행할 때마다 값이 바뀌고, 그러면 내용이 그대로여도 매 실행 재업로드된다.
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 로컬 카테고리 설정이 바뀌었으면 업로드 큐에 올린다.
    private func enqueueCategorySettingsIfChanged() {
        guard let engine else { return }
        let snapshot = currentSyncableCategories()
        guard !snapshot.isEmpty else { return }

        let fingerprint = categoryFingerprint(snapshot)
        let defaults = AppGroup.defaults
        guard defaults?.string(forKey: Self.categoryShadowKey) != fingerprint else { return }

        engine.state.add(pendingRecordZoneChanges: [.saveRecord(categoryRecordID)])
        log.info("category settings queued for upload")
    }

    /// 업로드용 레코드. `nextRecordZoneChangeBatch` 에서 이 recordID 를 만나면 여기로 온다.
    private func makeCategoryRecord() -> CKRecord? {
        var snapshot = currentSyncableCategories()
        guard !snapshot.isEmpty else { return nil }

        // 메모 레코드와 같은 이유로 서버 버전 위에 얹는다(태그 없이 올리면 두 번째부터 거절당한다).
        let record = cachedRecord(for: categoryRecordID)
            ?? CKRecord(recordType: Self.categoryRecordType, recordID: categoryRecordID)

        // ⚠️ 올리는 것은 **교체**다. 이 기기 목록만 올리면 공용 레코드가 그만큼 깎인다.
        //    원격에 이미 있던 것을 지우지 않도록 얹는다(카테고리를 새로 만들지는 않는다).
        //    자세한 이유: CategorySnapshotStore.union
        if let remotePayload = record["payload"] as? Data,
           let remote = try? JSONDecoder().decode(CategorySnapshot.self, from: remotePayload) {
            snapshot = CategorySnapshotStore.union(local: snapshot, remote: remote)
        }

        snapshot.updatedAt = Date()
        guard let payload = try? JSONEncoder().encode(snapshot) else { return nil }
        record["payload"] = payload as CKRecordValue
        record["updatedAt"] = snapshot.updatedAt as CKRecordValue
        return record
    }

    /// 원격 카테고리 설정을 로컬에 반영한다.
    /// ⚠️ 병합(merge) 전략을 쓴다 - 이 기기에만 있는 카테고리를 원격이 지우면 안 된다.
    ///    다른 기기에서 지운 카테고리는 여기서 되살아날 수 있지만, **지워지는 것보다
    ///    남는 쪽이 안전하다**(이름만 남을 뿐 메모는 그대로다).
    private func applyRemoteCategories(_ record: CKRecord) {
        guard let payload = record["payload"] as? Data,
              let snapshot = try? JSONDecoder().decode(CategorySnapshot.self, from: payload) else { return }

        // 동기화는 `.sync` - 목록·아이콘·색은 더하고, 숨김·기본 제공은 그대로 비춘다.
        // (`.merge` 로 두면 끈 것·되살린 것이 다른 기기로 영영 안 넘어간다)
        CategorySnapshotStore.apply(snapshot, strategy: .sync)
        // 방금 받은 상태를 그대로 섀도에 기록 - 받자마자 되올리는 핑퐁을 막는다.
        AppGroup.defaults?
            .set(categoryFingerprint(currentSyncableCategories()), forKey: Self.categoryShadowKey)
        log.info("remote category settings applied")
    }

    // MARK: - Images (App Group Images/ ↔ CKAsset)

    private var imagesDir: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent("Images")
    }

    /// 메모가 참조하는 이미지 파일들을 CKAsset 배열로 첨부(존재하는 파일만).
    private func attachImages(of memo: Memo, to record: CKRecord) {
        var names = memo.imageFileNames
        if let single = memo.imageFileName, !single.isEmpty, !names.contains(single) { names.append(single) }
        guard !names.isEmpty, let dir = imagesDir else { return }
        var assets: [CKAsset] = []
        var attached: [String] = []
        for name in names {
            let url = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                assets.append(CKAsset(fileURL: url))
                attached.append(name)
            }
        }
        if !assets.isEmpty {
            record["images"] = assets as CKRecordValue
            record["imageNames"] = attached as CKRecordValue
        }
    }

    /// 수신 레코드의 CKAsset들을 App Group Images/에 기록(아직 없는 파일만).
    private func writeImages(from record: CKRecord) {
        guard let assets = record["images"] as? [CKAsset],
              let names = record["imageNames"] as? [String],
              let dir = imagesDir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (asset, name) in zip(assets, names) {
            guard let src = asset.fileURL else { continue }
            let dest = dir.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.copyItem(at: src, to: dest)
            }
        }
    }

    // MARK: - Persistence (App Group)

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = defaults?.data(forKey: DefaultsKey.syncEngineState) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }
    private func saveState(_ state: CKSyncEngine.State.Serialization) {
        defaults?.set(try? JSONEncoder().encode(state), forKey: DefaultsKey.syncEngineState)
    }

    private func loadShadow() -> [UUID: String] {
        guard let data = defaults?.data(forKey: DefaultsKey.syncShadow),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
    }
    private func saveShadow(_ shadow: [UUID: String]) {
        let raw = Dictionary(uniqueKeysWithValues: shadow.map { ($0.key.uuidString, $0.value) })
        defaults?.set(try? JSONEncoder().encode(raw), forKey: DefaultsKey.syncShadow)
    }

    private func loadTombstones() -> [UUID: Date] {
        guard let data = defaults?.data(forKey: DefaultsKey.syncTombstones),
              let raw = try? JSONDecoder().decode([String: Date].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in UUID(uuidString: k).map { ($0, v) } })
    }
    private func saveTombstones(_ tombstones: [UUID: Date]) {
        let raw = Dictionary(uniqueKeysWithValues: tombstones.map { ($0.key.uuidString, $0.value) })
        defaults?.set(try? JSONEncoder().encode(raw), forKey: DefaultsKey.syncTombstones)
    }
}
