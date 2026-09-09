//
//  KeyboardOverlays.swift
//  ClipKeyboardExtension
//
//  KeyboardView에서 분리한 보조 뷰/모델:
//  ImageMemoButton, TemplateInputOverlay, PlaceholderInputView,
//  TypeVisualStyle, DisplayItem.
//

import SwiftUI
import UIKit

struct ImageMemoButton: View {
    let title: String
    let fileName: String
    let buttonHeight: Double
    let buttonFontSize: Double

    @Environment(\.colorScheme) private var colorScheme
    /// 대비 증가를 켠 사람에게는 흐린 글자와 선을 끌어올린다.
    /// ⚠️ 익스텐션은 앱의 `AppThemedContainer` 를 거치지 않으므로 **여기서 직접 본다.**
    @Environment(\.colorSchemeContrast) private var contrast
    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark,
                         increasedContrast: contrast == .increased)
    }

    @State private var image: UIImage?

    /// 키캡 모양 - 사진·그늘·글자·누를 자리가 **모두 같은 모양**을 봐야 어긋나지 않는다.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: theme.radiusSm)
    }

    var body: some View {
        // ⚠️ 사진은 `overlay` 로 얹는다. `ZStack` 에 그냥 넣으면 사진이 **자리 크기를 정해 버린다.**
        //    `scaledToFill` 은 제안된 칸을 덮을 때까지 키우는데, 폭이 묶여 있지 않으면
        //    가로로 긴 사진(파노라마·영수증·잘라낸 화면)에서 키 하나가 칸을 넘어 66pt 자리에
        //    225pt 로 눕는다. 넘친 만큼이 옆 키를 덮으면 **그 키는 눌러도 반응하지 않는다.**
        //    (`overlay` 의 자식은 부모 크기를 제안받고 자기 크기는 부모에 영향을 주지 않는다)
        shape
            .foregroundColor(Color(uiColor: .systemGray5))
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(shape)
            .overlay(alignment: .bottomLeading) {
                ZStack(alignment: .bottomLeading) {
                    // 텍스트 가독성을 위한 하단 그라디언트
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Text(title)
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .padding(10)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            // 누를 자리는 칸 전체. 모서리를 깎아 두면 둥근 귀퉁이가 죽은 자리가 된다.
            .contentShape(Rectangle())
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .onAppear(perform: load)
    }

    /// 키에 그릴 만큼만 줄여서 읽고, 읽은 것은 담아 둔다.
    ///
    /// ⚠️ 예전에는 `MemoStore.loadImage()` 로 **원본을 통째로** 그것도 `onAppear` 마다 읽었다.
    ///    사진 한 장이 펼쳐서 24MB 인데 키에 그려지는 것은 60pt 짜리다. 이미지 단축어가
    ///    몇 개만 보여도 익스텐션의 메모리 한도를 넘고, 넘으면 iOS 가 조용히 죽인다.
    ///    앱 목록(`CardSurfaceEffects`)은 처음부터 줄여서 담고 있었다 - 키보드만 안 하고 있었다.
    ///    (5.0.4 릴리즈 노트의 "남겨 둔 것" 에 적혀 있던 바로 그것이다.)
    private func load() {
        guard image == nil, !fileName.isEmpty else { return }
        if let cached = Self.cache.object(forKey: fileName as NSString) {
            image = cached
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let loaded = MemoStore.shared.loadThumbnail(fileName: fileName,
                                                              maxPixel: Self.thumbnailMaxPixel) else { return }
            Self.cache.setObject(loaded, forKey: fileName as NSString, cost: Self.byteCost(loaded))
            DispatchQueue.main.async { image = loaded }
        }
    }

    /// 키 하나는 크게 잡아도 180pt 다. 레티나 3배를 감안해도 이 정도면 넉넉하다.
    private static let thumbnailMaxPixel: CGFloat = 400

    /// ⚠️ **총량을 반드시 못박는다.** 익스텐션의 몫은 앱보다 훨씬 작아서, 상한 없는 캐시는
    ///    그 자체가 죽는 이유가 된다. 앱 목록의 캐시(32MB)보다 한참 작게 잡는다.
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 24
        c.totalCostLimit = 6 * 1024 * 1024   // 6MB
        return c
    }()

    /// 캐시가 스스로 덜어낼 수 있도록 알려 주는 대략의 크기(바이트).
    private static func byteCost(_ image: UIImage) -> Int {
        Int(image.size.width * image.scale * image.size.height * image.scale * 4)
    }
}

