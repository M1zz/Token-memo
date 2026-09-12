//
//  ProFeatureManagerTests.swift
//  ClipKeyboardTests
//
//  Pro/무료/체험 게이팅 로직 테스트.
//  주의: ProFeatureManager는 App Group UserDefaults를 직접 읽고/쓰는 static struct.
//  TestFlight 환경에서는 isPro가 무조건 true가 되므로 시뮬레이터/디버그 빌드에서 실행 권장.
//

import XCTest
@testable import ClipKeyboard

final class ProFeatureManagerTests: XCTestCase {

    private var groupDefaults: UserDefaults? {
        AppGroup.defaults
    }

    /// 테스트 격리를 위해 모든 ProFeatureManager 관련 키 초기화
    private func clearAllProState() {
        let keys = [
            ProFeatureManager.proStatusKey,
            ProFeatureManager.grandfatheredPurchaseKey,
            ProFeatureManager.existingFreeUserKey,
            ProFeatureManager.graceMemoQuotaKey,
            ProFeatureManager.graceBannerDismissedKey,
            ProFeatureManager.trialStartedAtKey,
            ProFeatureManager.trialLastSeenKey
        ]
        for key in keys {
            groupDefaults?.removeObject(forKey: key)
        }
    }

    override func setUp() {
        super.setUp()
        clearAllProState()
    }

    override func tearDown() {
        clearAllProState()
        super.tearDown()
    }

    // MARK: - 상수 검증

    func testFreeLimits_AreExpectedValues() {
        XCTAssertEqual(ProFeatureManager.freeMemoLimit, 10)
        XCTAssertEqual(ProFeatureManager.freeStackLimit, 3)
        XCTAssertEqual(ProFeatureManager.freeClipboardHistoryLimit, 50)
        XCTAssertEqual(ProFeatureManager.freeTemplateLimit, 3)
        XCTAssertEqual(ProFeatureManager.freeImageMemoLimit, 5)
        XCTAssertEqual(ProFeatureManager.trialDurationDays, 7)
    }

    // MARK: - 무료 사용자 한도

