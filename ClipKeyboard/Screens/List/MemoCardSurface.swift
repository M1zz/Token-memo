//
//  MemoCardSurface.swift
//  ClipKeyboard
//
//  단축어 카드의 **얼굴**. 제스처는 없다, 그리기만 한다.
//
//  세 화면이 같은 얼굴을 쓴다: 목록 격자(탭·꾹 누르기), 순서 바꾸기(흔들림·드래그),
//  여러 개 고르기(체크). 손이 닿는 방식만 다르고 카드가 어떻게 생겼는지는 하나여야 한다.
//
//  ⚠️ `ClipKeyboardList` 안에 있던 것을 꺼냈다. 거기서는 화면이 쥐고 있는 열댓 개의
//     상태를 아무 데서나 집어 쓸 수 있어서, 카드 하나를 고치려면 3,400줄짜리 화면을
//     통째로 읽어야 했다. 여기서는 **필요한 것을 다 받아 온다.** 무엇에 기대는지가
//     생성자 한 줄에 다 적혀 있고, 그게 이 파일이 존재하는 이유다.
//

import SwiftUI

struct MemoCardSurface: View {

    let memo: Memo

    /// 지금 만들어 둔 카테고리 목록. 색과 심볼이 이 목록에서의 자리로 정해진다
    /// (`categoryTint` · `categorySymbol`), 그래서 이름만으로는 못 그린다.
    let categories: [String]

    /// 카드 높이 - 디스플레이 설정(작게 110 / 보통 140 / 크게 180).
    let cardHeight: CGFloat

    /// 메모 구분 표시 - 타입 아이콘·즐겨찾기·카테고리 심볼을 윗줄에 세울지.
    let showsVisualCues: Bool

    /// 내용 힌트 자리를 둘지. 켜져 있으면 보여줄 것이 없어도 자리는 잡는다
    /// (카드마다 높이가 들쭉날쭉하면 격자가 흔들린다).
    let showsContentHint: Bool

    /// 목록 뒤에 사진이 깔려 있는가 - 글자 뒤 할로를 깔지 정하는 데만 쓴다.
    let hasListBackground: Bool

    /// 이 카드가 지금 내용 대신 동전을 보여줄 차례인가(금고 스킨).
    let showsCoin: Bool

    /// 재정렬 격자용 경량 렌더링 - 내용 힌트와 동전을 생략한다.
    /// 흔들림(repeatForever 회전)과 매 프레임 경합하는 비용을 줄여 드래그를 매끄럽게.
    let lightweight: Bool

    @Environment(\.appTheme) private var theme

    init(memo: Memo,
         categories: [String],
         cardHeight: CGFloat,
         showsVisualCues: Bool,
         showsContentHint: Bool,
         hasListBackground: Bool,
         showsCoin: Bool = false,
         lightweight: Bool = false) {
        self.memo = memo
        self.categories = categories
        self.cardHeight = cardHeight
        self.showsVisualCues = showsVisualCues
        self.showsContentHint = showsContentHint
        self.hasListBackground = hasListBackground
        self.showsCoin = showsCoin
        self.lightweight = lightweight
    }

    // MARK: - Body

