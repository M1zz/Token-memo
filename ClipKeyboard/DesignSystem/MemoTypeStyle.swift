//
//  MemoTypeStyle.swift
//  ClipKeyboard
//
//  단축어 타입(템플릿·콤보·보안·이미지)의 **시각 표현 단일 출처**.
//  메인앱 카드와 키보드 익스텐션 키가 같은 파일을 본다.
//
//  왜 만들었나: 같은 규칙(템플릿 보라 실선 / 콤보 주황 dash / 보안 회색 dot)이
//  `ClipKeyboardList.memoTypeBorder` 와 `KeyboardView.typeStyle` 두 곳에 복사돼 있었고,
//  주석에 "정확히 동일"이라고 적어 두는 것으로 동기화를 사람 손에 맡기고 있었다.
//  한쪽만 고치면 앱과 키보드의 생김새가 조용히 갈라진다.
//
//  ⚠️ 색만으로 구분하지 않는다 - 색약·색맹 사용자를 위해 **dash 패턴**이 함께 다르다.
//     (템플릿 실선 / 콤보 긴 파선 / 보안 점선) 색을 바꿀 때 패턴도 유지할 것.
//
//  ⚠️ 이 표시는 "단축어 구분 표시"(showVisualCues) 토글이 켜졌을 때만 노출된다.
//     기본은 제목만 보이는 깔끔한 상태다.
//

import SwiftUI

/// 타입 구분 테두리 스펙. 색 + 선 굵기 + dash 패턴.
struct TypeVisualStyle {
    let color: Color
    let lineWidth: CGFloat
    let dash: [CGFloat]

    /// 아무 표시도 하지 않음.
    static let none = TypeVisualStyle(color: .clear, lineWidth: 0, dash: [])
}

enum MemoTypeStyle {

    // MARK: - 테두리

    /// 단축어 타입별 테두리. `visualCuesVisible` 이 false면 아무것도 그리지 않는다.
    ///
    /// - Parameter forceTemplate: 같은 메모가 attached template으로 한 칸 더 펼쳐진 경우,
    ///   그 칸은 원본이 템플릿이 아니어도 템플릿으로 보여야 한다(키보드 전용 사정).
    static func border(for memo: Memo,
                       visualCuesVisible: Bool,
                       forceTemplate: Bool = false) -> TypeVisualStyle {
        guard visualCuesVisible else { return .none }

        if forceTemplate || memo.isTemplate || !memo.templateVariables.isEmpty {
            return TypeVisualStyle(color: .purple, lineWidth: 1.5, dash: [])
        }
        if memo.isStack {
            return TypeVisualStyle(color: .orange, lineWidth: 1.5, dash: [5, 3])
        }
        if memo.isSecure {
            return TypeVisualStyle(color: .gray, lineWidth: 1.5, dash: [1, 3])
        }
        return .none
    }

    // MARK: - 심볼

    /// 단축어 타입을 나타내는 SF Symbol 이름.
    /// 앱 카드와 키보드 키가 **같은 그림**을 써야 사용자가 두 화면을 같은 물건으로 읽는다.
    static func symbolName(for memo: Memo, forceTemplate: Bool = false) -> String {
        if forceTemplate || memo.isTemplate { return AppSymbol.wandAndSparkles }
        if memo.isStack { return AppSymbol.squareStack3dUpFill }
        if memo.isSecure { return AppSymbol.lockFill }
        if memo.contentType == .image || memo.contentType == .mixed { return AppSymbol.photoFill }
        return AppSymbol.docFill
    }

    /// 심볼을 보여줄 타입인가.
    /// 일반 텍스트 단축어까지 문서 아이콘을 달면 화면이 아이콘 밭이 된다
    /// **성격이 있는 것만** 표시한다.
    static func hasDistinctType(_ memo: Memo, forceTemplate: Bool = false) -> Bool {
        forceTemplate
            || memo.isTemplate
            || memo.isStack
            || memo.isSecure
            || memo.contentType == .image
            || memo.contentType == .mixed
    }
}
