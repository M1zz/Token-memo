//
//  ProStatusManager.swift
//  ClipKeyboard
//
//  Created by Claude on 2026/02/18.
//

import Foundation

/// Pro 상태 및 무료 제한 관리
/// ProFeatureManager와 App Group UserDefaults 키를 공유한다 (키보드 익스텐션에서도 같은 값을 읽도록).
class ProStatusManager: ObservableObject {
    static let shared = ProStatusManager()

    // MARK: - 무료 제한 상수
    // Note: Source of truth는 ProFeatureManager.freeMemoLimit 등. 이 struct는 레거시 참조용.

    struct FreeLimits {
        static var maxMemos: Int { ProFeatureManager.memoLimit }
        static var maxClipboardHistory: Int { ProFeatureManager.freeClipboardHistoryLimit }
        static var maxTemplates: Int { ProFeatureManager.freeTemplateLimit }
    }

    // MARK: - Published Properties

    @Published var isPro: Bool = false

    // MARK: - Private

    // ProFeatureManager와 키를 통일 (이전 "com.ysoup.tokenmemo.isPro" 키는 누락돼 Pro 구매 상태가 ProFeatureManager에 전달되지 않던 버그가 있었음)
    private let proStatusKey = ProFeatureManager.proStatusKey
    private let userDefaults = AppGroup.defaults

    // MARK: - Init

    private init() {
        migrateLegacyProKeyIfNeeded()
        loadProStatus()
    }

    /// v3.x에서 "com.ysoup.tokenmemo.isPro" 키에 저장하던 Pro 상태를 신규 통합 키로 이관.
    /// StoreKit 재동기화가 늦는 경우에도 업그레이드 직후 Pro 권한이 유지되도록 한다.
    private func migrateLegacyProKeyIfNeeded() {
        guard let defaults = userDefaults else { return }
        let legacyKey = "com.ysoup.tokenmemo.isPro"
        let unifiedKey = ProFeatureManager.proStatusKey
        // 이미 통합 키에 값이 있다면 건드리지 않음.
        if defaults.object(forKey: unifiedKey) != nil { return }
        if let legacyPro = defaults.object(forKey: legacyKey) as? Bool {
            defaults.set(legacyPro, forKey: unifiedKey)
            print("🔄 [ProStatusManager] 레거시 Pro 키 이관: \(legacyPro)")
        }
    }

    /// v4.0 첫 실행 시 그랜드파더 플래그 설정. 호출 시점:
    /// - 앱 시작 직후 (ClipKeyboardApp.init / onAppear 근처)
    /// - StoreManager가 구매 상태를 동기화한 직후 다시 한 번 호출 권장
    func bootstrapV4GrandfatherFlags(existingMemoCount: Int, isProNow: Bool) {
        guard let defaults = userDefaults else { return }

        // 1) Pro 구매 이력 기록 (한 번이라도 Pro였으면 영구 true)
        if isProNow, !defaults.bool(forKey: ProFeatureManager.grandfatheredPurchaseKey) {
            defaults.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
            print("🛡 [ProStatusManager] 그랜드파더 Pro 구매 기록됨")
        }

        // 2) 기존 무료 유저 표시 (메모가 하나라도 있으면, 키보드 익스텐션 등 기존 접근 유지)
        let hasAnyMemo = existingMemoCount > 0
        if hasAnyMemo, !defaults.bool(forKey: ProFeatureManager.existingFreeUserKey) {
            defaults.set(true, forKey: ProFeatureManager.existingFreeUserKey)
            print("🛡 [ProStatusManager] 기존 무료 유저 표시됨 (memos=\(existingMemoCount))")
        }

        // 3) 메모 보유량이 새 한도 초과면 grace 플래그
        let overNewLimit = existingMemoCount > ProFeatureManager.freeMemoLimit
        if overNewLimit, !defaults.bool(forKey: ProFeatureManager.graceMemoQuotaKey) {
            defaults.set(true, forKey: ProFeatureManager.graceMemoQuotaKey)
            print("🛡 [ProStatusManager] Grace memo quota 표시됨 (memos=\(existingMemoCount))")
        }
    }

    // MARK: - Public Methods

    /// 메모를 더 추가할 수 있는지 확인
    func canAddMemo(currentCount: Int) -> Bool {
        return ProFeatureManager.canAddMemo(currentCount: currentCount)
    }

    /// 클립보드 히스토리를 더 저장할 수 있는지 확인
    func canAddClipboardHistory(currentCount: Int) -> Bool {
        return ProFeatureManager.hasFullAccess || currentCount < FreeLimits.maxClipboardHistory
    }

    /// 템플릿을 더 추가할 수 있는지 확인
    func canAddTemplate(currentCount: Int) -> Bool {
        return ProFeatureManager.canAddTemplate(currentCount: currentCount)
    }

    /// iCloud 백업 사용 가능 여부 (구매 / 그랜드파더 / 활성 trial)
    var canUseCloudBackup: Bool {
        return ProFeatureManager.hasFullAccess
    }

    /// Combo 기능 사용 가능 여부
    var canUseStack: Bool {
        return ProFeatureManager.hasFullAccess
    }

    /// 보안 메모 사용 가능 여부
    var canUseSecureMemo: Bool {
        return ProFeatureManager.hasFullAccess
    }

    /// 남은 무료 메모 개수
    func remainingFreeMemos(currentCount: Int) -> Int {
        if ProFeatureManager.hasFullAccess { return Int.max }
        return max(0, FreeLimits.maxMemos - currentCount)
    }

    /// Pro 상태 설정 (StoreManager에서 호출)
    func setProStatus(_ isPro: Bool) {
        self.isPro = isPro
        saveProStatus()
        print("✅ [ProStatusManager] IAP 구매 권한 변경: \(isPro)")
        // 결제 외 경로(TestFlight/그랜드파더/체험)까지 합친 실제 접근권한을 함께 찍어 혼동 제거.
        ProFeatureManager.logAccessResolution("구매 권한 변경 후")
    }

    /// Pro 상태 복원 (앱 시작 시 또는 구매 복원 시)
    func restoreProStatus() {
        // StoreManager에서 구매 복원 후 호출됨
        loadProStatus()
    }

    // MARK: - Private Methods

    private func loadProStatus() {
        isPro = userDefaults?.bool(forKey: proStatusKey) ?? false
        print("📥 [ProStatusManager] IAP 구매 권한 로드: \(isPro)")
    }

    private func saveProStatus() {
        userDefaults?.set(isPro, forKey: proStatusKey)
        userDefaults?.synchronize()
        // macOS 앱과 Pro 상태 동기화 (iCloud KV Store)
        NSUbiquitousKeyValueStore.default.set(isPro, forKey: proStatusKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        print("💾 [ProStatusManager] IAP 구매 권한 저장: \(isPro)")
    }
}