    var body: some View {
        let imageFileName = memo.imageFileNames.first ?? memo.imageFileName ?? ""
        let hasImage = !imageFileName.isEmpty
        let onColor = isColored(hasImage: hasImage)

        return VStack(alignment: .leading, spacing: 0) {
            if showsVisualCues {
                cueRow(onColor: onColor)
                Spacer(minLength: 16)
            }
            titleRow(onColor: onColor)
            if showsContentHint {
                Spacer(minLength: 8)
                hintZone(onColor: onColor)
            }
        }
        // 유리 카드 글자 가독성 - 유리는 뒤 배경(사진·색)에 따라 글자가 묻힐 수 있어,
        // 글 내용 뒤에 은은한 할로를 깐다. 언제 까는지는 `textHaloColor` 참고.
        .modifier(CardTextHalo(color: textHaloColor(hasImage: hasImage, onColor: onColor)))
        .padding(16)
        // 모든 메모 셀 동일 높이: 제목 2줄(최대 콘텐츠)보다 큰 값으로 floor를 잡아
        // 1줄·2줄 제목 모두 같은 높이로 정렬되게 한다. (제목은 2줄로 제한)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
        // 배경은 단색이 그대로 얼굴이다(사진 카드는 사진).
        //
        // ⚠️ 예전에는 텍스트 카드에 `glassEffect` 를 얹었다. 걷어낸 이유는 그 유리가
        //    **뒤를 실시간으로 읽어야** 하기 때문이다. 카테고리 페이지를 넘길 때는 옆
        //    페이지가 지어졌다 헐리기를 반복하는데, 그 사이 유리가 읽을 뒤가 없어
        //    카드가 번쩍인다. `CardGlass` 주석에 그 증상이 이미 적혀 있었고
        //    (0.27~0.67초 동안 잿빛), 변형을 `.clear` 에서 `.regular` 로 바꿔 완화했을 뿐
        //    없애지는 못했다. 유리를 안 쓰면 읽을 뒤가 없어도 될 일이 없다.
        //
        //    색 정체성(즐겨찾기 분홍·카테고리 색)은 그대로다. 유리의 tint 로 내던 것을
        //    `cardBackground` 가 단색으로 낸다. 같은 규칙, 같은 색이다.
        .background {
            cardBackground(imageFileName: imageFileName, hasImage: hasImage)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        // ⚠️ 카드는 **단색 면 하나**다. 유리도, 두께도, 그림자도, 타입 테두리도 없다.
        //    종류(템플릿·콤보·보안)는 좌상단 아이콘이, 카테고리는 색이 말한다.
    }

    // MARK: - 줄 셋

    /// 구분 표시 ON일 때만 서는 윗줄(좌: 타입 아이콘 / 우: 즐겨찾기·카테고리 심볼).
    private func cueRow(onColor: Bool) -> some View {
        HStack(alignment: .top, spacing: 4) {
            // 보안 메모는 제목 왼쪽 자물쇠로 표시하므로 상단 타입 아이콘에서는 생략(중복 방지).
            if !memo.isSecure {
                typeIcon(onColor: onColor)
            }
            Spacer()
            if memo.isFavorite {
                Image(systemName: AppSymbol.heartFill)
                    .font(.title2)
                    .foregroundColor(onColor ? .white.opacity(0.9) : .clipFavorite)
                    .accessibilityHidden(true)
            } else if hasCustomCategory {
                Image(systemName: categorySymbol(for: memo.category, in: categories))
                    .font(.title2)
                    .foregroundColor(onColor
                        ? .white.opacity(0.85)
                        : categoryTint(for: memo.category, in: categories))
                    .accessibilityHidden(true)
            }
        }
    }

    private func titleRow(onColor: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            // 보안 단축어 자물쇠 - **구분 표시 설정과 무관하게 언제나 보인다.**
            //
            // ⚠️ 예전에는 구분 표시가 켜져 있을 때만 그렸다. 그 설정은 기본이 꺼짐이라,
            //    대부분의 사람에게 보안 단축어와 보통 단축어가 **겉으로 구별되지 않았다.**
            //    구분 표시는 "있으면 좋은 꾸밈"을 켜는 스위치지, 잠겨 있다는 사실을
            //    감출 스위치가 아니다.
            //    (목록 행 모양은 원래부터 봉랍을 늘 보여 준다, `MemoRowView`)
            if memo.isSecure {
                Image(systemName: AppSymbol.lockFill)
                    .font(.title3)
                    .foregroundColor(onColor ? .white.opacity(0.9) : theme.textMuted)
                    .accessibilityHidden(true)
            }
            // 템플릿 변수 {…}는 카드 제목에서도 원문이 아닌 칩(하이라이트)으로.
            Text(memo.title.templateAwareAttributed(theme: theme, font: .title2.weight(.semibold)))
                .font(.title2.weight(.semibold))
                .foregroundColor(onColor ? .white : theme.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 제목 아래 내용 힌트 - 카드가 화면에 2초쯤 머물면 한 번 살며시 맺혔다가
    /// 흩어지듯 사라진다(이번 등장에서는 끝). 설정(메모 표시)에서 켜기/끄기.
    ///
    /// 방금 쓴 카드는 이 자리에 **내용 대신 동전**을 보여준다. 겹쳐 얹으면 내용이
    /// 안 읽히고, 옆에 두면 카드 높이가 흔들린다. 같은 자리를 번갈아 쓰면 둘 다 해결된다.
    @ViewBuilder
    private func hintZone(onColor: Bool) -> some View {
        if !lightweight, showsCoin {
            VaultCardBadge(savedSeconds: VaultLedger.earnedSeconds(for: memo),
                           onColor: onColor)
                .frame(height: ContentHintPreview.zoneHeight, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .scale(scale: 0.7, anchor: .leading)))
        } else if !lightweight, let hint = Self.fishbowlText(for: memo) {
            ContentHintPreview(text: hint, seed: memo.id.hashValue, onColor: onColor)
        } else {
            Color.clear.frame(height: ContentHintPreview.zoneHeight)
        }
    }

    /// 키보드 키와 **같은 그림**을 쓴다 (DesignSystem/MemoTypeStyle.swift).
    private func typeIcon(onColor: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: MemoTypeStyle.symbolName(for: memo))
                .font(.title2)
                .foregroundStyle(onColor ? Color.white.opacity(0.9) : theme.textFaint)
        }
        .accessibilityHidden(true)
    }

    // MARK: - 색 고르기

    private var hasCustomCategory: Bool {
        CategoryStore.shared.isFeatureEnabled && categories.contains(memo.category)
    }

