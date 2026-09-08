//
//  KeyboardLayoutSettings.swift
//  ClipKeyboard
//
//  키보드 레이아웃 및 언어 설정. 상단에 키보드 익스텐션 전체 미리보기를 포함.
//

import SwiftUI
import CryptoKit
#if canImport(UIKit)
import UIKit
import LeeoKit
#endif

// MARK: - KeyboardLayoutSettings

struct KeyboardLayoutSettings: View {

    // MARK: AppStorage - App Group 공유 (익스텐션과 동일 키)
    @AppStorage("keyboardColumnCount", store: AppGroup.defaults) private var columnCount: Int    = 2
    @AppStorage("keyboardButtonHeight", store: AppGroup.defaults) private var buttonHeight: Double = 44.0
    @AppStorage("keyboardButtonFontSize", store: AppGroup.defaults) private var buttonFontSize: Double = 17.0
    @AppStorage("keyboardUseCustomColors", store: AppGroup.defaults) private var useCustomColors: Bool   = false
    @AppStorage("keyboardCustomBgHex", store: AppGroup.defaults) private var customBgHex: String = ""
    @AppStorage("keyboardCustomKeyHex", store: AppGroup.defaults) private var customKeyHex: String = ""
    /// 키캡 물성 프리셋 - 익스텐션이 같은 키를 읽는다.
    @AppStorage(DefaultsKey.keyLabelTruncation, store: AppGroup.defaults)
    private var truncationRaw: String = KeyLabelTruncation.middle.rawValue
    @AppStorage(DefaultsKey.keyboardSkin, store: AppGroup.defaults)
    private var keyboardSkinRaw: String = KeyboardSkin.classic.rawValue
    @AppStorage("keyboardShowSearch", store: AppGroup.defaults) private var showSearch: Bool   = false
    @AppStorage("keyboardShowRecent", store: AppGroup.defaults) private var showRecent: Bool   = false
    /// 위줄의 리턴(보내기) 키. 기본 켬 - 없어서 못 보내던 것이 신고로 들어온 쪽이다.
    @AppStorage(DefaultsKey.keyboardShowReturnKey, store: AppGroup.defaults) private var showReturnKey: Bool = true
    @AppStorage("keyboardKoreanLayout", store: AppGroup.defaults) private var koreanLayout: String = "dubeolsik"
    @AppStorage("keyboardTypingLang", store: AppGroup.defaults) private var defaultLang: String = "english"
    // 한국어 입력 사용(기본 OFF). 영어 전용 사용자가 한/EN 토글을 보지 않도록 명시적으로 켜야 함.
    @AppStorage("keyboardKoreanEnabled", store: AppGroup.defaults) private var koreanEnabled: Bool   = false

    @State private var customBgColor: Color = .clear
    @State private var customKeyColor: Color = .clear
    @Environment(\.appTheme) private var theme

    private var selectedTruncation: KeyLabelTruncation {
        KeyLabelTruncation(rawValue: truncationRaw) ?? .middle
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 상단 고정 실시간 미리보기 - 아래 설정을 바꾸면 즉시 반영된다 ──
            KeyboardPreviewView()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusMd)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(theme.bg)

