//
//  ComboAndTemplateModelSwiftTests.swift
//  ClipKeyboardTests
//
//  Swift Testing 스위트 - 콤보 실행 상태 머신(ComboExecutionState) 및
//  레거시 Combo/ComboItem 구조(정렬·Codable).
//
//  명세: docs/product/FEATURE_SPEC.md §4
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("콤보 상태 머신 & 레거시 콤보 구조")
struct StackAndTemplateModelSwiftTests {

    // MARK: - ComboExecutionState (Equatable)

    @Test("같은 케이스/연관값은 동등하다")
    func stateEquality() {
        #expect(StackExecutionState.idle == .idle)
        #expect(StackExecutionState.completed == .completed)
        #expect(StackExecutionState.running(currentIndex: 1, totalCount: 3)
                == .running(currentIndex: 1, totalCount: 3))
        #expect(StackExecutionState.paused(currentIndex: 2) == .paused(currentIndex: 2))
        #expect(StackExecutionState.error("x") == .error("x"))
    }

    @Test("다른 케이스/연관값은 동등하지 않다")
    func stateInequality() {
        #expect(StackExecutionState.idle != .completed)
        #expect(StackExecutionState.running(currentIndex: 0, totalCount: 3)
                != .running(currentIndex: 1, totalCount: 3))
        #expect(StackExecutionState.paused(currentIndex: 1) != .paused(currentIndex: 2))
        #expect(StackExecutionState.error("a") != .error("b"))
    }

    // MARK: - 레거시 ComboItem 정렬

    @Test("Combo.sortItems는 order 오름차순으로 정렬한다")
    func sortItemsAscending() {
        var stack = Combo(title: "정렬", items: [
            ComboItem(type: .memo, referenceId: UUID(), order: 2),
            ComboItem(type: .memo, referenceId: UUID(), order: 0),
            ComboItem(type: .template, referenceId: UUID(), order: 1)
        ])
        stack.sortItems()
        #expect(stack.items.map(\.order) == [0, 1, 2])
    }

    // MARK: - 레거시 Combo Codable

    @Test("Combo Codable 라운드트립")
    func stackCodableRoundTrip() throws {
        let original = Combo(title: "콤보", items: [
            ComboItem(type: .memo, referenceId: UUID(), order: 0, displayValue: "값1"),
            ComboItem(type: .clipboardHistory, referenceId: UUID(), order: 1)
        ], interval: 1.0, useCount: 5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Combo.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.title == "콤보")
        #expect(decoded.items.count == 2)
        #expect(decoded.interval == 1.0)
        #expect(decoded.useCount == 5)
    }

    // MARK: - ComboItemType

    @Test("ComboItemType rawValue")
    func stackItemTypeRawValues() {
        #expect(ComboItemType.memo.rawValue == "메모")
        #expect(ComboItemType.clipboardHistory.rawValue == "클립보드")
        #expect(ComboItemType.template.rawValue == "템플릿")
    }

    // MARK: - 콤보 메모(통합 모델) - stackValues 기반

    @Test("통합 모델에서 콤보 단계는 stackValues 순서를 유지한다")
    func unifiedStackPreservesOrder() {
        let memo = Memo(title: "3단계 콤보", value: "안녕",
                        stackValues: ["안녕", "반가워", "또 봐"])
        #expect(memo.isStack)
        #expect(memo.stackValues.first == "안녕")
        #expect(memo.stackValues.last == "또 봐")
    }
}
