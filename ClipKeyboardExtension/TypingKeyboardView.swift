//
//  TypingKeyboardView.swift
//  ClipKeyboardExtension
//
//  자체 QWERTY/한글 타이핑 키보드. 사용자가 메모 외 텍스트를 직접 입력할 때
//  지구본 버튼으로 시스템 키보드 전환 없이 같은 익스텐션에서 입력 가능.
//

import SwiftUI
import UIKit

/// 타이핑 키보드 → host 입력 인터페이스. KeyboardViewController가 구현.
protocol TypingInputProxy: AnyObject {
    func insertText(_ text: String)
    func deleteBackward()
    func insertNewline()

    /// ⚠️ **지구본 키에 쓰지 말 것.** 이 API 는 글자 키보드만 순서대로 돌고
    ///    **이모지 키보드는 건너뛴다.** 타사 키보드를 함께 쓰는 사람이 지구본을
    ///    눌러도 이모지가 나오지 않던 원인이 이것이었다.
    ///    지구본은 `attachInputModeSwitch(to:)` 로 붙인다.
    func advanceToNextInputMode()

    /// 지구본 키에 iOS 표준 전환 동작을 붙인다.
    ///
    /// 탭이면 다음 키보드, 길게 누르면 **이모지를 포함한** 키보드 목록이 뜬다.
    /// 이 동작은 `handleInputModeList(from:with:)` 가 붙은 UIControl 에서만 나온다.
    func attachInputModeSwitch(to button: UIButton)

    func cursorRight()
    func clearAll()
}
