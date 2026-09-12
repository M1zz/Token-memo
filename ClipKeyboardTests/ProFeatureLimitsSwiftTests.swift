//
//  ProFeatureLimitsSwiftTests.swift
//  ClipKeyboardTests
//
//  Swift Testing 스위트 - 무료/Pro 한도 상수와 한도 판정 함수.
//  Pro 상태(App Group)가 환경에 따라 다를 수 있으므로, 전역 상태에 의존하지
//  않는 불변식(상수, hasFullAccess와 한도의 관계)을 검증한다.
//
//  명세: docs/product/FEATURE_SPEC.md §6
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("ProFeatureManager: 무료/Pro 한도")
struct ProFeatureLimitsSwiftTests {

    // MARK: - 한도 상수

    @Test("무료 한도 상수")
    func freeLimitConstants() {
        #expect(ProFeatureManager.freeMemoLimit == 10)
        #expect(ProFeatureManager.freeStackLimit == 3)
        #expect(ProFeatureManager.freeTemplateLimit == 3)
        #expect(ProFeatureManager.freeImageMemoLimit == 5)
        #expect(ProFeatureManager.freeClipboardHistoryLimit == 50)
    }

    // MARK: - 한도 판정 (전역 상태에 무관한 불변식)

    @Test("0개일 때는 항상 추가 가능")
    func canAlwaysAddFromZero() {
        #expect(ProFeatureManager.canAddMemo(currentCount: 0))
        #expect(ProFeatureManager.canAddStack(currentCount: 0))
        #expect(ProFeatureManager.canAddTemplate(currentCount: 0))
        #expect(ProFeatureManager.canAddImageMemo(currentImageMemoCount: 0))
    }

    @Test("풀 액세스가 아니면 한도에서 막히고, 풀 액세스면 무제한")
    func limitDependsOnFullAccess() {
        let full = ProFeatureManager.hasFullAccess
        if full {
            #expect(ProFeatureManager.canAddMemo(currentCount: 9999))
            #expect(ProFeatureManager.canAddStack(currentCount: 9999))
            #expect(ProFeatureManager.canAddTemplate(currentCount: 9999))
            #expect(ProFeatureManager.canAddImageMemo(currentImageMemoCount: 9999))
        } else {
            #expect(ProFeatureManager.canAddMemo(currentCount: 9) == true)
            #expect(ProFeatureManager.canAddMemo(currentCount: 10) == false)
            #expect(ProFeatureManager.canAddStack(currentCount: 3) == false)
            #expect(ProFeatureManager.canAddTemplate(currentCount: 3) == false)
            #expect(ProFeatureManager.canAddImageMemo(currentImageMemoCount: 5) == false)
        }
    }

    @Test("클립보드 히스토리 한도는 풀 액세스 100, 무료 50")
    func clipboardHistoryLimitMatchesAccess() {
        let limit = ProFeatureManager.clipboardHistoryLimit()
        if ProFeatureManager.hasFullAccess {
            #expect(limit == 100)
        } else {
            #expect(limit == 50)
        }
    }

    // MARK: - 접근 권한 일관성

    @Test("hasFullAccess는 isPro/grandfathered/trial 중 하나라도 참이면 참")
    func fullAccessConsistency() {
        let expected = ProFeatureManager.isPro
            || ProFeatureManager.isGrandfathered
            || ProFeatureManager.isInTrial
        #expect(ProFeatureManager.hasFullAccess == expected)
    }

    @Test("grandfathered는 v3 구매 또는 기존 무료 사용자면 참")
    func grandfatheredConsistency() {
        let expected = ProFeatureManager.hasGrandfatheredPurchase
            || ProFeatureManager.wasExistingFreeUser
        #expect(ProFeatureManager.isGrandfathered == expected)
    }
}
