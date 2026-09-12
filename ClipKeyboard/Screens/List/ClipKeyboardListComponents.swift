//
//  ClipKeyboardListComponents.swift
//  ClipKeyboard
//
//  ClipKeyboardList에서 분리한 보조 뷰/시트/배너/필터/팁 모음.
//  (메인 뷰는 ClipKeyboardList.swift 유지)
//

import SwiftUI
import TipKit
import LocalAuthentication
import LeeoKit

// MARK: - Pro Value Nudge Banner

/// 무료 유저가 가치를 느낀 순간(시간 절약 누적·한도 근접)에 1회 노출되는 Pro 넛지.
/// 페이월 노출률을 높이는 상단 레버 - 탭하면 페이월, ×면 영구 닫힘.
struct ProValueNudgeBanner: View {
    let message: String
    let onTap: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: AppSymbol.crownFill)
                    .font(.title3)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(NSLocalizedString("Pro 보기", comment: "Pro nudge CTA"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: AppSymbol.xmark)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.textFaint)
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(NSLocalizedString("닫기", comment: "Close / dismiss"))
            }
            .padding(14)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous)
                    .stroke(.orange.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityHint(NSLocalizedString("탭하면 Pro 업그레이드 보기", comment: "VoiceOver: open paywall"))
    }
}

// MARK: - Paste Permission Tip Banner (메인 화면)

/// '다른 앱에서 붙여넣기' 안내를 띄워도 되는 시점인지 판단한다.
/// iOS 설정의 이 토글은 설치 직후엔 없고, 앱이 붙여넣기를 몇 차례 시도한 뒤에야
/// 설정 앱에 나타난다. 설치하자마자 안내하면 설정에 항목이 없어 사용자가 헤매므로,
/// 시스템 팝업을 몇 번 겪었을 시점(3번째 실행)부터 안내한다.
/// 메인 배너·클립보드 탭 배너·클립보드 첫 진입 알럿이 모두 이 게이트를 공유한다.
enum PastePermissionGuidance {

    /// 설치하고 **며칠**이 지나야 클립보드를 건드리는가.
    ///
    /// ⚠️ iOS는 앱이 클립보드를 **읽는 순간** "붙여넣기 허용?" 팝업을 띄운다.
    ///    설치 첫날 그게 뜨면 신규 사용자가 이 앱에서 보는 첫 다이얼로그가 권한 요청이 된다
    ///    무엇을 하는 앱인지 알기도 전에 거절할지를 묻는 셈이다.
    ///    며칠 써 보고 "복사한 게 여기 모이는구나"를 안 다음이라야 허용할 이유가 생긴다.
    static let warmUpDays = 3

    /// 설치일. 없으면 **지금으로 친다** - 모르는 채로 곧장 팝업을 부르는 것보다
    /// 며칠 기다리는 쪽이 안전하다. (보통은 ReviewManager가 첫 실행에 이미 찍어 둔다)
    ///
    /// ⚠️ 여기서 **값을 쓰지 않는다.** 읽기만 하는 자리에서 쓰면 남의 정리(테스트·초기화)를
    ///    조용히 되돌려 놓는다 - 실제로 리뷰 데이터 초기화 테스트가 이 부작용으로 깨졌다.
    private static var installDate: Date {
        UserDefaults.standard.object(forKey: "app_install_date") as? Date ?? Date()
    }

    /// 설치 후 `warmUpDays` 가 지났는가. **클립보드를 자동으로 읽어도 되는 때**의 기준.
    static var isWarmedUp: Bool {
        Date().timeIntervalSince(installDate) >= Double(warmUpDays) * 24 * 60 * 60
    }

    /// 클립보드를 **알아서** 읽어도 되는가(= iOS 팝업을 불러도 되는가).
    ///
    /// ⚠️ 사용자가 직접 누른 붙여넣기는 이 관문을 거치지 않는다. 자기가 누른 팝업은
    ///    이유가 분명하고, 막으면 기능이 죽는다. 막는 건 **묻지도 않았는데 읽는 것**뿐이다.
    static var mayAutoReadClipboard: Bool { isWarmedUp }