    func testCanAddMemo_FreeUserUnderLimit_True() throws {
        guard !ProFeatureManager.hasFullAccess else {
            // TestFlight 빌드에서는 항상 Pro라 의미 있는 검증 불가
            throw XCTSkip("TestFlight/Pro 환경에서는 한도 검증을 스킵")
        }
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: 0))
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: 9))
    }

    func testCanAddMemo_FreeUserAtLimit_False() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertFalse(ProFeatureManager.canAddMemo(currentCount: 10))
        XCTAssertFalse(ProFeatureManager.canAddMemo(currentCount: 100))
    }

    func testCanAddStack_FreeUserUnderLimit() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertTrue(ProFeatureManager.canAddStack(currentCount: 2))
        XCTAssertFalse(ProFeatureManager.canAddStack(currentCount: 3))
    }

    func testCanAddTemplate_FreeUserUnderLimit() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertTrue(ProFeatureManager.canAddTemplate(currentCount: 2))
        XCTAssertFalse(ProFeatureManager.canAddTemplate(currentCount: 3))
    }

    func testCanAddImageMemo_FreeUserUnderLimit() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertTrue(ProFeatureManager.canAddImageMemo(currentImageMemoCount: 4))
        XCTAssertFalse(ProFeatureManager.canAddImageMemo(currentImageMemoCount: 5))
    }

    func testClipboardHistoryLimit_FreeUser() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertEqual(ProFeatureManager.clipboardHistoryLimit(), 50)
    }

    // MARK: - Pro/그랜드파더 무제한

    func testCanAddMemo_Grandfathered_AlwaysTrue() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        XCTAssertTrue(ProFeatureManager.canAddMemo(currentCount: 99999))
        XCTAssertTrue(ProFeatureManager.canAddStack(currentCount: 99999))
    }

    func testClipboardHistoryLimit_FullAccess_Higher() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        XCTAssertEqual(ProFeatureManager.clipboardHistoryLimit(), 100)
    }

    func testKeyboardMemoDisplayLimit_FullAccess_Unlimited() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        XCTAssertEqual(ProFeatureManager.keyboardMemoDisplayLimit, Int.max)
    }

    func testKeyboardMemoDisplayLimit_FreeUser_Limited() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertEqual(ProFeatureManager.keyboardMemoDisplayLimit, 10)
    }

    // MARK: - 그랜드파더

    func testIsGrandfathered_TrueIfPurchaseFlag() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        XCTAssertTrue(ProFeatureManager.isGrandfathered)
    }

    func testIsGrandfathered_TrueIfExistingFreeUser() {
        groupDefaults?.set(true, forKey: ProFeatureManager.existingFreeUserKey)
        XCTAssertTrue(ProFeatureManager.isGrandfathered)
    }

    func testIsGrandfathered_FalseIfNoFlag() throws {
        // TestFlight 환경에서는 isGrandfathered와 무관하게 isPro=true가 됨, 그래도 isGrandfathered 자체는 false
        XCTAssertFalse(ProFeatureManager.isGrandfathered)
    }

    // MARK: - 7일 체험

    func testStartTrial_FreshUser_Succeeds() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        XCTAssertTrue(ProFeatureManager.canStartTrial)
        let started = ProFeatureManager.startTrial()
        XCTAssertTrue(started)
        XCTAssertNotNil(ProFeatureManager.trialStartedAt)
        XCTAssertTrue(ProFeatureManager.hasStartedTrial)
        XCTAssertTrue(ProFeatureManager.isInTrial)
    }

    func testStartTrial_AlreadyStarted_ReturnsFalse() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        _ = ProFeatureManager.startTrial()
        let secondTry = ProFeatureManager.startTrial()
        XCTAssertFalse(secondTry, "체험은 1회 한정")
    }

    func testStartTrial_ProUser_ReturnsFalse() {
        groupDefaults?.set(true, forKey: ProFeatureManager.proStatusKey)
        let started = ProFeatureManager.startTrial()
        XCTAssertFalse(started, "Pro는 체험 시작 불가")
    }

    func testStartTrial_Grandfathered_ReturnsFalse() {
        groupDefaults?.set(true, forKey: ProFeatureManager.grandfatheredPurchaseKey)
        let started = ProFeatureManager.startTrial()
        XCTAssertFalse(started)
    }

    func testTrialDaysRemaining_AfterStart_LessThanOrEqualToDuration() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        _ = ProFeatureManager.startTrial()
        let remaining = ProFeatureManager.trialDaysRemaining
        XCTAssertGreaterThan(remaining, 0)
        XCTAssertLessThanOrEqual(remaining, ProFeatureManager.trialDurationDays)
    }

    func testIsInTrial_AfterExpiry_False() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        // 8일 전에 시작했다고 강제 설정
        let eightDaysAgo = Date().timeIntervalSince1970 - (8 * 86400)
        groupDefaults?.set(eightDaysAgo, forKey: ProFeatureManager.trialStartedAtKey)
        groupDefaults?.set(eightDaysAgo, forKey: ProFeatureManager.trialLastSeenKey)
        XCTAssertTrue(ProFeatureManager.hasStartedTrial)
        XCTAssertFalse(ProFeatureManager.isInTrial)
        XCTAssertEqual(ProFeatureManager.trialDaysRemaining, 0)
    }

    func testTrialMonotonicTime_ClockRollback_DoesNotExtendTrial() throws {
        guard !ProFeatureManager.hasFullAccess else { throw XCTSkip("Pro 환경") }
        let now = Date().timeIntervalSince1970
        // 체험 5일 전 시작 + 미래 시점까지 lastSeen 기록 (예: 6일 후 본 척)
        groupDefaults?.set(now - 5 * 86400, forKey: ProFeatureManager.trialStartedAtKey)
        groupDefaults?.set(now + 6 * 86400, forKey: ProFeatureManager.trialLastSeenKey)
        // 체험 시작 + 7일 < lastSeen + Δ → 체험 만료로 처리되어야 함
        XCTAssertFalse(ProFeatureManager.isInTrial, "시계 조작(과거로 되돌리기) 방어")
    }

    // MARK: - Grace 배너

    func testMarkGraceBannerDismissed_Persists() {
        XCTAssertFalse(ProFeatureManager.didDismissGraceBanner)
        ProFeatureManager.markGraceBannerDismissed()
        XCTAssertTrue(ProFeatureManager.didDismissGraceBanner)
    }

    // MARK: - LimitType (분석/푸시 메시지용)

    func testLimitType_AnalyticsKeys_Unique() {
        let keys = [
            ProFeatureManager.LimitType.memo.analyticsKey,
            ProFeatureManager.LimitType.stack.analyticsKey,
            ProFeatureManager.LimitType.template.analyticsKey,
            ProFeatureManager.LimitType.clipboardHistory.analyticsKey,
            ProFeatureManager.LimitType.cloudBackup.analyticsKey,
            ProFeatureManager.LimitType.biometricLock.analyticsKey,
            ProFeatureManager.LimitType.themeCustomization.analyticsKey,
            ProFeatureManager.LimitType.imageMemo.analyticsKey
        ]
        XCTAssertEqual(Set(keys).count, keys.count, "analyticsKey는 모두 고유해야 함")
    }

    // MARK: - Feature 게이팅

    func testIsKeyboardExtensionAvailable_AlwaysTrue() {
        XCTAssertTrue(ProFeatureManager.isKeyboardExtensionAvailable)
    }

    func testIsThemeCustomizationAvailable_AlwaysTrue() {
        XCTAssertTrue(ProFeatureManager.isThemeCustomizationAvailable)
    }

    func testIsImageMemoAvailable_AlwaysTrue() {
        XCTAssertTrue(ProFeatureManager.isImageMemoAvailable)
    }

    func testIsCloudBackupAvailable_RequiresFullAccess() {
        groupDefaults?.set(true, forKey: ProFeatureManager.proStatusKey)
        XCTAssertTrue(ProFeatureManager.isCloudBackupAvailable)
    }

    func testIsBiometricLockAvailable_RequiresFullAccess() {
        groupDefaults?.set(true, forKey: ProFeatureManager.proStatusKey)
        XCTAssertTrue(ProFeatureManager.isBiometricLockAvailable)
    }
}
