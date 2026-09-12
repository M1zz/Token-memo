//
//  BulkImportKeyPreview.swift
//  ClipKeyboard
//
//  일괄 추가에서 **저장하기 전 결과를 키보드 모습 그대로** 보여주고, 그 안에서 고르게 한다.
//
//  왜 이렇게 하는가: 일괄 추가의 결과물이 실제로 쓰이는 곳은 목록이 아니라 **키보드**다.
//  그런데 미리보기가 설정 화면 같은 목록이라, 30개를 한꺼번에 넣고 저장한 뒤에야
//  "내 키보드가 이렇게 되는구나"를 알았다. 들어갈 자리에서 미리 보여주면
//  그 자리에서 뺄 것을 뺄 수 있다.
//
//  ⚠️ **키보드를 흉내 내지 않는다.** 키캡의 물성·모서리·눌림은 익스텐션과 같은
//     `KeycapButtonStyle`/`KeyboardSkin`을, 이름 접기는 같은 `KeyLabelTruncation`을,
//     열 수·키 높이·글자 크기·색은 **같은 App Group 설정 키**를 읽는다.
//     여기서 새로 정하는 값은 하나도 없다 - 설정을 바꾸면 이 미리보기도 같이 변한다.
//
//  ⚠️ 진짜 `KeyboardView`를 그대로 띄우지 않는 이유: 그건 **저장된** `clipMemos` 전역을
//     읽고 입력·템플릿·PIN·카테고리 탭까지 얹힌 물건이다. 아직 저장되지 않은 초안을
//     고르는 화면과는 하는 일이 다르다. 공유해야 할 것은 동작이 아니라 **생김새**라
//     생김새를 만드는 부품만 가져다 쓴다.
//

import SwiftUI

struct BulkImportKeyPreview: View {

    /// 고를 대상 - 누르면 `include`가 뒤집힌다(묶기 모드에서는 선택이 뒤집힌다).
    @Binding var drafts: [BulkImportView.Draft]

    /// **묶기 모드**인가 - 키에 체크가 나오고, 누르면 넣고빼기 대신 묶을 것을 고른다.
    ///
    /// ⚠️ 체크를 상시로 얹지 않는 이유: 이 화면의 약속은 "저장하면 키보드가 이 모습"이다.
    ///    키마다 동그라미가 박혀 있으면 그 약속이 깨진다. 묶는 일은 가끔 하는 일이니
    ///    그때만 모습을 바꾸고, 끝나면 다시 정직한 미리보기로 돌아온다.
    var isBundling: Bool = false

    /// 묶으려고 고른 항목들.
    @Binding var bundleSelection: Set<UUID>

    // MARK: - 키보드와 같은 설정 (App Group)