    /// 우리 안내(배너·알림)를 띄워도 되는가.
    ///
    /// 설치 직후엔 iOS 설정에 '다른 앱에서 붙여넣기' 항목이 아직 없어 안내가 헛돈다.
    /// 그래서 **며칠 지났고 + 몇 번 열어 본** 다음에만 말을 건다.
    static var isReady: Bool {
        isWarmedUp && UserDefaults.standard.integer(forKey: DefaultsKey.appLaunchCount) >= 3
    }
}

/// 앱을 열 때마다 iOS "붙여넣기 허용" 팝업이 뜨는 사용자를 위한 안내.
/// 클립보드를 읽어 최근 복사 카드를 만드는 지점(메인 리스트)이 곧 팝업이 뜨는 지점이라
/// 여기에서 바로 설정으로 안내한다. 설정 → 앱 → '다른 앱에서 붙여넣기' → 허용.
/// "허용하러 가기" → 앱 설정 열기, "다시 안 보기" → 영구 닫힘(pasteTipDismissed 공유).
/// 노출 시점은 PastePermissionGuidance.isReady가 판단한다(설치 직후 제외).
struct PastePermissionTipBanner: View {
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("붙여넣기 팝업이 자꾸 뜨나요?", comment: "Paste permission main tip title"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)

                    Text(NSLocalizedString("설정 → ClipKeyboard → 다른 앱에서 붙여넣기 → 허용으로 바꾸면 팝업 없이 바로 정리돼요.", comment: "Paste permission main tip body"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: AppSymbol.xmark)
                        .font(.caption2)
                        .foregroundColor(theme.textFaint)
                        .padding(6)
                        .background(theme.divider)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("닫기", comment: "Close / dismiss"))
            }

            HStack(spacing: 18) {
                Button(action: onOpenSettings) {
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("허용하러 가기", comment: "Go to Settings to allow paste"))
                            .font(.body)
                            .fontWeight(.semibold)
                        Image(systemName: AppSymbol.arrowUpForwardApp)
                            .font(.caption)
                    }
                    .foregroundColor(theme.accent)
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text(NSLocalizedString("더 이상 보지 않기", comment: "Don't show paste tip again"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
    }
}

// MARK: - Category Activation Banner (v4.1.0)