            List {
            // ── 1. 긴 이름 접기 ────────────────────────────────────────
            // 키 폭은 레이아웃이 정하고 이름은 그 안에서 잘린다. 자르지 않을 방법은 없으니
            // 남는 문제는 **어디를 자를 것인가**이고, 그걸 고르게 한다.
            Section {
                Picker(NSLocalizedString("긴 이름", comment: "Long key label section title"),
                       selection: $truncationRaw) {
                    ForEach(KeyLabelTruncation.allCases) { style in
                        Text(style.localizedName).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                // 고르기 전에 결과를 보여준다 - 이름만으로는 무엇이 달라지는지 알 수 없다.
                HStack {
                    Text(KeyLabelTruncation.sampleTitle)
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .keyLabelTruncation(selectedTruncation)
                        .frame(maxWidth: 120)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                                .fill(theme.surfaceAlt)
                        )
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text(NSLocalizedString("긴 이름", comment: "Long key label section title"))
            } footer: {
                Text(selectedTruncation.localizedDescription)
                    .font(.body)
            }

            // ── 2. 그리드 레이아웃 ─────────────────────────────────────
            Section {
                // 열 개수 - segmented
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("열 개수", comment: "Column count label"))
                        Spacer()
                        Text(String(format: NSLocalizedString("%d열", comment: "Column count value"), columnCount))
                            .foregroundColor(.secondary)
                    }
                    Picker("", selection: $columnCount) {
                        ForEach(1...5, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 버튼 높이
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("버튼 높이", comment: "Button height label"))
                        Spacer()
                        Text("\(Int(buttonHeight))pt").foregroundColor(.secondary)
                    }
                    Slider(value: $buttonHeight, in: 32...120, step: 1).tint(theme.accent)
                    HStack {
                        Text(NSLocalizedString("작게", comment: "Small")).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(NSLocalizedString("크게", comment: "Large")).font(.caption).foregroundColor(.secondary)
                    }
                }

                // 글자 크기
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(NSLocalizedString("글자 크기", comment: "Font size label"))
                        Spacer()
                        Text("\(Int(buttonFontSize))pt").foregroundColor(.secondary)
                    }
                    Slider(value: $buttonFontSize, in: 10...36, step: 1).tint(theme.accent)
                    HStack {
                        Text(NSLocalizedString("작게", comment: "Small")).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(NSLocalizedString("크게", comment: "Large")).font(.caption).foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("그리드 레이아웃", comment: "Section: grid layout"))
            }

            // ── 3. 언어 설정 ───────────────────────────────────────────
            Section {
                // 한국어 입력 사용 - 기본 OFF. 켜야 키보드에 한/EN 토글과 한글 자판이 나타난다.
                Toggle(isOn: $koreanEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("한국어 입력", comment: "Enable Korean input toggle"))
                        Text(NSLocalizedString("켜면 키보드에서 한국어도 입력할 수 있어요", comment: "Enable Korean input subtitle"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                if koreanEnabled {
                // 기본 언어 - Apple-style Picker (NavigationLink)
                Picker(NSLocalizedString("기본 언어", comment: "Default language picker label"), selection: $defaultLang) {
                    Label("English", systemImage: AppSymbol.globe).tag("english")
                    Label(NSLocalizedString("한국어", comment: "Korean language option"), systemImage: AppSymbol.globeAsiaAustraliaFill).tag("korean")
                }

                // 한국어 레이아웃 - Apple-style Picker (NavigationLink)
                Picker(NSLocalizedString("한국어 레이아웃", comment: "Korean layout picker label"), selection: $koreanLayout) {
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("두벌식", comment: "Korean layout: dubeolsik"))
                        Text(NSLocalizedString("QWERTY 스타일 (표준)", comment: "Dubeolsik subtitle"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .tag("dubeolsik")

                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("천지인", comment: "Korean layout: cheonjiin"))
                        Text(NSLocalizedString("3×3 키패드 스타일", comment: "Cheonjiin subtitle"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .tag("cheonjiin")
                }

                // 레이아웃 시각 가이드
                koreanLayoutGuide
                }   // if koreanEnabled
            } header: {
                Text(NSLocalizedString("언어", comment: "Section: language"))
            } footer: {
                Text(koreanEnabled
                     ? NSLocalizedString("키보드의 한/EN 버튼으로 언어를 전환할 수 있습니다. 기본 언어는 키보드를 처음 열었을 때 적용됩니다.", comment: "Language section footer")
                     : NSLocalizedString("이 설정을 켜면 키보드에 한/EN 전환 버튼이 추가됩니다.", comment: "Language section footer when Korean off"))
            }

            // ── 4. 표시 옵션 ───────────────────────────────────────────
            Section {
                Toggle(isOn: $showSearch) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("검색창", comment: "Show search bar toggle"))
                        Text(NSLocalizedString("단축어를 이름으로 빠르게 찾습니다", comment: "Search bar description"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $showRecent) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("최근 단축어", comment: "Show recent snippets toggle"))
                        Text(NSLocalizedString("최근 사용한 단축어 5개를 상단에 표시합니다", comment: "Recent snippets description"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $showReturnKey) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("보내기 키", comment: "Show return key toggle"))
                        Text(NSLocalizedString("단축어를 넣은 뒤 키보드를 바꾸지 않고 바로 보냅니다", comment: "Return key description"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("표시 옵션", comment: "Section: display options"))
            } footer: {
                if showReturnKey {
                    // 되는 앱과 안 되는 앱이 갈리는 자리라, 켠 사람에게는 미리 말해 둔다.
                    // 안 그러면 "왜 어떤 앱에서는 줄만 바뀌지" 가 다시 문의로 돌아온다.
                    Text(NSLocalizedString("보내기 키의 이름은 앱이 정합니다. 메시지 앱에서는 보내기, 검색창에서는 검색으로 보여요. 줄바꿈만 되는 앱도 있습니다.", comment: "Return key footer"))
                }
            }

            // ── 4.5 키캡 스킨 ──────────────────────────────────────────
            // 지금은 감춰 둔다(KeyboardSkin.isEnabled = false) - 모두 예전 모습으로 보인다.
            // 되살리려면 그 값을 true 로 바꾸고 이 줄의 주석을 풀면 된다.
            if KeyboardSkin.isEnabled { skinSection }


            // ── 5. 색상 ────────────────────────────────────────────────
            Section {
                Toggle(isOn: $useCustomColors) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(NSLocalizedString("커스텀 색상 사용", comment: "Use custom colors toggle"))
                        Text(NSLocalizedString("기본 Paper 테마 대신 직접 색상을 지정합니다", comment: "Custom colors description"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                if useCustomColors {
                    ColorPicker(NSLocalizedString("배경색", comment: "Background color picker"),
                                selection: $customBgColor, supportsOpacity: false)
                        .onChange(of: customBgColor) { _, c in customBgHex = c.toHex() ?? "" }

                    ColorPicker(NSLocalizedString("키 색상", comment: "Key color picker"),
                                selection: $customKeyColor, supportsOpacity: false)
                        .onChange(of: customKeyColor) { _, c in customKeyHex = c.toHex() ?? "" }

                    Button {
                        customBgHex  = ""; customKeyHex  = ""
                        customBgColor = .clear; customKeyColor = .clear
                    } label: {
                        Label(NSLocalizedString("색상 초기화", comment: "Reset colors"), systemImage: AppSymbol.arrowUturnBackward)
                            .foregroundColor(theme.accent).font(.footnote)
                    }
                }
            } header: {
                Text(NSLocalizedString("색상", comment: "Section: colors"))
            }

            // ── 6. 전체 초기화 ─────────────────────────────────────────
            Section {
                Button(role: .destructive) { resetToDefaults() } label: {
                    Label(NSLocalizedString("기본값으로 되돌리기", comment: "Reset to defaults"), systemImage: AppSymbol.arrowCounterclockwise)
                }
            }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle(NSLocalizedString("키보드 레이아웃", comment: "Keyboard layout"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .onAppear {
            if !customBgHex.isEmpty, let c = Color(hex: customBgHex) { customBgColor  = c }
            if !customKeyHex.isEmpty, let c = Color(hex: customKeyHex) { customKeyColor = c }
        }
    }

    // MARK: - 키캡 스킨

    /// 스킨은 **색이 아니라 물성**을 고른다 - 두께·빛·모서리·눌림.
    /// 그래서 아래 색상 섹션(커스텀 키 색)과 겹치지 않고, 어떤 색을 골라도 그대로 유지된다.
    private var skinSection: some View {
        Section {
            ForEach(KeyboardSkin.allCases) { candidate in
                ChoiceRow(name: candidate.localizedName,
                          detail: candidate.localizedDescription,
                          isSelected: keyboardSkinRaw == candidate.rawValue) {
                    // 실제 키캡과 같은 규칙으로 그린 미리보기 - 설명 대신 물건을 보여준다.
                    KeycapPreview(skin: candidate, isDark: theme.isDark)
                } action: {
                    keyboardSkinRaw = candidate.rawValue
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(keyboardSkinRaw == candidate.rawValue ? [.isSelected] : [])
            }
        } header: {
            Text(NSLocalizedString("키캡 스킨", comment: "Section: keycap skin"))
        } footer: {
            Text(NSLocalizedString("키의 두께와 눌리는 느낌만 바뀌어요. 색은 아래에서 따로 고를 수 있어요.",
                                   comment: "Keycap skin section footer"))
        }
    }

    // MARK: - Korean Layout Visual Guide

    private var koreanLayoutGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("레이아웃 미리보기", comment: "Layout preview label"))
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                // 두벌식
                layoutCard(
                    title: NSLocalizedString("두벌식", comment: "Dubeolsik Korean keyboard layout name"),
                    layoutId: "dubeolsik",
                    rows: [["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ"], ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ"], ["ㅗ", "ㅓ", "ㅏ", "ㅣ", "ㅡ"]],
                    isSelected: koreanLayout == "dubeolsik"
                )
                // 천지인
                layoutCard(
                    title: NSLocalizedString("천지인", comment: "Cheonjiin Korean keyboard layout name"),
                    layoutId: "cheonjiin",
                    rows: [["ㅣ", "ㆍ", "ㅡ"], ["ㄱㅋ", "ㄴㄹ", "ㄷㅌ"], ["ㅂㅍ", "ㅅㅎ", "ㅈㅊ"]],
                    isSelected: koreanLayout == "cheonjiin"
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func layoutCard(title: String, layoutId: String, rows: [[String]], isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { ri in
                HStack(spacing: 3) {
                    ForEach(rows[ri].indices, id: \.self) { ci in
                        Text(rows[ri][ci])
                            .font(.system(size: 9, weight: .medium))
                            .frame(minWidth: 18, minHeight: 16)
                            .background(isSelected ? theme.accent.opacity(0.15) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                    }
                }
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(isSelected ? theme.accent : .secondary)
                .padding(.top, 2)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusSm)
                .fill(isSelected ? theme.accent.opacity(0.08) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusSm)
                .strokeBorder(isSelected ? theme.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture { if !isSelected { koreanLayout = layoutId } }
    }

    // MARK: - Reset

    private func resetToDefaults() {
        columnCount = 2; buttonHeight = 56; buttonFontSize = 17
        useCustomColors = false; customBgHex = ""; customKeyHex = ""
        customBgColor = .clear; customKeyColor = .clear
        showSearch = false; showRecent = false; showReturnKey = true
        koreanLayout = "dubeolsik"; defaultLang = "english"
        keyboardSkinRaw = KeyboardSkin.classic.rawValue
    }
}

// MARK: - KeyboardPreviewView

/// 키보드 익스텐션 전체를 설정 화면에서 실시간으로 미리 보여주는 뷰.
/// AppStorage를 직접 읽어 슬라이더/토글 변경이 즉시 반영된다.
struct KeyboardPreviewView: View {

    private let ud = AppGroup.defaults

    @AppStorage("keyboardColumnCount", store: AppGroup.defaults) private var columnCount: Int    = 2
    @AppStorage("keyboardButtonHeight", store: AppGroup.defaults) private var buttonHeight: Double = 44.0
    @AppStorage("keyboardButtonFontSize", store: AppGroup.defaults) private var buttonFontSize: Double = 17.0
    @AppStorage("keyboardUseCustomColors", store: AppGroup.defaults) private var useCustomColors: Bool   = false
    @AppStorage("keyboardCustomBgHex", store: AppGroup.defaults) private var customBgHex: String = ""
    @AppStorage("keyboardCustomKeyHex", store: AppGroup.defaults) private var customKeyHex: String = ""
    @AppStorage(DefaultsKey.keyboardSkin, store: AppGroup.defaults)
    private var keyboardSkinRaw: String = KeyboardSkin.classic.rawValue

    @State private var previewMemos: [Memo] = []
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("showVisualCues", store: AppGroup.defaults)
    private var showVisualCues: Bool = false
    /// 실제 키보드(KeyboardView)와 동일 - 오직 "메모 구분 표시" 토글만 따른다.
    private var visualCuesVisible: Bool { showVisualCues }

    @Environment(\.colorSchemeContrast) private var contrast
    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark,
                         increasedContrast: contrast == .increased)
    }

    private var bgColor: Color {
        if useCustomColors, !customBgHex.isEmpty, let c = Color(hex: customBgHex) { return c }
        return theme.bg
    }
    private var keyColor: Color {
        if useCustomColors, !customKeyHex.isEmpty, let c = Color(hex: customKeyHex) { return c }
        return theme.surface
    }

    // 카테고리 탭 (익스텐션과 동일 로직)
    private var categoryFeatureEnabled: Bool { ud?.bool(forKey: DefaultsKey.categoryFeatureEnabledV1) ?? false }
    private var allUserCats: [String] { ud?.stringArray(forKey: DefaultsKey.userDefinedCategoriesV1) ?? [] }
    private var hiddenCats: Set<String> { Set(ud?.stringArray(forKey: DefaultsKey.hiddenCategoryTabsV1) ?? []) }
    private var categoryPages: [String] {
        guard categoryFeatureEnabled else { return [] }
        var pages = ["★all"]
        if !hiddenCats.contains("__favorites__"), previewMemos.contains(where: { $0.isFavorite }) {
            pages.append("★favorites")
        }
        pages.append(contentsOf: allUserCats.filter { cat in
            !hiddenCats.contains(cat) && previewMemos.contains { $0.category == cat }
        })
        return pages
    }

    private func catIcon(_ key: String) -> String {
        if key == "★all" { return "square.grid.2x2.fill" }
        if key == "★favorites" { return "heart.fill" }
        return categorySymbol(for: key, in: allUserCats)
    }
    private func catColor(_ key: String) -> Color {
        if key == "★all" { return .blue }
        if key == "★favorites" { return .clipFavorite }
        return categoryTint(for: key, in: allUserCats)
    }

    /// 메모가 속한 사용자 카테고리 색(익스텐션 categoryColorFor와 동일). 미해당이면 nil.
    private func memoCatColor(_ memo: Memo) -> Color? {
        guard allUserCats.contains(memo.category) else { return nil }
        return catColor(memo.category)
    }

    /// 실제 키보드·앱 카드와 **같은 규칙**을 본다 (DesignSystem/MemoTypeStyle.swift).
    /// 미리보기가 실물과 다르면 설정을 고르고 나서 "이게 아닌데"가 된다.
    private func typeBorder(_ memo: Memo) -> TypeVisualStyle {
        MemoTypeStyle.border(for: memo, visualCuesVisible: visualCuesVisible)
    }

    /// 사용자가 고른 키캡 물성 - 실제 키보드와 같은 값을 읽는다.
    private var skin: KeyboardSkin {
        KeyboardSkin.resolved(keyboardSkinRaw)
    }

    private var keycapRadius: CGFloat { skin.cornerRadius(base: theme.radiusMd) }

    private var gridColumns: [GridItem] {
        // 익스텐션 LazyVGrid spacing 10과 동일
        Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, min(5, columnCount)))
    }

    /// 익스텐션 memoButtonLabel과 동일한 셀 - radiusMd, 카테고리 틴트, 타입 테두리,
    /// 중앙 2줄 제목. 프리뷰가 실제 키보드와 같은 모습이 되도록 한다.
    @ViewBuilder
    private func previewCell(_ memo: Memo) -> some View {
        let cat = memoCatColor(memo)
        let border = typeBorder(memo)
        ZStack {
            // 스커트(키캡 옆면) - 실제 키와 같은 두께를 미리 보여준다.
            RoundedRectangle(cornerRadius: keycapRadius)
                .fill(Color.black.opacity(skin.skirtOpacity(isDark: theme.isDark)))
                .offset(y: skin.skirtDepth)

            RoundedRectangle(cornerRadius: keycapRadius)
                .foregroundColor(keyColor)
                .overlay(
                    Group {
                        if let cat {
                            RoundedRectangle(cornerRadius: keycapRadius)
                                .fill(cat.opacity(theme.isDark ? 0.22 : 0.14))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: keycapRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(skin.sheenOpacity(isDark: theme.isDark)), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                )
                .shadow(color: .black.opacity(skin.shadowOpacity), radius: 2, y: 1)

            Text(memo.title.templateAwareAttributed(
                theme: theme, font: .system(size: buttonFontSize, weight: .semibold)))
                .foregroundColor(theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .font(.system(size: buttonFontSize, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(10)
        }
        .frame(height: buttonHeight)
        .overlay(
            RoundedRectangle(cornerRadius: keycapRadius)
                .strokeBorder(border.color,
                              style: StrokeStyle(lineWidth: border.lineWidth, dash: border.dash))
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 상단 헤더: 카테고리 탭 ──
            if !categoryPages.isEmpty {
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(categoryPages.enumerated()), id: \.offset) { idx, key in
                                let sel = idx == 0
                                // 익스텐션 categoryTabRow와 동일: 13pt, 32×28, 비선택 배경 surface
                                Image(systemName: catIcon(key))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(sel ? .white : theme.textMuted)
                                    .frame(width: 32, height: 28)
                                    .background(sel ? catColor(key) : theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusXs))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                    }
                }
            }

            // ── 메모 그리드 ──
            ZStack {
                bgColor

                if previewMemos.isEmpty {
                    // 메모 없을 때 플레이스홀더 (셀과 동일한 radiusMd)
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(0..<(columnCount * 2), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: theme.radiusMd)
                                .fill(keyColor.opacity(0.6))
                                .frame(height: min(buttonHeight, 50))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusMd)
                                        .strokeBorder(theme.divider, lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                } else {
                    let displayMemos = Array(previewMemos.prefix(columnCount * 3))
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(displayMemos) { memo in
                                previewCell(memo)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .disabled(true)
                }
            }
        }
        .background(bgColor)
        .onAppear {
            previewMemos = (try? MemoStore.shared.load(type: .memo)) ?? []
        }
    }
}

// MARK: - SecurePINSetupView

struct SecurePINSetupView: View {
    var onSave: (String) -> Void

    enum Step { case enter, confirm }

    @State private var step: Step = .enter
    @State private var firstPIN = ""
    @State private var currentPIN = ""
    @State private var mismatch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: AppSymbol.lockShieldFill)
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                    Text(step == .enter
                         ? NSLocalizedString("4자리 PIN 입력", comment: "PIN setup: enter step title")
                         : NSLocalizedString("PIN 확인", comment: "PIN setup: confirm step title"))
                        .font(.title3).fontWeight(.semibold)
                    if mismatch {
                        Text(NSLocalizedString("PIN이 일치하지 않습니다. 다시 시도하세요.", comment: "PIN mismatch error"))
                            .font(.caption).foregroundColor(.red)
                    } else {
                        Text(step == .enter
                             ? NSLocalizedString("보안 단축어 잠금에 사용할 PIN을 입력하세요.", comment: "PIN setup: enter hint")
                             : NSLocalizedString("동일한 PIN을 한 번 더 입력하세요.", comment: "PIN setup: confirm hint"))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.top, 32)

                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < currentPIN.count ? Color.orange : Color(UIColor.systemGray4))
                            .frame(width: 16, height: 16)
                    }
                }

                VStack(spacing: 12) {
                    ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.first) { row in
                        HStack(spacing: 20) {
                            ForEach(row, id: \.self) { n in pinDigitButton(String(n)) }
                        }
                    }
                    HStack(spacing: 20) {
                        Color.clear.frame(width: 80, height: 60)
                        pinDigitButton("0")
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if !currentPIN.isEmpty { currentPIN.removeLast() }
                        } label: {
                            Image(systemName: AppSymbol.deleteLeftFill)
                                .font(.system(size: 22)).foregroundColor(.primary)
                                .frame(width: 80, height: 60)
                        }
                        .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace button"))
                    }
                }
                Spacer()
            }
            .navigationTitle(NSLocalizedString("보안 PIN 설정", comment: "Secure PIN setup nav title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func pinDigitButton(_ digit: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard currentPIN.count < 4 else { return }
            currentPIN.append(digit)
            if currentPIN.count == 4 { advance() }
        } label: {
            Text(digit).font(.system(size: 24, weight: .medium)).foregroundColor(.primary)
                .frame(width: 80, height: 60)
                .background(Circle().fill(Color(UIColor.systemGray6)))
        }
    }

    private func advance() {
        if step == .enter {
            firstPIN = currentPIN; currentPIN = ""; mismatch = false; step = .confirm
        } else {
            if firstPIN == currentPIN {
                let hash = SHA256.hash(data: Data(firstPIN.utf8))
                    .compactMap { String(format: "%02x", $0) }.joined()
                onSave(hash)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                mismatch = true; step = .enter; firstPIN = ""; currentPIN = ""
            }
        }
    }
}

#Preview {
    NavigationStack { KeyboardLayoutSettings() }
}

// MARK: - 키캡 미리보기

/// 스킨 선택 행에 붙는 작은 키캡.
///
/// ⚠️ 실제 키(`KeycapButtonStyle`)와 **같은 규칙**으로 그린다 - 스커트를 아래로 빼고,
///    윗면에 빛을 얹고, 스킨이 정한 모서리를 쓴다. 미리보기가 실물과 다르면
///    고르고 나서 "이게 아닌데"가 된다.
///
/// 눌러 보면 실제와 같은 곡선으로 내려앉는다 - 설명 대신 만져 보게 한다.
private struct KeycapPreview: View {
    let skin: KeyboardSkin
    let isDark: Bool

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    private var size: CGSize { CGSize(width: 46, height: 34) }
    private var radius: CGFloat { skin.cornerRadius(base: theme.radiusMd) }

    var body: some View {
        ZStack {
            // 스커트(옆면)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.black.opacity(skin.skirtOpacity(isDark: isDark)))
                .frame(width: size.width, height: size.height)
                .offset(y: pressed ? 0 : skin.skirtDepth)

            // 윗면 + 표면광
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(skin.sheenOpacity(isDark: isDark)), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 0.5)
                )
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(skin.shadowOpacity), radius: 2, y: 1)
                .offset(y: pressed ? skin.skirtDepth : 0)
        }
        // 스커트가 아래로 삐져나온 만큼 자리를 확보해 행 높이가 흔들리지 않게 한다.
        .frame(width: size.width, height: size.height + skin.skirtDepth, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { tap() }
        .accessibilityHidden(true)
    }

    private func tap() {
        guard skin.skirtDepth > 0, !reduceMotion else { return }
        withAnimation(.easeOut(duration: skin.pressDuration)) { pressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + skin.pressDuration + 0.04) {
            withAnimation(.spring(response: skin.releaseResponse,
                                  dampingFraction: skin.releaseDamping)) { pressed = false }
        }
    }
}
