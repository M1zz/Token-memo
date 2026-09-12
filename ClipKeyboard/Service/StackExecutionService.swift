//
//  ComboExecutionService.swift
//  ClipKeyboard
//
//  Created by Claude Code on 2025-12-06.
//  Phase 2: Combo Execution Service
//

import Foundation
import UIKit
import Combine

/// Combo 실행 상태
enum StackExecutionState: Equatable {
    case idle
    case running(currentIndex: Int, totalCount: Int)
    case paused(currentIndex: Int)
    case completed
    case error(String)
}

/// Combo 실행 서비스
class StackExecutionService: ObservableObject {
    static let shared = StackExecutionService()

    @Published var state: StackExecutionState = .idle
    @Published var currentItemIndex: Int = 0

    private var timer: Timer?
    /// 실행 중인 콤보(= 자식 메모를 가진 Memo).
    private var currentStack: Memo?
    /// 자식 메모들의 value(순서대로). childMemoIds → 메모 value 해석 결과.
    private var currentValues: [String] = []

    private init() {}

    /// Combo 실행 시작
    /// - Parameter memo: 자식 메모(childMemoIds)를 가진 콤보 Memo
    func startStack(_ memo: Memo) {
        guard state == .idle else {
            print("⚠️ Combo가 이미 실행 중입니다")
            return
        }

        currentStack = memo
        currentValues = memo.stackValues   // 콤보 단계(인라인 텍스트)
        currentItemIndex = 0

        guard !currentValues.isEmpty else {
            print("⚠️ Combo '\(memo.title)' 자식 메모 없음. 실행 취소")
            stopStack()
            return
        }

        print("🎬 Combo '\(memo.title)' 실행 시작 (\(currentValues.count)개 항목, \(memo.stackInterval)초 간격)")

        // 첫 번째 항목 즉시 실행
        executeCurrentItem()

        // 타이머 시작 (두 번째 항목부터)
        if currentValues.count > 1 {
            state = .running(currentIndex: 0, totalCount: currentValues.count)
            startTimer(interval: memo.stackInterval)
        } else {
            // 항목이 1개면 바로 완료
            completeExecution()
        }
    }

    /// Combo 일시정지
    func pauseStack() {
        guard case .running = state else { return }
        timer?.invalidate()
        timer = nil
        state = .paused(currentIndex: currentItemIndex)
        print("⏸ Combo 일시정지")
    }

    /// Combo 재개
    func resumeStack() {
        guard case .paused = state, let memo = currentStack else { return }
        state = .running(currentIndex: currentItemIndex, totalCount: currentValues.count)
        startTimer(interval: memo.stackInterval)
        print("▶️ Combo 재개")
    }

    /// Combo 중지
    func stopStack() {
        timer?.invalidate()
        timer = nil
        currentStack = nil
        currentValues = []
        currentItemIndex = 0
        state = .idle
        print("⏹ Combo 중지")
    }

    // MARK: - Private Methods

    private func startTimer(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.executeNextItem()
        }
    }

    private func executeCurrentItem() {
        guard currentItemIndex < currentValues.count else {
            completeExecution()
            return
        }

        // 자동 변수 치환 ({날짜}, {시간} 등)
        let finalValue = processTemplateVariables(in: currentValues[currentItemIndex])
        print("📋 [\(currentItemIndex + 1)/\(currentValues.count)] 실행 중")

        // 클립보드에 복사
        UIPasteboard.general.string = finalValue
        print("✅ 클립보드에 복사됨: \(finalValue.prefix(50))...")

        // 청각 장애 접근성: 항목 복사 완료 햅틱 (medium = 구별 가능한 강도)
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        // 알림 발송 (옵션)
        postNotification(value: finalValue)
    }

    private func executeNextItem() {
        currentItemIndex += 1

        if currentItemIndex < currentValues.count {
            state = .running(currentIndex: currentItemIndex, totalCount: currentValues.count)
            executeCurrentItem()
        } else {
            completeExecution()
        }
    }

    private func completeExecution() {
        timer?.invalidate()
        timer = nil
        state = .completed

        // 청각 장애 접근성: Combo 완료 success 햅틱 (두 번 울리는 패턴 - 완료 신호)
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        // 사용 횟수 증가 (콤보도 일반 메모이므로 clipCount/lastUsedAt 일원화)
        if let stack = currentStack {
            do {
                try MemoStore.shared.incrementClipCount(for: stack.id)
                print("🎉 Combo '\(stack.title)' 완료!")
            } catch {
                print("⚠️ 사용 횟수 업데이트 실패: \(error)")
            }

            // 리뷰 요청 트리거: Combo 완료
            NotificationCenter.postOnMain(name: .reviewTriggerStackCompleted, object: nil)
        }

        // 3초 후 상태 초기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if case .completed = self?.state {
                self?.stopStack()
            }
        }
    }

    private func postNotification(value: String) {
        NotificationCenter.postOnMain(
            name: .stackItemExecuted,
            object: nil,
            userInfo: [
                "value": value,
                "index": currentItemIndex,
                "total": currentValues.count
            ]
        )
    }

    /// 템플릿 자동 변수 치환
    /// - Parameter text: 치환할 텍스트
    /// - Returns: 치환된 텍스트
    private func processTemplateVariables(in text: String) -> String {
        TemplateVariableProcessor.process(text)
    }

    /// 진행률 계산
    var progress: Double {
        guard currentValues.count > 0 else { return 0 }
        return Double(currentItemIndex) / Double(currentValues.count)
    }

    /// 현재 실행 중인 항목 값
    var currentValue: String? {
        guard currentItemIndex < currentValues.count else { return nil }
        return currentValues[currentItemIndex]
    }
}

// MARK: - Notification Names
// 통합: Notification.Name 상수는 AppNotification.swift 단일 출처에서 관리.