/// 카테고리 기능이 미활성일 때 메모가 5개 이상이면 상단에 노출.
/// "쓸래요" → enableFeature, "안 쓸래요" → dismissActivationBanner (영구 닫힘).
struct CategoryActivationBanner: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: AppSymbol.folderBadgePlus)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("단축어가 늘었어요", comment: "Category activation banner title"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.text)
                    Text(NSLocalizedString("카테고리로 분류해서 빠르게 찾아볼까요?", comment: "Category activation banner subtitle"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text(NSLocalizedString("괜찮아요", comment: "Decline category activation"))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.surfaceAlt)
                        .clipShape(Capsule())
                }
                Button(action: onEnable) {
                    Text(NSLocalizedString("써볼게요", comment: "Accept category activation"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.accentForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Memo Action Sheet (long-press menu)

/// 메모 카드를 long-press 했을 때 뜨는 커스텀 bottom sheet.
/// confirmationDialog는 iOS에서 button icon을 렌더링 안 해서 자체 시트로 구현.
/// 각 행에 SF Symbol + 텍스트 표시 (삭제는 빨간색).
struct MemoActionSheet: View {
    let memo: Memo
    /// 이동 대상 카테고리 목록 (키보드 페이지와 동일한 통일 목록).
    var categories: [String] = []
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    /// 메모를 다른 카테고리로 이동. nil이면 이동 행을 표시하지 않는다.
    var onMoveToCategory: ((String) -> Void)?
    /// "새 카테고리에 추가" - 즉석 생성 후 이 메모 이동 (호스트가 alert 표시).
    var onCreateNewCategory: (() -> Void)?
    /// "순서 바꾸기" - 그리드 흔들기/드래그 재정렬 모드 진입. nil이면 행을 숨긴다.
    var onReorder: (() -> Void)?
    /// "여러 개 고르기" - 이 카드를 미리 고른 채 일괄 선택 모드로 들어간다. nil이면 행을 숨긴다.
    /// 두 손가락 탭이 같은 문을 열지만, 그 몸짓은 눈에 보이지 않아 여기에도 둔다.
    var onSelectMultiple: (() -> Void)?
    /// "템플릿으로 만들기" - 편집 화면을 열고 본문에 포커스를 둬 변수 삽입바를 바로 노출.
    /// nil이거나 이미 템플릿/콤보/이미지 메모면 행을 숨긴다.
    var onMakeTemplate: (() -> Void)?
    /// 튜토리얼이 지금 이 줄을 고르라고 안내하는 중인가 - 색과 한 줄 안내로 가리킨다.
    /// ⚠️ 메뉴 안에서는 코치 말풍선을 얹을 수 없다. 줄 자체가 스스로 도드라져야 한다.
    var highlightsMakeTemplate: Bool = false
    /// "보안 메모로 설정 / 보안 해제" - 값을 암호화/복호화. 해제 시 호스트에서 생체 인증.
    var onToggleSecure: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    /// 시트 높이 - 내용 실측으로 갱신. 고정 높이는 행 개수·Dynamic Type에 따라
    /// 하단 행(보안 설정/삭제)이 잘려 보이지 않는 문제가 있었다.
    @State private var contentHeight: CGFloat = 530

    var body: some View {
        ScrollView {
            sheetContent
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newValue in
                    contentHeight = newValue
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.bg)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            // 헤더 - 메모 제목
            HStack {
                Text(memo.title.templateAwareAttributed(theme: theme, font: .headline))
                    .font(.headline)
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // 액션 그룹
            VStack(spacing: 0) {
                actionRow(
                    label: NSLocalizedString("복사", comment: "Action: copy"),
                    systemImage: AppSymbol.docOnDoc
                ) {
                    onCopy()
                    dismiss()
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: memo.isFavorite
                        ? NSLocalizedString("즐겨찾기 해제", comment: "Action: remove favorite")
                        : NSLocalizedString("즐겨찾기 추가", comment: "Action: add favorite"),
                    systemImage: memo.isFavorite ? "heart.slash" : "heart"
                ) {
                    onToggleFavorite()
                    dismiss()
                }
                // 카테고리 지정 - 미분류(흰 배경) 메모는 "추가", 이미 카테고리가 있으면 "이동".
                if let onMoveToCategory {
                    // 카드가 실제로 색을 갖는 조건과 동일(기능 활성 + 커스텀 카테고리 소속)
                    let hasCategory = CategoryStore.shared.isFeatureEnabled && categories.contains(memo.category)
                    Divider().padding(.leading, 56)
                    Menu {
                        // 즐겨찾기 - '전체' 탭은 지정 대상이 아니지만 즐겨찾기는 카테고리처럼 지정 가능.
                        Button {
                            onToggleFavorite()
                            dismiss()
                        } label: {
                            Label(NSLocalizedString("즐겨찾기", comment: "Favorites"),
                                  systemImage: memo.isFavorite ? "checkmark" : "heart")
                        }
                        Divider()
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                onMoveToCategory(cat)
                                dismiss()
                            } label: {
                                // 각 카테고리에 그 카테고리 심볼을 붙여 표시(현재 카테고리는 체크).
                                Label(cat, systemImage: memo.category == cat ? "checkmark" : categoryIcon(cat))
                            }
                        }
                        if let onCreateNewCategory {
                            Divider()
                            Button {
                                dismiss()
                                onCreateNewCategory()
                            } label: {
                                Label(NSLocalizedString("새 카테고리에 추가", comment: "Create new category and assign memo"), systemImage: AppSymbol.folderBadgePlus)
                            }
                        }
                        if hasCategory {
                            Divider()
                            Button {
                                onMoveToCategory("기본")
                                dismiss()
                            } label: {
                                Label(NSLocalizedString("카테고리에서 빼기", comment: "Action: remove memo from its category"), systemImage: AppSymbol.tray)
                            }
                        }
                    } label: {
                        actionRowLabel(
                            label: hasCategory
                                ? NSLocalizedString("카테고리 이동", comment: "Action: move to category")
                                : NSLocalizedString("카테고리에 추가", comment: "Action: add to category"),
                            systemImage: AppSymbol.folder
                        )
                    }
                }
                if let onSelectMultiple {
                    Divider().padding(.leading, 56)
                    actionRow(
                        label: NSLocalizedString("여러 개 고르기", comment: "Action: select multiple memos"),
                        systemImage: AppSymbol.checkmarkCircle
                    ) {
                        dismiss()
                        onSelectMultiple()
                    }
                }
                if let onReorder {
                    Divider().padding(.leading, 56)
                    actionRow(
                        label: NSLocalizedString("순서 바꾸기", comment: "Action: reorder memos"),
                        systemImage: AppSymbol.arrowUpArrowDown
                    ) {
                        dismiss()
                        onReorder()
                    }
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: NSLocalizedString("수정", comment: "Action: edit"),
                    systemImage: AppSymbol.pencil
                ) {
                    dismiss()
                    onEdit()
                }
                // 템플릿으로 만들기 - 아직 템플릿/콤보가 아닌 일반 텍스트 메모에서만 노출
                // (보안 메모는 값이 암호문이라 제외).
                if let onMakeTemplate, !memo.isTemplate, !memo.isStack, !memo.isSecure, memo.contentType == .text {
                    Divider().padding(.leading, 56)
                    actionRow(
                        label: NSLocalizedString("템플릿으로 만들기", comment: "Action: turn memo into a template"),
                        systemImage: AppSymbol.wandAndSparkles
                    ) {
                        dismiss()
                        onMakeTemplate()
                    }
                    .background(highlightsMakeTemplate ? Color.accentColor.opacity(0.12) : .clear)
                    .overlay(alignment: .trailing) {
                        if highlightsMakeTemplate {
                            Text(NSLocalizedString("여기예요", comment: "Tutorial pointer in action sheet"))
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color.accentForeground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.accentColor))
                                .padding(.trailing, 16)
                        }
                    }
                }
                // 보안 메모 설정/해제 - 텍스트 메모에서만(이미지는 제외, 콤보는 단계 값까지 암호화).
                if let onToggleSecure, memo.contentType == .text {
                    Divider().padding(.leading, 56)
                    actionRow(
                        label: memo.isSecure
                            ? NSLocalizedString("보안 해제", comment: "Action: remove secure lock from memo")
                            : NSLocalizedString("보안 단축어로 설정", comment: "Action: make memo secure"),
                        systemImage: memo.isSecure ? "lock.open" : "lock"
                    ) {
                        dismiss()
                        onToggleSecure()
                    }
                }
                Divider().padding(.leading, 56)
                actionRow(
                    label: NSLocalizedString("삭제", comment: "Action: delete"),
                    systemImage: AppSymbol.trash,
                    isDestructive: true
                ) {
                    dismiss()
                    onDelete()
                }
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            .padding(.horizontal, 16)

            Spacer(minLength: 12)

            // 취소
            Button {
                dismiss()
            } label: {
                Text(NSLocalizedString("취소", comment: "Cancel"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLg, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private func actionRow(
        label: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionRowLabel(label: label, systemImage: systemImage, isDestructive: isDestructive)
        }
        .buttonStyle(.plain)
    }

    /// 행 라벨 비주얼 - Button과 Menu(카테고리 이동)가 공유.
    private func actionRowLabel(
        label: String,
        systemImage: String,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 24, alignment: .center)
                .foregroundColor(isDestructive ? .red : theme.text)
            Text(label)
                .font(.body)
                .foregroundColor(isDestructive ? .red : theme.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    /// 카테고리 심볼 - 카드/키보드와 동일(사용자 지정 우선, 없으면 기본 팔레트).
    private func categoryIcon(_ name: String) -> String {
        categorySymbol(for: name, in: categories)
    }
}

// MARK: - Category Suggestion Tip (TipKit)

/// 메모를 보고 "이 카테고리를 만들어 정리할까요?"를 부드럽게 제안하는 팁.
/// 메모는 자동 분류로 이미 `category` 값을 갖고 있어, 카테고리를 추가하면 곧바로 모인다.
/// id에 카테고리 rawValue를 포함 → 카테고리별로 1회씩 노출/무효화가 추적된다.
struct CategorySuggestionTip: Tip {
    let categoryRawName: String
    let displayName: String
    let count: Int

    var id: String { "category-suggestion-\(categoryRawName)" }

    var title: Text {
        Text(String(format: NSLocalizedString("'%@' 단축어가 %d개 있어요", comment: "Category suggestion tip title: category name, memo count"),
                    displayName, count))
    }

    var message: Text? {
        Text(String(format: NSLocalizedString("'%@' 카테고리를 만들어 한 곳에 모아드릴까요?", comment: "Category suggestion tip message: category name"),
                    displayName))
    }


    var actions: [Tips.Action] {
        [Tips.Action(id: "create") {
            Text(NSLocalizedString("카테고리 만들기", comment: "Category suggestion: create action button"))
        }]
    }
}

/// 페르소나에 맞는 카테고리 '이름'을 제안하는 팁. 액션(카테고리명)을 탭하면 그 카테고리를 만든다.
struct PersonaCategoryTip: Tip {
    let suggestions: [String]

    var id: String { "persona-category-suggestion" }

    var title: Text {
        Text(NSLocalizedString("이런 카테고리는 어때요?", comment: "Persona category suggestion tip title"))
    }
    var message: Text? {
        Text(NSLocalizedString("선택한 사용 패턴에 맞는 카테고리예요. 탭하면 만들어서 단축어를 한곳에 모을 수 있어요.", comment: "Persona category suggestion tip message"))
    }
    var actions: [Tips.Action] {
        suggestions.map { name in Tips.Action(id: name) { Text(name) } }
    }
}

struct SwipePageIndicator: View {
    let total: Int
    let selectedIndex: Int
    var accentColor: Color = Color.accentColor

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? accentColor : theme.textFaint.opacity(0.35))
                    .frame(width: index == selectedIndex ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: selectedIndex)
        .animation(.easeInOut(duration: 0.3), value: accentColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // 콘텐츠 위에 떠 있는 인디케이터 - Liquid Glass 캡슐. (iOS 26)
        .glassEffect(in: Capsule())
    }
}


// MARK: - Memo Type Filter Bar

struct FilterExpandChip: View {
    let isExpanded: Bool
    let hiddenCount: Int
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(isExpanded
                     ? NSLocalizedString("접기", comment: "Collapse filter bar")
                     : String(format: NSLocalizedString("+%d개", comment: "More filter count"), hiddenCount))
                    .font(.footnote.weight(.medium))
                Image(systemName: isExpanded ? "chevron.left" : "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.surfaceAlt)
            .cornerRadius(theme.radiusLg)
            .foregroundColor(theme.textMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded
            ? NSLocalizedString("접기", comment: "Collapse filter bar")
            : String(format: NSLocalizedString("%d개 카테고리 더 보기", comment: "More categories a11y"), hiddenCount))
    }
}

struct MemoFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    var color: String = "blue"
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .medium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.1)
                    )
                    .cornerRadius(theme.radiusSm)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusLg)
                    .fill(isSelected ? Color.fromName(color) : theme.surfaceAlt)
                    .shadow(
                        color: isSelected ? Color.fromName(color).opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            .foregroundColor(isSelected ? .white : theme.textFaint)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusLg)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.2) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.96)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(
            String(format: NSLocalizedString("%@, %d개", comment: "Filter chip: name and count"), title, count)
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(
            isSelected
                ? NSLocalizedString("현재 선택됨", comment: "Filter chip: currently selected")
                : NSLocalizedString("탭하여 이 유형으로 필터링", comment: "Filter chip: tap to filter")
        )
    }
}