#Preview {
    KeyboardView()
}

// 템플릿 입력 오버레이
struct TemplateInputOverlay: View {
    @ObservedObject var state: TemplateInputState

    /// 누가 이 화면을 띄우고 있는가. **값이 없을 때 할 수 있는 일이 갈린다.**
    ///
    /// ⚠️ 앱 안(미리보기)에서는 여기서 바로 값을 적어 넣을 수 있다. 시스템 키보드를
    ///    올릴 수 있으니까. 진짜 키보드 익스텐션은 **자기가 키보드라서** 글자를 받을
    ///    자판을 따로 부를 수 없다. 그래서 그쪽에는 "앱에서 추가하고 오세요"로 안내한다.
    ///    같은 화면이지만 할 수 있는 일이 다른 것은 이 한 가지 때문이다.
    var hostKind: KeyboardHostKind = .keyboardExtension

    /// 지금 **튜토리얼이 손을 잡고 있는가.** 그러면 다음에 누를 곳마다 파형이 인다.
    ///
    /// ⚠️ 평소에는 켜지 않는다. 늘 물결치는 화면은 안내가 아니라 소음이고,
    ///    무엇보다 이 연출의 뜻("여기가 다음")이 닳아 없어진다.
    var guidesUser: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    /// 대비 증가를 켠 사람에게는 흐린 글자와 선을 끌어올린다.
    /// ⚠️ 익스텐션은 앱의 `AppThemedContainer` 를 거치지 않으므로 **여기서 직접 본다.**
    @Environment(\.colorSchemeContrast) private var contrast
    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark,
                         increasedContrast: contrast == .increased)
    }

    /// 한 칸만 펼칠지. App Group 이라 앱 무대와 키보드 익스텐션이 같은 값을 본다.
    @AppStorage(DefaultsKey.keyboardCompactPlaceholders, store: AppGroup.defaults)
    private var compactPlaceholders: Bool = true

    /// 지금 펼쳐 둘 칸.
    ///
    /// ⚠️ 아무것도 안 골라 둔 상태(화면을 막 열었을 때)를 따로 초기화하지 않는다.
    ///    **아직 안 채운 첫 칸**을 그때그때 계산해 쓴다. `onAppear` 로 값을 심어 두면
    ///    다른 템플릿을 열었을 때 앞 템플릿의 칸을 가리킨 채로 남는 순간이 생긴다.
    ///
    /// 다 채웠으면 nil 이다. 그때는 전부 접혀서 채운 값들이 한눈에 보이고,
    /// 남은 일은 입력하기를 누르는 것뿐이다.
    private var focusedPlaceholder: String? {
        if let focused = state.currentFocusedPlaceholder,
           state.placeholders.contains(focused) {
            return focused
        }
        return TemplateInputState.nextUnfilled(in: state.placeholders,
                                               inputs: state.inputs,
                                               after: nil)
    }

    /// 접어 둘 칸인가.
    ///
    /// ⚠️ 빈칸이 하나뿐이면 접지 않는다. 접을 것이 없는데 접는 시늉만 하면
    ///    한 번 더 눌러야 하는 일만 늘어난다.
    private func isCollapsed(_ placeholder: String) -> Bool {
        guard compactPlaceholders, state.placeholders.count > 1 else { return false }
        return focusedPlaceholder != placeholder
    }

    /// 값이 정해지면 **다음 빈칸으로 저절로 넘어간다.**
    ///
    /// 이것이 없으면 접기는 손해다. 한 칸 채울 때마다 다음 칸을 손으로 눌러 펼쳐야 하니
    /// 스크롤 대신 탭이 늘어날 뿐이다. 넘어가 주면 누르는 횟수는 예전과 같고 자리만 번다.
    private func advanceFocus(from placeholder: String, filled value: String) {
        guard compactPlaceholders, !value.isEmpty else { return }
        var inputs = state.inputs
        inputs[placeholder] = value
        let next = TemplateInputState.nextUnfilled(in: state.placeholders,
                                                   inputs: inputs,
                                                   after: placeholder)
        withAnimation(.easeOut(duration: 0.18)) {
            state.currentFocusedPlaceholder = next
        }
    }

    /// 접힌 한 줄. 이름과 고른 값만 보여주고, 누르면 펼쳐진다.
    private func collapsedRow(_ placeholder: String) -> some View {
        let value = state.inputs[placeholder] ?? ""
        return Button {
            KeyboardHaptics.tap()
            withAnimation(.easeOut(duration: 0.18)) {
                state.currentFocusedPlaceholder = placeholder
            }
        } label: {
            HStack(spacing: 8) {
                Text(placeholder.strippingTemplateBraces)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radiusXs, style: .continuous)
                            .fill(theme.accentSoft)
                    )
                    .lineLimit(1)

                if value.isEmpty {
                    Text(NSLocalizedString("아직 안 골랐어요", comment: "Placeholder not chosen yet"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(value)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Color(UIColor.systemGreen))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Image(systemName: AppSymbol.chevronForward)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(NSLocalizedString("눌러서 이 빈칸을 펼칩니다", comment: "Collapsed placeholder row hint"))
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 헤더 - 항상 보임: [00][000][0000] + 입력 + 닫기
            HStack(spacing: 8) {
                    Spacer()

                    // 숫자 플레이스홀더가 있을 때만 자릿수 패드 표시
                    if let numericPH = state.placeholders.first(where: { TemplateVariableProcessor.isNumericToken($0) }) {
                        HStack(spacing: 6) {
                            ForEach(["0", "00", "000", "0000"], id: \.self) { zeros in
                                let cur = state.inputs[numericPH] ?? ""
                                let inactive = cur.isEmpty || cur == "0"
                                Button {
                                    let v = state.inputs[numericPH] ?? ""
                                    guard !v.isEmpty && v != "0" else { return }
                                    guard v.count + zeros.count <= 13 else { return }
                                    state.inputs[numericPH] = v + zeros
                                    state.updateAllPlaceholdersFilled()
                                    KeyboardHaptics.tap()
                                } label: {
                                    Text(zeros)
                                        .font(.system(.footnote, design: .monospaced, weight: .semibold))
                                        .lineLimit(1)
                                        .fixedSize()
                                        .frame(height: 36)
                                        .padding(.horizontal, 10)
                                        .background(inactive ? theme.accent.opacity(0.05) : theme.accent.opacity(0.12))
                                        .foregroundColor(inactive ? theme.accent.opacity(0.35) : theme.accent)
                                        .cornerRadius(theme.radiusXs)
                                }
                                .disabled(inactive)
                            }
                        }
                    }

                    // 입력 버튼 (항상 노출)
                    Button {
                        completeInput()
                    } label: {
                        Text(NSLocalizedString("입력하기", comment: "Insert with template button"))
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundColor(theme.accentFg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(state.allPlaceholdersFilled ? theme.accent : Color.gray.opacity(0.4))
                            .cornerRadius(theme.radiusSm)
                    }
                    .disabled(!state.allPlaceholdersFilled)
                    // 채울 것을 다 채웠으면 **다음은 여기**라고 알린다.
                    .overlay {
                        if guidesUser && state.allPlaceholdersFilled {
                            KeyRipple(shape: RoundedRectangle(cornerRadius: theme.radiusSm,
                                                              style: .continuous),
                                      color: theme.accent, reach: 10)
                        }
                    }

                    // 닫기
                    Button {
                        withAnimation {
                            state.isShowing = false
                            state.currentFocusedPlaceholder = nil
                        }
                    } label: {
                        Image(systemName: AppSymbol.xmarkCircleFill)
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .accessibilityLabel(NSLocalizedString("닫기", comment: "Close"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))

                Divider()

                // MARK: 컬러 프리뷰
                Text(previewText)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(theme.radiusXs)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // MARK: 플레이스홀더 입력 (스크롤)
                ScrollView {
                    VStack(spacing: 16) {
                        if state.placeholders.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: AppSymbol.questionmarkCircle)
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text(NSLocalizedString("No template variables", comment: "Empty state: no template variables"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("This template has no values to set.\nPlease try again.", comment: "Empty state: no template variables hint"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        } else {
                            ForEach(state.placeholders, id: \.self) { placeholder in
                                // 한 칸만 펼친다. 나머지는 이름과 고른 값만 한 줄로 접어 둔다.
                                // (설정 > 키보드 > 빈칸 한 칸씩 채우기. 끄면 예전처럼 전부 펼친다)
                                if isCollapsed(placeholder) {
                                    collapsedRow(placeholder)
                                } else {
                                PlaceholderInputView(
                                    hostKind: hostKind,
                                    guidesUser: guidesUser,
                                    placeholder: placeholder,
                                    // ⚠️ 값을 고른다고 **바로 넣지 않는다.**
                                    //
                                    //    예전에는 마지막 빈칸이 채워지는 순간 곧바로
                                    //    `completeInput()` 이 돌아 화면이 닫혔다. 그래서 위에
                                    //    있는 미리보기가 무엇을 위해 있는 것인지 알 수 없었다
                                    //    바뀌는 장면이 안 보이고 결과만 남으니까.
                                    //
                                    //    이 화면이 가르치려는 것이 바로 그 장면이다.
                                    //    "{이름} 자리에 고객님이 들어가는구나"를 **눈으로 본 뒤에**
                                    //    입력하기를 누르는 것과, 눌렀더니 글이 들어가 있는 것은
                                    //    같은 결과지만 배우는 것이 다르다.
                                    //
                                    //    고르는 일과 넣는 일을 떼어 놓으면 고쳐 볼 수도 있다.
                                    //    "대표님으로 바꿔 볼까"가 가능해진다.
                                    selectedValue: Binding(
                                        get: { state.inputs[placeholder] ?? "" },
                                        set: { newValue in
                                            state.inputs[placeholder] = newValue
                                            state.updateAllPlaceholdersFilled()
                                            advanceFocus(from: placeholder, filled: newValue)
                                        }
                                    ),
                                    templateId: state.templateId
                                )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    // ⚠️ 아래를 넉넉히 비운다. 앱 안에서는 **탭바가 이 위에 떠 있어서**,
                    //    빈칸이 넷다섯인 템플릿을 열면 마지막 칸이 탭바 뒤에 깔린다.
                    //    보이지도 않고 눌리지도 않는 칸이 생기는 것이라, 빈칸이 많을수록
                    //    (= 이 화면이 가장 필요할 때) 못 쓰게 된다.
                    .padding(.bottom, hostKind == .inApp ? 96 : 16)
                }
                .background(Color(UIColor.systemBackground))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    /// 넣으면 이렇게 된다 - **실제로 들어갈 것**을 그린다.
    ///
    /// ⚠️ 예전에는 `inputs` 에 없는 토큰을 전부 빈칸으로 그렸다. 그런데 `{날짜}` 같은
    ///    자동 변수는 넣는 순간 시스템이 채운다. 그래서 화면에는 **구멍이 둘로 보이는데
    ///    채우는 칸은 하나**뿐이었고, 하나가 빠진 것처럼 읽혔다. 빠진 적은 없었다
    ///    미리보기가 결과와 다른 그림을 그리고 있었을 뿐이다.
    ///
    /// ⚠️ 색이 셋인 이유: **누가 채웠는지가 다르다.**
    ///    · 내가 고른 값 - 초록. 내가 한 일이다.
    ///    · 알아서 채워진 값 - 흐린 글자. 손댈 것이 없다는 뜻이다.
    ///    · 아직 빈칸 - 칩. 여기가 내가 할 일이다.
    ///    셋을 같은 색으로 칠하면 "그래서 내가 뭘 해야 하지"가 화면에서 사라진다.
    private var previewText: AttributedString {
        let font: Font = .subheadline
        var out = AttributedString()
        if !state.baseMemoValue.isEmpty {
            out += state.baseMemoValue.templateAwareAttributed(theme: theme, font: font)
            out += AttributedString("\n")
        }
        for seg in TemplatePlaceholder.previewSegments(of: state.originalText,
                                                       inputs: state.inputs,
                                                       clipboard: clipboardPreview) {
            switch seg.kind {
            case .filled:
                var filled = AttributedString(seg.text)
                filled.foregroundColor = Color(UIColor.systemGreen)
                filled.font = font.weight(.semibold)
                out += filled
            case .automatic:
                var auto = AttributedString(seg.text)
                auto.foregroundColor = theme.textMuted
                auto.font = font
                out += auto
            case .blank, .plain:
                out += seg.text.templateAwareAttributed(theme: theme, font: font)
            }
        }
        return out
    }

    /// `{클립보드}` 가 있을 때만 읽는다 - iOS 는 읽을 때마다 붙여넣기 프롬프트를 띄울 수 있다.
    private var clipboardPreview: String? {
        guard TemplateVariableProcessor.containsClipboardToken(state.originalText) else { return nil }
        return UIPasteboard.general.string
    }

    private func completeInput() {
        var userInfo: [String: Any] = [
            "text": state.originalText,
            "inputs": state.inputs
        ]
        if let baseId = state.baseMemoId { userInfo["baseMemoId"] = baseId }
        if let templateId = state.templateId { userInfo["memoId"] = templateId }
        NotificationCenter.postOnMain(
            name: Notification.Name.templateInputComplete,
            object: nil,
            userInfo: userInfo
        )
        withAnimation {
            state.isShowing = false
            state.currentFocusedPlaceholder = nil
            state.baseMemoId = nil
        }
    }
}

// 플레이스홀더 입력 뷰 (선택 방식 + 숫자 토큰 직접 입력)
struct PlaceholderInputView: View {
    let hostKind: KeyboardHostKind
    /// 튜토리얼이 손을 잡고 있는가 - 고를 값들에 파형이 인다.
    var guidesUser: Bool = false
    let placeholder: String
    @Binding var selectedValue: String
    let templateId: UUID?

    @Environment(\.colorScheme) private var colorScheme
    /// 대비 증가를 켠 사람에게는 흐린 글자와 선을 끌어올린다.
    /// ⚠️ 익스텐션은 앱의 `AppThemedContainer` 를 거치지 않으므로 **여기서 직접 본다.**
    @Environment(\.colorSchemeContrast) private var contrast
    private var theme: AppTheme {
        AppTheme.resolve(kind: .paper, isDark: colorScheme == .dark,
                         increasedContrast: contrast == .increased)
    }

    /// 고를 수 있는 값들. **한 번 읽어 들고 있는다.**
    ///
    /// ⚠️ 예전에는 계산 프로퍼티라 body 가 그려질 때마다 저장소를 읽었다. 평소에는
    ///    티가 안 났는데, 파형(`TimelineView`)이 들어오면서 body 가 초당 수십 번
    ///    다시 그려지자 **App Group 을 초당 수십 번 읽고 JSON 을 그만큼 디코딩**하게 됐다.
    ///    (로그도 그만큼 쏟아진다)
    ///
    /// ⚠️ 그리는 자리에서 저장소를 직접 읽지 않는다. 언제 몇 번 그릴지는 SwiftUI 가
    ///    정하는 일이라, 그 횟수에 값이 딸려 가면 안 된다.
    @State private var predefinedValues: [String] = []
    /// 값을 적는 칸. 앱 안에서만 쓰인다.
    @State private var draftValue: String = ""
    @FocusState private var draftFocused: Bool

    private func reloadValues() {
        predefinedValues = PredefinedValuesStore.shared
            .getValuesForTemplate(placeholder: placeholder, templateId: templateId)
    }

    private var trimmedDraft: String {
        draftValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 적은 값이 이미 저장 목록에 있는가.
    private var isDraftKept: Bool {
        !trimmedDraft.isEmpty && predefinedValues.contains(trimmedDraft)
    }

    /// 적은 값을 **이번에만** 쓴다. 저장 목록에는 넣지 않는다.
    ///
    /// ⚠️ 예전에는 적는 즉시 목록에 넣었다. 한 번 쓰고 말 값(오늘 회의 장소, 이번 주문번호)
    ///    까지 칩으로 남아 목록이 금세 못 쓰게 됐다. 남길 값은 옆의 별이 정한다.
    ///    (앱 쪽 채우기 창도 같은 규칙이다 - 두 곳이 다르면 어디서 적었는지에 따라 결과가 갈린다)
    private func commitDraft() {
        guard !trimmedDraft.isEmpty else { return }
        selectedValue = trimmedDraft
        draftFocused = false
        KeyboardHaptics.tap()
    }

    /// 적은 값을 다음에도 쓰게 저장한다.
    private func keepDraft() {
        let value = trimmedDraft
        guard !value.isEmpty, !predefinedValues.contains(value) else { return }
        PredefinedValuesStore.shared.addValue(value,
                                              for: placeholder,
                                              sourceMemoId: templateId,
                                              sourceMemoTitle: placeholder.strippingTemplateBraces)
        reloadValues()
        selectedValue = value
        KeyboardHaptics.tap()
    }

    /// v4.0.8: 토큰명에 금액/amount/qty 등 키워드가 있으면 numeric 직접 입력 모드.
    private var isNumericToken: Bool {
        TemplateVariableProcessor.isNumericToken(placeholder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if isNumericToken {
                numericInputSection
            } else {
                textPredefinedSection
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // ⚠️ 빈칸 하나가 **한 덩어리**로 읽혀야 한다. 여백은 **가까운 쪽**을 말해 주지만
        //    **경계**를 말해 주지는 못해서, 빈칸이 넷이 되자 "이 칩 줄이 위 이름 것인가
        //    아래 것인가"가 매번 헷갈렸다.
        //
        // ⚠️ **판은 한 겹뿐이다.** 처음에는 바탕에 테두리까지 둘렀는데, 값이 없는 칸은
        //    안내 패널이 이미 자기 판을 갖고 있어 **판 안에 판**이 됐다. 겹쳐 놓으면
        //    경계가 분명해지는 게 아니라 무엇이 한 덩어리인지가 흐려진다.
        //    그래서 테두리를 빼고, 안내 패널이 뜨는 칸은 그 패널을 판으로 삼는다.
        .background(cardBackground)
        .onAppear(perform: reloadValues)
    }

    /// 이 칸이 앉는 판. **값이 없을 때는 그리지 않는다** - 안내 패널이 이미 판이다.
    @ViewBuilder
    private var cardBackground: some View {
        if predefinedValues.isEmpty {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                .fill(theme.surfaceAlt.opacity(colorScheme == .dark ? 0.5 : 0.7))
        }
    }

    // MARK: - 이 칸이 무슨 칸인가

    /// **어느 빈칸의 값을 고르는 중인지** 알려 주는 한 줄.
    ///
    /// ⚠️ 이게 없던 동안, 빈칸이 넷인 템플릿(송금 양식: 금액·수신인·IBAN·SWIFT)을 열면
    ///    **이름 없는 칩 줄이 네 개** 나왔다. 어느 줄이 무슨 값인지 알 길이 없어서,
    ///    위 미리보기와 아래 칩을 눈으로 번갈아 맞춰 봐야 했다.
    ///    빈칸이 하나뿐일 때는 티가 안 나던 문제라 오래 남아 있었다.
    ///
    /// ⚠️ 이름은 위 미리보기의 **칩과 같은 모습**으로 그린다. 미리보기에서 `{수신인}` 으로
    ///    보이던 것이 여기서는 다른 모양이면, 그 둘이 같은 자리라는 것을 스스로 이어야 한다.
    ///
    /// ⚠️ 고른 값을 오른쪽에 함께 적는다. 칩은 가로로 넘칠 수 있어 고른 것이 화면 밖으로
    ///    밀려나 있을 수 있는데, 그러면 "이 칸은 채웠나?"에 답할 수가 없다.
    ///    색도 미리보기와 맞춘다 - 채운 값은 초록이다.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(placeholder.strippingTemplateBraces)
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: theme.radiusXs, style: .continuous)
                        .fill(theme.accentSoft)
                )
                .lineLimit(1)

            Spacer(minLength: 0)

            if selectedValue.isEmpty {
                Text(NSLocalizedString("아직 안 골랐어요", comment: "Placeholder not chosen yet"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(selectedValue)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(UIColor.systemGreen))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Numeric input
    // 자릿수 패드(00·000·0000) + 1-9 수평 스크롤.

    @ViewBuilder
    private var numericInputSection: some View {
        VStack(spacing: 8) {
            // 전체 너비: [1][2][3][4][5][6][7][8][9][⌫]
            HStack(spacing: 6) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) { digit in
                    numericScrollKey(digit)
                }
                numericScrollBackspace
            }

            // 사전 저장 값 빠른 선택
            if !predefinedValues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(predefinedValues, id: \.self) { value in
                            Button {
                                selectedValue = value
                                KeyboardHaptics.tap()
                            } label: {
                                Text(value)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(selectedValue == value ? theme.accent.opacity(0.2) : Color(UIColor.systemGray5))
                                    .foregroundColor(selectedValue == value ? theme.accent : .primary)
                                    .cornerRadius(theme.radiusSm)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func numericScrollKey(_ digit: String) -> some View {
        Button {
            guard selectedValue.count + digit.count <= 13 else { return }
            if selectedValue.isEmpty && digit == "00" {
                selectedValue = "0"
            } else if selectedValue == "0" {
                selectedValue = digit == "0" || digit == "00" ? "0" : digit
            } else {
                selectedValue += digit
            }
            KeyboardHaptics.tap()
        } label: {
            Text(digit)
                .font(.system(.headline, design: .monospaced, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(theme.radiusXs)
        }
    }

    @ViewBuilder
    private var numericScrollBackspace: some View {
        Button {
            if !selectedValue.isEmpty { selectedValue.removeLast() }
            KeyboardHaptics.tap()
        } label: {
            Image(systemName: AppSymbol.deleteLeft)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(UIColor.systemGray4))
                .foregroundColor(.primary)
                .cornerRadius(theme.radiusXs)
        }
        .accessibilityLabel(NSLocalizedString("지우기", comment: "Backspace button"))
    }

    // MARK: - 값이 아직 없을 때

    /// 고를 값이 하나도 없는 자리.
    ///
    /// ⚠️ 예전에는 여기가 **막다른 길**이었다. "저장된 값이 없어요 / 앱에서 추가하세요"만
    ///    적혀 있어서, 앱 안에서 이 화면을 보고 있는 사람에게도 앱으로 가라고 했다.
    ///    이미 앱인데.
    ///
    /// ⚠️ 앱 안에서는 여기서 바로 적어 넣는다. 진짜 익스텐션에서는 그럴 수 없어서
    ///    (자기가 키보드라 글자를 받을 자판을 부를 수 없다) 예전 안내를 그대로 둔다.
    @ViewBuilder
    private var emptyValuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: AppSymbol.exclamationmarkTriangleFill)
                    .font(.caption)
                    .foregroundColor(.orange)
                Text(NSLocalizedString("No saved values", comment: "Placeholder values empty title"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }

            if hostKind == .inApp {
                Text(NSLocalizedString("적은 값은 이번에만 써요. 별을 누르면 다음에도 쓰게 저장돼요",
                                       comment: "Fill sheet: one-off value hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    TextField(String(format: NSLocalizedString("%@ 값",
                                                               comment: "Placeholder value field prompt"),
                                     placeholder.strippingTemplateBraces),
                              text: $draftValue)
                        .textFieldStyle(.plain)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(theme.radiusSm)
                        .focused($draftFocused)
                        .submitLabel(.done)
                        .onSubmit { commitDraft() }

                    // 남길 값만 별로. 누르지 않으면 이번에만 쓰고 사라진다.
                    Button(action: keepDraft) {
                        Image(systemName: isDraftKept ? AppSymbol.starFill : AppSymbol.star)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(isDraftKept ? .yellow : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                    }
                    .disabled(trimmedDraft.isEmpty || isDraftKept)
                    .accessibilityLabel(isDraftKept
                        ? NSLocalizedString("이미 저장해 둔 값이에요", comment: "Fill sheet: value already kept")
                        : NSLocalizedString("이 값 저장해 두기", comment: "Fill sheet: keep this value"))

                    Button(action: commitDraft) {
                        Text(NSLocalizedString("쓰기", comment: "Use typed value button"))
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.accentFg)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(trimmedDraft.isEmpty ? Color.gray.opacity(0.4) : theme.accent)
                            .cornerRadius(theme.radiusSm)
                    }
                    .disabled(trimmedDraft.isEmpty)
                }
            } else {
                Text(String(format: NSLocalizedString("Open the app to add values for '%@' in placeholder settings", comment: "Placeholder values empty hint"), placeholder.strippingTemplateBraces))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(theme.radiusXs)
    }

    // MARK: - Text predefined (existing flow)

    @ViewBuilder
    private var textPredefinedSection: some View {
        if predefinedValues.isEmpty {
            emptyValuesSection
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(predefinedValues, id: \.self) { value in
                        Button {
                            selectedValue = value
                            KeyboardHaptics.tap()
                        } label: {
                            Text(value)
                                .font(.footnote.weight(selectedValue == value ? .semibold : .regular))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedValue == value ? theme.accent : Color(UIColor.systemGray5))
                                .foregroundColor(selectedValue == value ? theme.accentFg : .primary)
                                .cornerRadius(theme.radiusLg)
                        }
                        // ⚠️ 파형은 **아직 안 고른 것**에만 인다. 이미 고른 칩에까지 얹으면
                        //    "여기를 눌러라"가 아니라 그냥 장식이 되고, 무엇보다
                        //    고른 것과 안 고른 것의 차이가 흐려진다.
                        .overlay {
                            if guidesUser && selectedValue != value {
                                KeyRipple(shape: Capsule(), color: theme.accent, reach: 8)
                            }
                        }
                    }
                }
                // 파형이 잘리지 않게 - ScrollView 는 넘치는 것을 잘라낸다.
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - 가리키는 키의 파형

/// 튜토리얼이 가리키는 키에서 **밖으로 번져 나가는 파형.**
///
/// ⚠️ 예전에는 테두리 한 줄에 그림자였다. 그런데 이 키보드에는 이미 테두리가 여럿이다
///    카테고리 색 테두리, 콤보 점선, 키캡 자체의 윤곽. 거기에 테두리를 하나 더 얹으면
///    **"또 하나의 테두리"**로 읽히지 눈이 끌려가지 않는다. 가만히 있는 것은 배경이 된다.
///
/// ⚠️ 파형은 **키 밖으로 나간다.** 키 안에서 일어나는 일은 키의 생김새로 읽히지만,
///    바깥으로 번지는 것은 주변과 다른 사건이라 주변시로도 잡힌다. 화면에서 이것만
///    움직이면 눈은 반드시 그리로 간다.
///
/// ⚠️ 키 자체는 **덮지 않는다.** 파형은 윤곽선만 그리고 속은 비운다 - 글자를 가리면
///    무엇을 누르라는 건지 읽을 수가 없다.
///
/// ⚠️ 움직임 줄이기를 켠 사람에게는 번지지 않는다. 대신 **가만히 있는 두 겹**을 둔다
///    움직임을 뺀다고 표시까지 없애면 그 사람만 무엇을 누를지 모르게 된다.
/// ⚠️ 어떤 모양이든 감쌀 수 있게 열어 뒀다. 튜토리얼이 가리키는 것은 키만이 아니다
///    템플릿의 값 칩, 입력하기 버튼, 보내기 동그라미까지 **차례로** 눈을 데려가야 한다.
///    모양마다 다른 연출을 쓰면 그 셋이 같은 뜻이라는 것이 안 읽힌다.
struct KeyRipple<S: InsettableShape>: View {
    let shape: S
    let color: Color
    /// 얼마나 멀리 번지는가(pt). 좁은 자리에서는 줄여 옆을 침범하지 않게 한다.
    var reach: CGFloat = 14

    /// 한 겹이 태어나서 사라지기까지(초).
    private static var period: Double { 1.6 }
    /// 몇 겹이 동시에 번지는가. 셋이면 끊기지 않고 이어져 보인다.
    private static var ringCount: Int { 3 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                still
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<Self.ringCount, id: \.self) { i in
                            ring(progress: phase(t, index: i))
                        }
                        // 가운데 한 겹은 늘 남아 있다 - 파형이 잦아든 순간에도
                        // 가리키는 것이 무엇인지 사라지지 않는다.
                        shape.strokeBorder(color.opacity(0.9), lineWidth: 2.5)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// 겹마다 시작을 어긋나게 해 물결이 이어지게 한다.
    private func phase(_ t: TimeInterval, index: Int) -> Double {
        let offset = Double(index) / Double(Self.ringCount)
        return ((t / Self.period) + offset).truncatingRemainder(dividingBy: 1)
    }

    /// 한 겹 - 밖으로 나가며 옅어지고 가늘어진다.
    private func ring(progress p: Double) -> some View {
        let spread = reach * CGFloat(p)
        return shape
            .strokeBorder(color.opacity(0.55 * (1 - p)), lineWidth: 3 * (1 - p) + 0.5)
            .padding(-spread)
    }

    /// 움직임 없이도 "여기"가 읽히게 - 굵은 한 겹과 옅은 한 겹.
    private var still: some View {
        ZStack {
            shape.strokeBorder(color.opacity(0.25), lineWidth: 2).padding(-reach / 2)
            shape.strokeBorder(color, lineWidth: 3)
        }
    }
}

// MARK: - Type Visual Style
// `TypeVisualStyle` 과 타입별 규칙은 DesignSystem/MemoTypeStyle.swift 로 옮겼다.
// 앱 카드와 키보드 키가 같은 파일을 봐야 두 화면이 갈라지지 않는다.

// MARK: - DisplayItem

/// 메모 그리드 1셀. 같은 메모가 attached template으로 2셀로 expand될 때
/// useTemplate 값으로 구분. id는 (memoId, useTemplate) 합성으로 SwiftUI ForEach 충돌 방지.
struct DisplayItem: Identifiable {
    let memo: Memo
    let useTemplate: Bool
    var id: String { "\(memo.id.uuidString)-\(useTemplate ? "t" : "n")" }
}
