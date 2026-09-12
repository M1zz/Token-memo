//
//  MemoRowView.swift
//  ClipKeyboard
//
//  Created by Leeo on 12/11/25.
//

import SwiftUI

// Separate view for memo row to reduce complexity
// v4.3 Redesign: design-handoff 기반 CatIcon + 인라인 Template/Combo 배지 +
// 새 프리뷰 라인. 기존 business 로직(resolvedType 등)은 그대로 유지.
struct MemoRowView: View {
    let memo: Memo
    let fontSize: CGFloat
    var showFavoriteNudge: Bool = false
    /// compact=true: 홈 리스트용 - 아이콘(CatIcon만), 타이틀, 배지만 표시.
    /// 이미지 썸네일·밸류 미리보기·시간 라벨 숨김.
    var compact: Bool = false

    // VoiceOver 커스텀 액션 콜백 - 부모(ClipKeyboardList)에서 주입
    var onFavoriteToggle: (() -> Void)?
    var onDelete: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 메모 구분 표시 마스터 토글(카드와 동일). 기본 OFF = 제목 위주로 심플.
    @AppStorage("showVisualCues", store: AppGroup.defaults)
    private var showVisualCues: Bool = false
    // 오직 앱 토글만 따른다(iOS "색상 없이 구별"과 무관).
    private var visualCuesVisible: Bool { showVisualCues }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if visualCuesVisible {
                leadingIcon
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(memo.title.templateAwareAttributed(
                    theme: theme, font: theme.bodyFont(style: .subheadline, weight: .semibold)))
                    .font(theme.bodyFont(style: .subheadline, weight: .semibold))
                    .foregroundColor(theme.text)

                if visualCuesVisible {
                    badgesRow
                }

                if !compact {
                    let previewText = MemoPreviewFormatter.preview(for: memo, resolvedType: resolvedType)
                    if !previewText.isEmpty {
                        Text(previewText.templateAwareAttributed(
                            theme: theme, font: theme.bodyFont(style: .footnote)))
                            .font(theme.bodyFont(style: .footnote))
                            .foregroundColor(theme.textMuted)
                            .lineLimit(3)
                    }
                }

                if !compact, let hint = memo.hint, !hint.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: AppSymbol.lightbulbFill)
                            .font(.caption2)
                            .foregroundColor(.yellow.opacity(0.7))
                        Text(hint.templateAwareAttributed(theme: theme, font: .caption2))
                            .font(.caption2)
                            .foregroundColor(theme.textFaint)
                            .lineLimit(1)
                    }
                    .padding(.top, 1)
                }

                if !compact, let relative = relativeTimeLabel {
                    Text(relative)
                        .font(.caption2)
                        .foregroundColor(theme.textFaint)
                        .padding(.top, 1)
                }
            }

            Spacer()

            // 날인 자국 - 많이 쓴 문구일수록 잉크가 진해진다.
            // 숫자 배지가 아니라 흔적으로 보여주는 이유는 DelightMotion.inkOpacity 주석 참고.
            // 다른 구분 표시와 같은 게이트를 따른다(기본 OFF = 제목 위주).
            if visualCuesVisible, memo.clipCount > 0 {
                StampMark(useCount: memo.clipCount, size: 20, angle: stampAngle)
            }

            // 즐겨찾기 하트 표시 (구분 표시 ON일 때만)
            if visualCuesVisible, memo.isFavorite {
                Image(systemName: AppSymbol.heartFill)
                    .font(.body)
                    .foregroundColor(.pink)
                    .accessibilityHidden(true)
            }

            if showFavoriteNudge {
                FavoriteNudgeHeart(reduceMotion: reduceMotion)
            }
        }
        // MARK: - Accessibility
        // 행 전체를 단일 요소로 묶어 VoiceOver가 자연스러운 순서로 읽도록 함
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)
        .accessibilityHint(NSLocalizedString("탭하면 클립보드에 복사됩니다", comment: "Memo row accessibility hint"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: memo.isFavorite
            ? NSLocalizedString("즐겨찾기 해제", comment: "VoiceOver action: remove favorite")
            : NSLocalizedString("즐겨찾기 추가", comment: "VoiceOver action: add favorite")
        ) { onFavoriteToggle?() }
        .accessibilityAction(named: NSLocalizedString("삭제", comment: "VoiceOver action: delete memo")) {
            onDelete?()
        }
    }

    // MARK: - Badges Row

    @ViewBuilder
    private var badgesRow: some View {
        if memo.isTemplate
            || memo.isStack
            || (memo.clipCount == 0 && Date().timeIntervalSince(memo.lastEdited) < 86400)
            || memo.isSecure {
            HStack(spacing: 6) {
                if memo.isTemplate {
                    TagBadge(label: NSLocalizedString("Template", comment: "Tag: template"))
                }
                if memo.isStack {
                    TagBadge(label: NSLocalizedString("Combo", comment: "Tag: combo"))
                }
                if memo.clipCount == 0 && Date().timeIntervalSince(memo.lastEdited) < 86400 {
                    TagBadge(label: NSLocalizedString("New", comment: "Badge: new memo within 24h"), tint: .green)
                }
                if memo.isSecure {
                    // 자물쇠 아이콘 대신 봉랍 - 잠겨 있다는 사실이 감각으로 읽히게.
                    // 행 자체가 탭 대상이라 여기서는 장식(onTap 없음)으로만 쓴다.
                    WaxSealView(isSealed: true, size: 16)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - Accessibility Label

    private var voiceOverLabel: String {
        var parts: [String] = []

        // 1. 카테고리 (위치 컨텍스트)
        if let type = resolvedType {
            parts.append(type.localizedName)
        } else {
            let cat = ClipCategory.from(itemType: nil)
            parts.append(cat.localizedLabel)
        }

        // 2. 제목
        parts.append(memo.title)

        // 3. 상태 배지
        if memo.isSecure {
            parts.append(NSLocalizedString("보안 단축어", comment: "VoiceOver: secure memo badge"))
        }
        if memo.isTemplate {
            parts.append(NSLocalizedString("템플릿", comment: "VoiceOver: template badge"))
        }
        if memo.isStack {
            parts.append(NSLocalizedString("콤보", comment: "VoiceOver: combo badge"))
        }
        if memo.isFavorite {
            parts.append(NSLocalizedString("즐겨찾기", comment: "VoiceOver: favorite badge"))
        }
        if memo.clipCount == 0 && Date().timeIntervalSince(memo.lastEdited) < 86400 {
            parts.append(NSLocalizedString("새로 추가됨", comment: "VoiceOver: new memo badge"))
        }

        // 4. 내용 미리보기 (MemoPreviewFormatter의 접근성 텍스트 활용)
        let preview = MemoPreviewFormatter.accessibilityPreview(for: memo, resolvedType: resolvedType)
        if !preview.isEmpty { parts.append(preview) }

        // 5. 사용 시간
        if let relative = relativeTimeLabel {
            parts.append(relative)
        }

        // 6. 사용 횟수 - 날인 자국은 시각 요소라 VoiceOver에는 숫자로 읽어 준다.
        if memo.clipCount > 0 {
            parts.append(String(format: NSLocalizedString("%d회 사용", comment: "VoiceOver: use count"), memo.clipCount))
        }

        return parts.joined(separator: ", ")
    }

    /// 날인 각도 - 행마다 조금씩 달라야 손으로 찍은 것처럼 보인다.
    /// 메모 id에서 뽑으므로 스크롤·리렌더에도 값이 흔들리지 않는다.
    private var stampAngle: Double {
        let bucket = abs(memo.id.hashValue % 5)
        return [-9.0, -4.0, 0.0, 5.0, 9.0][bucket]
    }

    // MARK: - Leading Icon

    /// 좌측 아이콘 - 항상 카테고리 CatIcon 사용.
    private var leadingIcon: some View {
        CatIcon(category: ClipCategory.from(itemType: resolvedType), size: 40)
    }

    /// 현재 메모에 적용할 타입 결정.
    private var resolvedType: ClipboardItemType? {
        ClipboardClassificationService.shared.resolvedType(for: memo)
    }

    // MARK: - Time / Usage Signals

    /// "3분 전" 같은 상대 시간 라벨. lastUsedAt 우선, 없으면 lastEdited 폴백.
    private var relativeTimeLabel: String? {
        let reference = memo.lastUsedAt ?? memo.lastEdited
        let interval = Date().timeIntervalSince(reference)
        guard interval >= 0 else { return nil }
        if interval > 60 * 60 * 24 * 30 { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: reference, relativeTo: Date())
    }
}

// MARK: - Favorite Nudge Heart Animation

/// 즐겨찾기 넛지 하트 애니메이션 뷰
/// reduceMotion ON: 페이드만, OFF: spring으로 튀어나오고 3초 후 fade out
struct FavoriteNudgeHeart: View {
    let reduceMotion: Bool
    @State private var appear = false

    var body: some View {
        Image(systemName: AppSymbol.heartFill)
            .font(.title3)
            .foregroundColor(.pink)
            .opacity(appear ? 1 : 0)
            .offset(x: reduceMotion ? 0 : (appear ? 0 : 40))
            .scaleEffect(reduceMotion ? 1 : (appear ? 1.0 : 0.5))
            .onAppear {
                let animation: Animation = reduceMotion
                    ? .easeIn(duration: 0.2)
                    : .spring(response: 0.5, dampingFraction: 0.4)
                withAnimation(animation) { appear = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.4)) { appear = false }
                }
            }
            .accessibilityHidden(true)
    }
}
