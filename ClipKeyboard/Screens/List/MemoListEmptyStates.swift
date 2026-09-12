//
//  MemoListEmptyStates.swift
//  ClipKeyboard
//
//  아직 아무것도 없는 칸에 서는 것들 - 점선 "추가" 카드와 빈 상태 안내.
//
//  ⚠️ `ClipKeyboardList` 에서 꺼냈다. 여기 있는 것들은 **화면의 상태를 읽지 않는다.**
//     무엇을 그릴지는 인자로 받고, 눌렸을 때 무엇을 열지는 닫힘(closure)으로 돌려준다.
//     그래서 목록 화면의 시트 상태 네댓 개가 여기까지 따라오지 않는다.
//

import SwiftUI
import LeeoKit

// MARK: - 추가 카드

/// 그리드 끝에 붙는 점선 "추가" 카드. 즐겨찾기·커스텀·기본 제공 카테고리가 공유.
struct AddMemoCard: View {
    let label: String
    let accessibilityText: String
    /// 카드 높이 - 메모 셀과 같아야 격자가 흔들리지 않는다.
    let cardHeight: CGFloat
    /// 목록 뒤에 사진이 깔려 있는가 - 받침을 반투명 표면으로 할지 프로스트 유리로 할지.
    let hasListBackground: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: AppSymbol.plus)
                    .font(.title2.weight(.medium))
                    .foregroundColor(theme.textFaint)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: cardHeight)  // 메모 셀과 동일 높이
            // 배경 사진 위에서는 반투명 표면이 씻겨 보여 프로스트 유리로 받친다.
            .background {
                if hasListBackground {
                    Rectangle().fill(.ultraThinMaterial)
                } else {
                    theme.surface.opacity(0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous)
                    .strokeBorder(
                        theme.textFaint.opacity(hasListBackground ? 0.5 : 0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }
}

// MARK: - 탭마다 다른 글자

/// 탭에 맞는 "추가" 카드의 글자와, 눌렀을 때 열어야 할 것.
///
/// 글자만 여기서 정하고 **여는 일은 목록 화면이 한다.** 어느 시트를 어떻게 여는지는
/// 그 화면의 사정이라, 여기까지 끌고 오면 시트 상태가 통째로 따라온다.
enum AddCardCopy {
    /// 눌렀을 때 목록 화면이 무엇을 해야 하는지.
    enum Intent: Equatable {
        /// 새 단축어 만들기. 값은 미리 골라 둘 카테고리("" 면 없음).
        case addMemo(category: String)
        case addFavorite
        case addTemplate
        case addStack
    }

    static func label(for tab: CategoryTab) -> String {
        switch tab {
        case .basic, .all:
            return NSLocalizedString("단축어 추가", comment: "Add memo card")
        case .favorites:
            return NSLocalizedString("즐겨찾기 추가", comment: "Add memo to favorites card")
        case .builtIn(let b):
            switch b {
            case .templates: return NSLocalizedString("템플릿 추가", comment: "Add template card")
            case .combos: return NSLocalizedString("콤보 추가", comment: "Add combo card")
            case .images: return NSLocalizedString("이미지 단축어 추가", comment: "Add image memo card")
            case .textMemos: return NSLocalizedString("단축어 추가", comment: "Add memo card")
            }
        case .custom(let name):
            return String(format: NSLocalizedString("'%@' 추가", comment: "Add memo to this category card"), name)
        }
    }

    static func accessibilityText(for tab: CategoryTab) -> String {
        switch tab {
        case .favorites:
            return NSLocalizedString("즐겨찾기 단축어 추가", comment: "Add favorite memo card a11y")
        case .custom(let name):
            return String(format: NSLocalizedString("'%@' 카테고리에 단축어 추가", comment: "Add memo to category a11y"), name)
        default:
            return label(for: tab)
        }
    }

    static func intent(for tab: CategoryTab) -> Intent {
        switch tab {
        case .basic, .all:
            return .addMemo(category: "")
        case .favorites:
            return .addFavorite
        case .builtIn(let b):
            switch b {
            case .templates: return .addTemplate
            case .combos: return .addStack
            case .images: return .addMemo(category: "이미지")
            case .textMemos: return .addMemo(category: "")
            }
        case .custom(let name):
            return .addMemo(category: name)
        }
    }
}

// MARK: - 빈 상태

/// 빈 상태 안내(아이콘+문구) - 배경 사진이 있으면 프로스트 유리 패널을 받쳐
/// 밝은 설경 같은 사진 위에서도 회색 안내가 씻겨 보이지 않게 한다.
struct EmptyStateMessage: View {
    let message: String
    let hasListBackground: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: AppSymbol.tray)
                .font(.system(size: 46, weight: .light))
                .foregroundColor(theme.textFaint)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background {
            if hasListBackground {
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .padding(.horizontal, 32)
    }
}

/// 빈 카테고리 안내 + 상단에 "추가" 카드.
/// (즐겨찾기 빈 상태도 같은 판을 쓴다 - 예전에는 따로 있었고 그래서 따로 어긋났다)
struct EmptyStateWithAddCard: View {
    let message: String
    let tab: CategoryTab
    let columns: [GridItem]
    let cardHeight: CGFloat
    let hasListBackground: Bool
    let onAdd: (AddCardCopy.Intent) -> Void

    var body: some View {
        ZStack(alignment: .center) {
            EmptyStateMessage(message: message, hasListBackground: hasListBackground)
            VStack {
                LazyVGrid(columns: columns, spacing: 12) {
                    AddMemoCard(label: AddCardCopy.label(for: tab),
                                accessibilityText: AddCardCopy.accessibilityText(for: tab),
                                cardHeight: cardHeight,
                                hasListBackground: hasListBackground) {
                        onAdd(AddCardCopy.intent(for: tab))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