    /// 카드 배경이 짙은 색(컬러드)인지 - 글자·아이콘 색을 여기서 갈라 정한다.
    /// 색은 '카테고리'를 뜻한다. 타입(템플릿·콤보)은 색이 아니라 좌상단 아이콘으로 구분하고,
    /// 보안은 색이 아니라 자물쇠 심볼로만 구분한다(카드 색은 카테고리를 따른다).
    private func isColored(hasImage: Bool) -> Bool {
        if hasImage { return true }
        if memo.isFavorite { return true }
        return hasCustomCategory
    }

    /// 글자 뒤 할로 색. nil 이면 할로를 아예 깔지 않는다(`CardTextHalo` 참고).
    ///
    /// - 사진 카드: 자체 그라디언트가 가독성을 책임진다 → 없음
    /// - 색 카드(즐겨찾기·카테고리): 흰 글자라 어두운 할로
    /// - 무색 카드: **뒤에 사진이 깔렸을 때만.** 민 바탕에서는 테마 배경색과 같은 색이라
    ///   보이지도 않으면서 카드마다 화면 밖 합성만 한 번씩 더 만든다.
    private func textHaloColor(hasImage: Bool, onColor: Bool) -> Color? {
        if hasImage { return nil }
        if onColor { return Color.black.opacity(0.55) }
        return hasListBackground ? theme.bg : nil
    }

    @ViewBuilder
    private func cardBackground(imageFileName: String, hasImage: Bool) -> some View {
        if hasImage {
            // 그늘(가독성 그라디언트)은 `MemoImageBackground` 안으로 들어갔다.
            // 여기서 얹으면 사진이 오기 전에도 깔려서 카드가 검게 보인다.
            MemoImageBackground(fileName: imageFileName)
        } else if memo.isFavorite {
            // 즐겨찾기 = 분홍 (카테고리 색이므로 항상 표시)
            Color.clipFavorite
        } else if hasCustomCategory {
            // 색 = 카테고리 (항상 표시)
            categoryTint(for: memo.category, in: categories)
        } else {
            // 보안 메모도 카테고리 색(없으면 기본 표면색)을 따른다 - 회색으로 칠하지 않는다.
            theme.surface
        }
    }

    // MARK: - 글자 (화면들이 함께 쓴다)

    /// 카드 어항 미리보기 텍스트 - 제목 아래에서 물고기처럼 나타났다 사라질 내용 한 줄.
    /// 사용자가 메모에 힌트를 직접 적었으면 그것이 우선(보안 메모도 - 직접 쓴 한 줄이라 안전).
    /// ⚠️ 자동 요약은 보안 메모 내용 노출 금지(자물쇠 카드에서 값이 떠다니면 안 됨) → nil.
    static func fishbowlText(for memo: Memo) -> String? {
        if let custom = memo.hint?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        guard !memo.isSecure else { return nil }
        let text = MemoPreviewFormatter.preview(for: memo, resolvedType: memo.autoDetectedType)
        return text.isEmpty ? nil : text
    }

    /// 그리드 셀 VoiceOver 합성 라벨 - 제목 + 상태(즐겨찾기/이미지/보안/템플릿/콤보/카테고리).
    static func accessibilityLabel(for memo: Memo, categories: [String]) -> String {
        var parts: [String] = [memo.title]
        if memo.isFavorite { parts.append(NSLocalizedString("즐겨찾기", comment: "Category: favorites")) }
        if memo.contentType == .image || memo.contentType == .mixed {
            parts.append(NSLocalizedString("이미지 단축어", comment: "VoiceOver: image memo badge"))
        }
        if memo.isSecure { parts.append(NSLocalizedString("보안 단축어", comment: "VoiceOver: secure memo badge")) }
        if memo.isTemplate { parts.append(NSLocalizedString("템플릿", comment: "VoiceOver: template badge")) }
        if memo.isStack { parts.append(NSLocalizedString("콤보", comment: "VoiceOver: combo badge")) }
        if CategoryStore.shared.isFeatureEnabled, categories.contains(memo.category) {
            parts.append(NSLocalizedString(memo.category, comment: "Category name"))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 카드가 어떻게 보일지

/// 카드 얼굴을 정하는 설정 묶음.
///
/// 화면마다 이 값들을 따로 읽어 오면 한쪽만 고쳐진 채로 남아서, 같은 카드가 목록에서와
/// 순서 바꾸기에서 달라 보인다. 한 번 만들어 건네주면 그럴 일이 없다.
struct MemoCardStyle {
    var categories: [String]
    var cardHeight: CGFloat
    var showsVisualCues: Bool
    var showsContentHint: Bool
    var hasListBackground: Bool

    func surface(for memo: Memo,
                 showsCoin: Bool = false,
                 lightweight: Bool = false) -> MemoCardSurface {
        MemoCardSurface(
            memo: memo,
            categories: categories,
            cardHeight: cardHeight,
            showsVisualCues: showsVisualCues,
            showsContentHint: showsContentHint,
            hasListBackground: hasListBackground,
            showsCoin: showsCoin,
            lightweight: lightweight
        )
    }
}
