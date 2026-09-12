//
//  KeyboardMemoPeek.swift
//  ClipKeyboardExtension
//
//  키를 길게 눌렀을 때 **값을 크게 보여주는 판.** 키보드 안에 우리가 직접 그린다.
//
//  왜 시스템 컨텍스트 메뉴를 버렸는가: 키보드 익스텐션은 자기 창 밖에 그릴 수 없다.
//  그래서 `.contextMenu(preview:)` 로 아무리 큰 미리보기를 넘겨도 키보드 높이(약 300pt)에서
//  잘리고, 거기서 메뉴 줄까지 빼면 150pt 남짓만 남는다. 값이 긴 단축어는 두 줄 보고 끝난다.
//  키보드 영역 전체는 **우리 것**이므로, 직접 그리면 그 안을 꽉 채워 쓸 수 있다.
//  (같은 방식으로 이미 PIN 입력 오버레이가 이 자리를 쓰고 있다)
//
//  ⚠️ 보안 단축어의 값은 여기서도 보여주지 않는다. 길게 누르기는 인증을 거치지 않는 길이다.
//

import SwiftUI

struct KeyboardMemoPeek: View {
    let memo: Memo
    let theme: AppTheme
    /// 클립보드로 복사한다 - 전체 접근 확인은 부르는 쪽(KeyboardView)이 한다.
    let onCopy: () -> Void
    /// 순서 바꾸기로 들어간다. nil 이면 그 버튼을 두지 않는다.
    ///
    /// ⚠️ 길게 누르기는 이 판이 이미 쓰고 있어서(한 손짓에 주인은 하나) 순서 바꾸기는
    ///    손짓을 하나 더 만들지 않고 **이 판 안에서** 시작한다.
    let onReorder: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // 뒤를 덮어 판이 떠 보이게. 아무 데나 눌러도 닫힌다.
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 10) {
                header
                Divider().overlay(theme.divider)
                valueArea
                actions
            }
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            // 키보드 안을 꽉 채운다 - 남는 자리를 두면 크게 만든 이유가 없다.
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 머리

    private var header: some View {
        HStack(spacing: 8) {
            Text(memo.title.templateAwareAttributed(accent: theme.accent,
                                                    accentSoft: theme.accentSoft,
                                                    font: .callout.weight(.semibold)))
                .font(.callout.weight(.semibold))
                .foregroundColor(theme.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            if memo.isSecure {
                Image(systemName: AppSymbol.lockFill)
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
            }
            Button(action: onClose) {
                Image(systemName: AppSymbol.xmarkCircleFill)
                    .font(.title3)
                    .foregroundColor(theme.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("닫기", comment: "Close paywall"))
        }
    }

    // MARK: - 값

    /// 값이 길면 스크롤한다. 잘라서 보여주면 크게 만든 뜻이 없다.
    @ViewBuilder
    private var valueArea: some View {
        if memo.isSecure {
            HStack(spacing: 8) {
                Image(systemName: AppSymbol.lockFill)
                    .foregroundColor(theme.textMuted)
                Text(NSLocalizedString("잠긴 값이에요. 눌러서 인증하면 입력돼요.",
                                       comment: "Long-press preview: secure memo value is hidden"))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if memo.stackValues.isEmpty {
                        valueText(memo.value)
                    } else {
                        // 콤보는 단계 번호를 붙여 순서를 보여준다.
                        ForEach(Array(memo.stackValues.enumerated()), id: \.offset) { index, value in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                    .foregroundColor(theme.textFaint)
                                valueText(value)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 값 한 줄 - `{변수}` 는 여기서도 칩으로 보인다(값이 가장 크게 보이는 자리다).
    private func valueText(_ value: String) -> some View {
        Text(value.templateAwareAttributed(accent: theme.accent,
                                           accentSoft: theme.accentSoft,
                                           font: .callout))
            .font(.callout)
            .foregroundColor(theme.text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 할 일

    /// 보안 단축어에는 복사 버튼 자체를 두지 않는다.
    /// (예전에는 opacity·disabled·frame 세 개를 맞춰 숨겼는데, 셋이 어긋나면 안 보이는
    ///  버튼이 자리와 보이스오버 순서를 차지한다)
    ///
    /// 순서 바꾸기는 **잠긴 단축어에도 둔다.** 자리를 옮기는 일에는 값이 필요 없다.
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
            if !memo.isSecure {
                Button(action: onCopy) {
                    HStack(spacing: 6) {
                        Image(systemName: AppSymbol.docOnDoc)
                        Text(NSLocalizedString("Copy to clipboard", comment: "Context menu: copy"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.accentFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let onReorder {
                Button(action: onReorder) {
                    HStack(spacing: 6) {
                        Image(systemName: AppSymbol.arrowUpArrowDown)
                        Text(NSLocalizedString("순서 바꾸기", comment: "Long-press panel: enter reorder mode"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(theme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint(NSLocalizedString("자주 쓰는 단축어를 위로 옮길 수 있어요",
                                                    comment: "Reorder button hint"))
            }
        }
    }
}

// MARK: - 길게 누르면 판이 열린다

/// 키에 붙이는 길게 누르기.
///
/// ⚠️ `simultaneousGesture` 를 쓴다. 키는 버튼이라 자기 탭 제스처를 갖고 있는데,
///    `onLongPressGesture` 로 덮으면 그 탭이 먹히거나 순서가 엉킨다. 나란히 걸면
///    짧게 누르면 입력, 길게 누르면 판이 열리는 두 길이 서로 방해하지 않는다.
///    (콤보 키처럼 안에 버튼이 둘인 경우에도 바깥에서 한 번에 잡을 수 있다)
struct MemoPeekOnLongPress: ViewModifier {
    let memo: Memo
    /// ⚠️ 앱 무대에서는 **꺼 둔다.** 거기서는 같은 길게 누르기가 이미 "클립보드로 복사"이고
    ///    (무대 안내에도 그렇게 적혀 있다), 둘을 같이 걸면 한 번 눌렀는데 복사도 되고
    ///    판도 열린다. 한 손짓에 주인은 하나여야 한다.
    let enabled: Bool
    let onPeek: (Memo) -> Void

    func body(content: Content) -> some View {
        if enabled { gestured(content) } else { content }
    }

    private func gestured(_ content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in onPeek(memo) }
            )
            // 길게 누르기는 눈에 안 보이는 동작이다. 손이 불편한 사람도 닿을 수 있게.
            .accessibilityAction(named: Text(NSLocalizedString("값 크게 보기",
                                                              comment: "Accessibility action: peek at the value"))) {
                onPeek(memo)
            }
    }
}