    @AppStorage("keyboardColumnCount", store: AppGroup.defaults)
    private var keyboardColumnCount: Int = 2
    @AppStorage("keyboardButtonHeight", store: AppGroup.defaults)
    private var buttonHeight: Double = 44.0
    @AppStorage("keyboardButtonFontSize", store: AppGroup.defaults)
    private var buttonFontSize: Double = 17.0
    @AppStorage("keyboardUseCustomColors", store: AppGroup.defaults)
    private var useCustomColors: Bool = false
    @AppStorage("keyboardCustomBgHex", store: AppGroup.defaults)
    private var customBgHex: String = ""
    @AppStorage("keyboardCustomKeyHex", store: AppGroup.defaults)
    private var customKeyHex: String = ""
    @AppStorage(DefaultsKey.keyboardSkin, store: AppGroup.defaults)
    private var keyboardSkinRaw: String = KeyboardSkin.classic.rawValue
    @AppStorage("showVisualCues", store: AppGroup.defaults)
    private var showVisualCues: Bool = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: gridItemLayout, spacing: 10) {
                ForEach($drafts) { $draft in
                    keycap(for: $draft)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
    }

    // MARK: - 키 한 장

    private func keycap(for draft: Binding<BulkImportView.Draft>) -> some View {
        let d = draft.wrappedValue
        let memo = previewMemo(for: d)

        let checked = bundleSelection.contains(d.id)

        return Button {
            if isBundling {
                if checked { bundleSelection.remove(d.id) } else { bundleSelection.insert(d.id) }
            } else {
                draft.wrappedValue.include.toggle()
            }
            KeyboardHaptics.softTap()
        } label: {
            ZStack {
                if d.include {
                    // 들어갈 것 - 키보드에 실제로 생길 키의 모습 그대로.
                    RoundedRectangle(cornerRadius: keycapRadius)
                        .foregroundColor(keyColor)
                        .overlay(keycapSheen)
                        .shadow(color: Color.black.opacity(skin.shadowOpacity), radius: 2, y: 1)
                } else {
                    // 빠질 것 - 키가 아니라 **빈자리**로 그린다. 흐리게만 처리하면
                    // "연한 키"로 보여서 들어가는지 마는지가 애매해진다.
                    RoundedRectangle(cornerRadius: keycapRadius)
                        .strokeBorder(theme.divider,
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }

                HStack(spacing: 4) {
                    // 묶기 중에는 체크가 타입 심볼 자리를 대신한다 - 둘 다 넣으면 이름 쓸 폭이 없다.
                    if isBundling {
                        Image(systemName: checked ? AppSymbol.checkmarkCircleFill : AppSymbol.circle)
                            .font(.system(size: buttonFontSize * 0.9, weight: .semibold))
                            .foregroundColor(checked ? Color.checkGreen : theme.textMuted)
                            .accessibilityHidden(true)
                    } else if showVisualCues, MemoTypeStyle.hasDistinctType(memo) {
                        Image(systemName: MemoTypeStyle.symbolName(for: memo))
                            .font(.system(size: buttonFontSize * 0.82, weight: .semibold))
                            .foregroundColor(theme.textMuted)
                            .accessibilityHidden(true)
                    }
                    Text(displayTitle(for: d))
                        .font(.system(size: buttonFontSize))
                        .foregroundColor(d.include ? theme.text : theme.textMuted)
                        .keyLabelTruncation(KeyLabelTruncation.current)

                    // 콤보는 **몇 단계인지**를 늘 보여준다.
                    // ⚠️ 구분 표시(showVisualCues) 설정에 맡기지 않는다. 그건 기본이 꺼져 있어서,
                    //    정작 "어떤 게 단축어이고 어떤 게 콤보인지" 판단해야 하는 이 자리에서
                    //    아무 표시도 안 나온다. 여기서는 그 판단이 화면의 존재 이유다.
                    if d.isStack {
                        Text("\(d.values.count)")
                            .font(.system(size: buttonFontSize * 0.72, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                            .accessibilityHidden(true)
                    }
                }
                .padding(10)
                .opacity(d.include ? 1.0 : 0.55)
            }
            .frame(height: buttonHeight)
            // 타입 구분 테두리(콤보·보안) - 앱 카드·키보드와 같은 규칙.
            // 빠질 키는 이미 점선 빈자리라 덧그리지 않는다.
            .overlay(
                RoundedRectangle(cornerRadius: keycapRadius)
                    .strokeBorder(d.include ? typeBorder(for: memo).color : .clear,
                                  style: StrokeStyle(lineWidth: typeBorder(for: memo).lineWidth,
                                                     dash: typeBorder(for: memo).dash))
            )
        }
        // 빠진 키는 눌러도 내려앉지 않는다 - 바닥에 얹힌 키캡이 아니라 빈자리니까.
        .buttonStyle(KeycapButtonStyle(skin: d.include ? skin : .flat,
                                       cornerRadius: keycapRadius,
                                       skirtColor: keycapSkirtColor))
        .accessibilityLabel(accessibilityLabel(for: d))
        .accessibilityValue(isBundling
                            ? (checked
                               ? NSLocalizedString("선택됨", comment: "Bulk import key preview: picked for bundling")
                               : NSLocalizedString("선택 안 됨", comment: "Bulk import key preview: not picked for bundling"))
                            : (d.include
                               ? NSLocalizedString("추가됨", comment: "Bulk import key preview: included")
                               : NSLocalizedString("빠짐", comment: "Bulk import key preview: excluded")))
        .accessibilityHint(isBundling
                           ? NSLocalizedString("두 번 누르면 함께 묶을 것으로 고르거나 뺍니다",
                                               comment: "Bulk import key preview: bundling toggle hint")
                           : NSLocalizedString("두 번 누르면 이 단축어를 넣거나 뺍니다",
                                               comment: "Bulk import key preview: toggle hint"))
        .accessibilityAddTraits((isBundling ? checked : d.include) ? [.isSelected] : [])
    }

    /// 화면을 못 보는 사람에게도 **단축어인지 콤보인지**가 들려야 한다
    /// 눈으로는 주황 숫자 배지가 그 일을 한다.
    private func accessibilityLabel(for draft: BulkImportView.Draft) -> String {
        let name = draft.title.isEmpty ? draft.value : draft.title
        guard draft.isStack else { return name }
        return String(format: NSLocalizedString("%@, 콤보 %d단계", comment: "Bulk import key preview: combo a11y label"),
                      name, draft.values.count)
    }

    /// 키에 적힐 이름. 제목을 아직 안 지은 항목은 값 앞부분을 빌려 쓴다
    /// 빈 키가 나열되면 무엇을 빼야 할지 판단할 수가 없다.
    private func displayTitle(for draft: BulkImportView.Draft) -> String {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        if draft.isSecure { return NSLocalizedString("보안 단축어", comment: "Bulk import key preview: untitled secure item") }
        return String(draft.value.prefix(20))
    }

    /// 초안을 **저장 후 모습**의 임시 `Memo`로 바꾼다. 타입 표시(콤보·보안·템플릿)를
    /// 앱·키보드와 똑같은 규칙으로 판정하려면 같은 타입에 물어보는 편이 안전하다.
    /// ⚠️ 저장하지 않는다. 값도 암호화하지 않는다 - 화면에 그릴 용도로만 만든다.
    private func previewMemo(for draft: BulkImportView.Draft) -> Memo {
        draft.isStack
            ? Memo(title: draft.title, value: "", isSecure: draft.isSecure, stackValues: draft.values)
            : Memo(title: draft.title, value: draft.value, isSecure: draft.isSecure)
    }

    /// 타입 테두리는 "색상 없이 구별"(구분 표시)이 켜졌을 때만 그린다 - 키보드와 같은 기준.
    private func typeBorder(for memo: Memo) -> TypeVisualStyle {
        MemoTypeStyle.border(for: memo, visualCuesVisible: showVisualCues)
    }

    // MARK: - 키보드와 같은 값들

    private var gridItemLayout: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10),
              count: max(1, min(5, keyboardColumnCount)))
    }

    private var skin: KeyboardSkin { KeyboardSkin.resolved(keyboardSkinRaw) }

    private var keycapRadius: CGFloat { skin.cornerRadius(base: theme.radiusMd) }

    private var keycapSkirtColor: Color {
        Color.black.opacity(skin.skirtOpacity(isDark: theme.isDark))
    }

    private var keycapSheen: some View {
        RoundedRectangle(cornerRadius: keycapRadius)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(skin.sheenOpacity(isDark: theme.isDark)), .clear],
                    startPoint: .top, endPoint: .center
                )
            )
            .allowsHitTesting(false)
    }

    private var backgroundColor: Color {
        if useCustomColors, !customBgHex.isEmpty, let custom = Color(hex: customBgHex) {
            return custom
        }
        return theme.bg
    }

    private var keyColor: Color {
        if useCustomColors, !customKeyHex.isEmpty, let custom = Color(hex: customKeyHex) {
            return custom
        }
        return theme.surface
    }
}