// MARK: - Sheet Modifiers
/// 모든 Sheet 프레젠테이션을 관리하는 ViewModifier
struct SheetModifiers: ViewModifier {
    // Sheet 표시 상태
    @Binding var showTemplateInputSheet: Bool
    @Binding var showPlaceholderManagementSheet: Bool
    @Binding var selectedTemplateIdForSheet: UUID?
    @Binding var selectedStackIdForSheet: UUID?

    // 데이터
    let templatePlaceholders: [String]
    @Binding var templateInputs: [String: String]
    let memos: [Memo]
    let currentTemplateMemo: Memo?
    /// v4.0.8: attachedTemplate 흐름이면 본 메모(계좌번호 등). preview 결합용.
    let attachedTemplateBaseMemo: Memo?

    // 콜백
    let onTemplateComplete: () -> Void
    let onTemplateCancel: () -> Void
    let onTemplateCopy: (Memo, String) -> Void
    let onTemplateSheetCancel: () -> Void
    let onStackDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            // 템플릿 입력 시트
            .sheet(isPresented: $showTemplateInputSheet) {
                if let template = currentTemplateMemo {
                    TemplateInputSheet(
                        placeholders: templatePlaceholders,
                        inputs: $templateInputs,
                        onComplete: onTemplateComplete,
                        onCancel: onTemplateCancel,
                        originalText: template.value,
                        baseMemoValue: attachedTemplateBaseMemo?.value ?? "",
                        sourceMemoId: template.id,
                        sourceMemoTitle: template.title
                    )
                    // 메모+템플릿은 합쳐진 결과가 길어 전체 높이로, 일반 템플릿은 중간 높이도 허용.
                    .presentationDetents(attachedTemplateBaseMemo != nil ? [.large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            // 빈칸 관리 시트
            .sheet(isPresented: $showPlaceholderManagementSheet) {
                PlaceholderManagementSheet(allMemos: memos)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            // 템플릿 값 입력 하프모달 - 탭하면 키보드 익스텐션과 동일한 UX로
            // 변수를 채우고 우상단 "복사"로 결과를 클립보드에 복사.
            .sheet(item: $selectedTemplateIdForSheet) { templateId in
                if let memo = memos.first(where: { $0.id == templateId }) {
                    TemplateFillSheet(
                        memo: memo,
                        onCopy: { resolved in onTemplateCopy(memo, resolved) },
                        onCancel: onTemplateSheetCancel
                    )
                } else {
                    // 폴백(거의 발생 안 함): 기존 편집 시트.
                    TemplateSheetResolver(
                        templateId: templateId,
                        allMemos: memos,
                        onCopy: onTemplateCopy,
                        onCancel: onTemplateSheetCancel
                    )
                }
            }
            // Combo 미리보기 하프모달 - 탭 시 즉시 복사되고, 순차 입력될 값들을 보여준다.
            .sheet(item: $selectedStackIdForSheet) { stackId in
                StackPreviewSheet(
                    stackId: stackId,
                    allMemos: memos,
                    onDismiss: onStackDismiss
                )
                // 템플릿 fill 시트와 동일하게 하프모달(필요 시 위로 확장).
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}

