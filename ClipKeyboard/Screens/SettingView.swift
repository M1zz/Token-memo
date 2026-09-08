//
//  SettingView.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/06/05.
//

import SwiftUI
import StoreKit
import LeeoKit

struct SettingView: View {

    @Environment(\.requestReview) var requestReview
    @Environment(\.appTheme) private var theme
    @ObservedObject private var proManager = StoreManager.shared
    @State private var showPaywall = false
    /// 지금 가진 단축어 개수 - 화면에 들어올 때와 데이터가 바뀔 때만 다시 센다.
    /// ⚠️ 그릴 때마다 세면 설정을 스크롤하는 내내 저장 파일을 읽는다.
    @State private var memoCountState = 0
    /// 예전 목록 화면 ⋯ 메뉴에 있던 것들. 바가 넘쳐서 여기로 옮겼다.
    @State private var showPlaceholderManagement = false
    @State private var showKeyboardGuide = false
    @State private var securePINSet = false
    /// 기기 간 메모 동기화(실험적) - App Group에 저장해 엔진/맥과 공유.
    @AppStorage(DefaultsKey.memoSyncEnabled, store: AppGroup.defaults)
    private var memoSyncEnabled: Bool = false
    /// 마스터(개발자) 모드 - 앱 정보의 버전 행을 7번 탭하면 토글. 피드백 인박스 진입점 노출.
    @AppStorage(DefaultsKey.masterModeEnabled) private var masterModeEnabled: Bool = false
    /// `{날짜}` 모양. App Group 이라 키보드도 같은 값을 본다.
    @AppStorage(DefaultsKey.templateDateFormat, store: AppGroup.defaults)
    private var dateTokenFormatRaw: String = DateTokenFormat.automatic.rawValue
    /// `{시간}` 모양.
    @AppStorage(DefaultsKey.templateTimeFormat, store: AppGroup.defaults)
    private var timeTokenFormatRaw: String = TimeTokenFormat.automatic.rawValue
    /// 키보드에서 빈칸을 채울 때 한 칸만 펼칠지. App Group - 키보드도 같은 값을 읽는다.
    @AppStorage(DefaultsKey.keyboardCompactPlaceholders, store: AppGroup.defaults)
    private var compactPlaceholders: Bool = true
    @State private var versionTapCount = 0
    @State private var showMasterModeAlert = false
    /// 모든 데이터 삭제 - 되돌릴 수 없어 2단계로 확인받는다.
    /// 튜토리얼 다시 하기 확인 - 무엇이 지워지고 무엇이 남는지 먼저 알린다.
    @State private var showTutorialRestartConfirm = false
    @State private var showWipeConfirm = false      // 1단계: 무엇이 지워지는지 안내
    @State private var showWipeFinalConfirm = false // 2단계: 마지막 확인
    @State private var wipeResultMessage: String?
    /// 데모 데이터 토글 - 켜면 샘플 페르소나 데이터, 끄면 내 데이터 복원(DemoDataService).
    @AppStorage(DefaultsKey.demoDataActive, store: AppGroup.defaults)
    private var demoDataActive: Bool = false
    @State private var demoResultMessage: String?
    /// 날인·봉인 등 입력 반응 마스터 스위치. App Group - 키보드 익스텐션도 같은 값을 읽는다.
    @AppStorage(DefaultsKey.delightEffectsEnabled, store: AppGroup.defaults)
    private var delightEffectsEnabled: Bool = true
    /// 단축어 탭의 첫 화면(목록 / 키보드 무대). 앱 안에서만 쓰므로 표준 UserDefaults.
    /// ⚠️ 기본값은 목록 - 쓰던 사람의 첫 화면이 업데이트로 바뀌면 안 된다.
    @AppStorage(DefaultsKey.snippetsTabStyle)
    private var snippetsTabStyleRaw: String = SnippetsTabStyle.list.rawValue

    // MARK: 데모 데이터 섹션
    // 앱을 처음 둘러보거나 스크린샷·영상을 찍을 때, 잘 짜인 샘플 한 벌을 즉시 켜고 끌 수 있게 한다.
    // 켤 때 내 데이터는 백업되고 끄면 그대로 복원된다(DemoDataService).
    // ⚠️ body의 List 안에 인라인으로 두면 타입 체크 시간이 폭발한다(빌드 실패) - 반드시 분리 유지.
    /// 데모 토글 한 줄 - "화면과 표시" 섹션의 **맨 아래**에 붙는다.
    /// ⚠️ 예전에는 자기 섹션(제목 "데모")을 따로 갖고 위에서 두 번째에 있었다. 둘러보기용
    ///    가짜 데이터가 매일 쓰는 설정보다 먼저 보일 이유가 없다.
    @ViewBuilder
    private var demoToggleRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { demoDataActive },
                set: { newValue in
                    let ok = newValue ? DemoDataService.shared.enable()
                                      : DemoDataService.shared.disable()
                    // 서비스가 App Group 플래그를 갱신하므로 @AppStorage가 자동 반영된다.
                    // 실패했을 때만 알린다(성공은 화면 변화로 충분).
                    if !ok && newValue {
                        demoResultMessage = NSLocalizedString(
                            "데모 데이터를 켜지 못했어요. 잠시 후 다시 시도해 주세요.",
                            comment: "Demo data enable failed message")
                    }
                }
            )) {
                Label(NSLocalizedString("데모 데이터 사용", comment: "Demo data toggle"),
                      systemImage: AppSymbol.sparkles)
            }
            // 섹션 꼬리말은 "입력 반응" 것이라, 이 줄의 설명은 바로 아래에 붙인다.
            Text(NSLocalizedString("샘플 단축어와 클립보드 기록을 채워 앱을 바로 체험해 봅니다. 켜는 순간 내 데이터는 안전하게 보관되고, 끄면 그대로 돌아옵니다.", comment: "Demo data section explanation"))
                .font(.caption)
                .foregroundColor(theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refreshMemoCount() {
        // 한도와 같은 개수를 센다 - 심어 준 샘플은 칸을 차지하지 않는다.
        memoCountState = ProFeatureManager.ownMemoCount(((try? MemoStore.shared.load(type: .memo)) ?? []))
    }

    private func refreshSecurePINState() {
        let hash = AppGroup.defaults?.string(forKey: DefaultsKey.keyboardSecurePinHash) ?? ""
        securePINSet = !hash.isEmpty
    }

    /// 지금 고른 첫 화면. 저장된 값이 깨졌으면 목록으로 본다.
    private var currentSnippetsTabStyle: SnippetsTabStyle {
        SnippetsTabStyle(rawValue: snippetsTabStyleRaw) ?? .list
    }

    /// 첫 화면 - 고르는 일은 하위 화면(FirstScreenSettingsView)에서 한다.
    ///
    /// ⚠️ 예전에는 설명 붙은 선택 카드 두 장을 설정 목록에 그대로 펼쳐 두었다. 자리를 크게
    ///    차지해서 한 행으로 접었지만, **현재 값은 행에 남긴다**. 값이 안 보이면 눌러 보기
    ///    전에는 무엇으로 되어 있는지 알 수 없고, 첫 화면은 되돌리기가 번거로운 설정이다.
    private var firstScreenRow: some View {
        NavigationLink(destination: FirstScreenSettingsView()) {
            HStack {
                Label(NSLocalizedString("첫 화면", comment: "Settings section: first screen"),
                      systemImage: currentSnippetsTabStyle.symbolName)
                Spacer()
                Text(currentSnippetsTabStyle.localizedName)
                    .foregroundColor(theme.textMuted)
                    .font(.body)
            }
        }
    }

    /// 화면과 표시 - 눈에 보이는 것을 바꾸는 설정을 한자리에 모은다.
    /// 예전에는 "배경 이미지"만 단축어 관리에 떨어져 있어 같은 일을 두 군데서 찾아야 했다.
    ///
    /// ⚠️ body 안에 인라인으로 두면 타입 체커가 시간 초과로 컴파일을 포기한다
    ///    (body 표현식 하나가 감당하는 뷰 트리 깊이에 한계가 있다).
    ///    이 화면에 섹션을 더할 때는 이렇게 계산 프로퍼티로 빼낼 것.
    private var appearanceSection: some View {
        Section {
            firstScreenRow
            // 키 컬러가 이 섹션의 맨 위쪽에 있는 이유: 이 하나가 앱 전체의 인상을 바꾼다.
            // 아래 항목들(높이·배경·반응)은 그다음에 손보는 것들이다.
            NavigationLink(destination: KeyColorSettingsView()) {
                Label {
                    Text(NSLocalizedString("키 컬러", comment: "Settings: key color"))
                } icon: {
                    // 심볼 대신 **지금 그 색**을 보여준다. 무슨 색인지 들어가 보지 않아도 안다.
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(theme.divider, lineWidth: 0.5))
                }
            }
            NavigationLink(destination: DisplaySettingsView()) {
                Label(NSLocalizedString("단축어 표시", comment: "Memo display settings entry"),
                      systemImage: AppSymbol.rectangleGrid1x2)
            }
            // 단축어 스킨(생활 레이어)은 지금 감춰 둔다 - LivingSkin.isEnabled = false.
            // 되살리려면 그 값을 true 로. 화면(LivingSkinSettings)은 그대로 남아 있다.
            if LivingSkin.isEnabled {
                NavigationLink(destination: LivingSkinSettings()) {
                    Label(NSLocalizedString("단축어 스킨", comment: "Section: shortcut card skin"),
                          systemImage: AppSymbol.sparkles)
                }
            }
            NavigationLink(destination: ListBackgroundSettings()) {
                Label(NSLocalizedString("배경 이미지", comment: "Menu: list background image"),
                      systemImage: "photo.on.rectangle.angled")
            }
            // @AppStorage가 App Group에 직접 쓴다 - Delight.isEnabled / 키보드 익스텐션이 같은 키를 읽는다.
            Toggle(isOn: $delightEffectsEnabled) {
                Label(NSLocalizedString("입력 반응", comment: "Delight effects toggle title"),
                      systemImage: AppSymbol.handTap)
            }
            // 기기 언어와 읽고 싶은 언어가 다른 사람이 있다. iOS 설정까지 가지 않아도
            // 여기서 바로 고르게 한다(자세한 건 AppLanguage 머리말).
            NavigationLink(destination: LanguageSettingsView()) {
                Label(NSLocalizedString("언어", comment: "Settings: app language"),
                      systemImage: "globe")
            }
            // ⚠️ 데모는 **맨 아래**다. 예전에는 위에서 두 번째 섹션이라, 매일 쓰는 설정보다
            //    "둘러보기용 가짜 데이터"가 먼저 보였다. 켜 둔 사람이 끌 수 있게 남기되,
            //    자리는 화면을 바꾸는 것들 뒤에 둔다(자주 안 만지는 것은 아래로).
            if showsDemoSection { demoToggleRow }
        } header: {
            Text(NSLocalizedString("화면과 표시", comment: "Settings section: appearance"))
        } footer: {
            Text(NSLocalizedString("입력 반응은 문구를 넣을 때의 진동과 짧은 연출이에요.",
                                   comment: "Appearance section footer"))
                .font(.body)
        }
    }

    // MARK: - 섹션
    //
    // ⚠️ 섹션은 반드시 계산 프로퍼티로 분리한다. body 의 List 안에 인라인으로 늘어놓으면
    //    타입 체커가 시간 초과로 컴파일을 포기한다(이 화면에서 실제로 겪은 일이다).

    /// Pro 상태 - 결제 entitlement 만 보는 StoreManager.isPro 가 아니라 hasPermanentPro 를 본다.
    /// → 그랜드파더/TestFlight 유저도 "Pro 활성화됨"으로 올바르게 표시(업그레이드 안내 X)
    @ViewBuilder
    private var proSection: some View {
        if ProFeatureManager.hasPermanentPro {
            Section {
                HStack {
                    Image(systemName: AppSymbol.checkmarkSealFill)
                        .font(.title2)
                        .foregroundColor(.green)
                        .accessibilityHidden(true)
                    Text(NSLocalizedString("Pro 활성화됨", comment: "Pro activated"))
                        .font(.headline)
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(NSLocalizedString("Pro 활성화됨", comment: "Pro activated"))
            }
        } else if ProFeatureManager.isInTrial {
            Section {
                Button { showPaywall = true } label: {
                    HStack {
                        Image(systemName: AppSymbol.clockBadgeCheckmarkFill)
                            .font(.title2)
                            .foregroundStyle(.green.gradient)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: NSLocalizedString("체험 활성: %d일 남음", comment: "Trial active days remaining"), ProFeatureManager.trialDaysRemaining))
                                .font(.headline).foregroundColor(.primary)
                            Text(NSLocalizedString("지금 Pro로 업그레이드하면 평생 사용", comment: "Trial upsell"))
                                .font(.body).foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: AppSymbol.chevronRight).font(.body)
                            .foregroundColor(theme.textMuted).accessibilityHidden(true)
                    }
                }
                .accessibilityHint(NSLocalizedString("Pro 업그레이드 화면을 엽니다", comment: "Open paywall hint"))

                restorePurchasesButton
            }
        } else {
            Section {
                remainingSlotsRow
                Button { showPaywall = true } label: {
                    HStack {
                        Image(systemName: AppSymbol.starCircleFill)
                            .font(.title2)
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Pro 업그레이드", comment: "Pro upgrade"))
                                .font(.headline).foregroundColor(.primary)
                            Text(ProFeatureManager.canStartTrial
                                 ? String(format: NSLocalizedString("%d일 무료 체험 + 무제한 단축어, iCloud 백업", comment: "Pro features w/ trial"), ProFeatureManager.trialDurationDays)
                                 : NSLocalizedString("무제한 단축어, iCloud 백업 등", comment: "Pro features"))
                                .font(.body).foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: AppSymbol.chevronRight).font(.body)
                            .foregroundColor(theme.textMuted).accessibilityHidden(true)
                    }
                }
                .accessibilityHint(NSLocalizedString("Pro 업그레이드 화면을 엽니다", comment: "Open paywall hint"))

                restorePurchasesButton
            }
        }
    }

    /// **몇 개 더 만들 수 있는가** - Pro 구매 자리 바로 위.
    ///
    /// 왜 여기에 두는가: 한도는 만들다 막혀야 알게 되는 것이었다. 열 개째를 만들려다
    /// 막힌 사람에게 그때서야 "한도예요"라고 말하는 건 늦다. 설정을 열면 지금 몇 칸이
    /// 남았는지 먼저 보이고, 바로 아래에 그 칸을 늘리는 길이 있다.
    ///
    /// ⚠️ 숫자는 `ProFeatureManager.memoLimit` 을 본다 - 칸을 산 사람은 15가 기준이다.
    /// ⚠️ 쓰고 있는 개수는 **자기 것만** 센다. 저장을 막는 관문과 다른 숫자를 보이면,
    ///    "3칸 남았어요" 를 보고 만들러 갔다가 막히는 일이 생긴다.
    /// ⚠️ 겁을 주지 않는다. 남은 칸이 0이어도 "다 썼어요"가 아니라 몇 개 중 몇 개인지만 말한다.
    @ViewBuilder
    private var remainingSlotsRow: some View {
        let used = memoCount
        let limit = ProFeatureManager.memoLimit
        let left = max(0, limit - used)
        HStack(spacing: 12) {
            Image(systemName: AppSymbol.trayFull)
                .font(.title2)
                .foregroundColor(left == 0 ? .orange : theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: NSLocalizedString("단축어 %1$d칸 남았어요", comment: "Settings: remaining free shortcut slots"), left))
                    .font(.headline)
                    .foregroundColor(theme.text)
                Text(String(format: NSLocalizedString("%1$d개 중 %2$d개를 쓰고 있어요", comment: "Settings: used of total shortcut slots"), limit, used))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
            Spacer(minLength: 0)
            // 남은 칸을 막대로도 - 숫자보다 먼저 눈에 들어온다.
            ZStack(alignment: .leading) {
                Capsule().fill(theme.surfaceAlt).frame(width: 54, height: 6)
                Capsule()
                    .fill(left == 0 ? Color.orange : theme.accent)
                    .frame(width: max(2, 54 * CGFloat(min(used, limit)) / CGFloat(max(limit, 1))), height: 6)
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// 지금 가진 단축어 개수 - 설정을 열 때와 데이터가 바뀔 때만 센다.
    /// (계산 프로퍼티로 두면 화면을 그릴 때마다 파일을 읽는다)
    private var memoCount: Int { memoCountState }

    /// 체험 중일 때와 아닐 때 같은 버튼이 필요하다 - 한 곳에서만 고치도록 빼 둔다.
    private var restorePurchasesButton: some View {
        Button {
            Task { await proManager.restorePurchases() }
        } label: {
            Label(NSLocalizedString("이전 구매 복원", comment: "Restore"), systemImage: AppSymbol.arrowClockwise)
                .foregroundStyle(Color.secondary)
        }
        .disabled(proManager.isLoading)
        .accessibilityLabel(NSLocalizedString("이전 구매 복원", comment: "Restore"))
        .accessibilityHint(NSLocalizedString("이전에 구매한 Pro를 복원합니다", comment: "Restore purchases accessibility hint"))
    }

    /// 데모 토글을 보여줄지.
    ///
    /// 처음 둘러보는 동안에만 필요한 것이라 **2회 실행까지만** 보인다. 그 뒤에는 사라져서
    /// 평소 설정 화면이 그만큼 짧아진다. 다만 두 가지 예외가 있다.
    ///  · 켜 둔 상태라면 계속 보인다. 끌 길이 없으면 데모 데이터에 갇힌다.
    ///  · 마스터 모드에서는 항상 보인다(스크린샷·영상 촬영용).
    private var showsDemoSection: Bool {
        if demoDataActive || masterModeEnabled { return true }
        return UserDefaults.standard.integer(forKey: DefaultsKey.appLaunchCount) <= 2
    }

    /// 키보드 - 키보드로 입력할 때 일어나는 일을 전부 여기로 모은다.
    /// 붙여넣기 알림은 예전에 "데이터 & 보안"에 있었지만 보안이 아니라 입력 동작이다.
    private var keyboardSection: some View {
        Section {
            // 시트 버튼 - Label 텍스트에 .primary를 명시해 파란색 tint 방지
            Button {
                HapticManager.shared.light()
                showKeyboardGuide = true
            } label: {
                HStack {
                    Label {
                        Text(NSLocalizedString("키보드 설정 가이드", comment: "Keyboard setup guide"))
                            .foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: AppSymbol.keyboardBadgeEye)
                    }
                    Spacer()
                    // 시스템 디스클로저 인디케이터와 동일한 톤·크기로 맞춤
                    // (형제 NavigationLink 행들의 기본 chevron과 일치시키기 위함)
                    Image(systemName: AppSymbol.chevronForward)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint(NSLocalizedString("단계별 키보드 설정 가이드를 엽니다", comment: "Open keyboard setup guide hint"))

            NavigationLink(destination: KeyboardLayoutSettings()) {
                Label(NSLocalizedString("키보드 레이아웃", comment: "Keyboard layout"),
                      systemImage: AppSymbol.rectangle3Group)
            }
            NavigationLink(destination: CopyPasteView()) {
                Label(NSLocalizedString("붙여넣기 알림 허용 끄기", comment: "Paste notification settings title"),
                      systemImage: AppSymbol.docOnClipboard)
            }
            // 빈칸이 여럿인 단축어를 키보드에서 채울 때의 모양.
            // 사용자 요청에서 왔다: "빈칸이 여러 개일 때 스크롤이 번거로워서요."
            Toggle(isOn: $compactPlaceholders) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("빈칸 한 칸씩 채우기", comment: "Compact placeholder filling toggle"))
                        Text(NSLocalizedString("채우는 칸만 펼치고 나머지는 한 줄로 접어요. 빈칸이 여럿이어도 굴리지 않고 다 보입니다. 끄면 전부 펼쳐요.", comment: "Compact placeholder filling footer"))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: AppSymbol.rectangleCompressVertical)
                }
            }
            // 온디바이스 AI(iOS 26+). 설명은 행 안에 둔다 - 예전에는 이 행 하나만을 위한
            // 섹션이 따로 있었고, 섹션 머리말이 내용보다 길었다.
            NavigationLink(destination: AISettingsView()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("Apple Intelligence", comment: "AI settings status row title"))
                        Text(NSLocalizedString("클립보드 AI 분류·붙여넣기 앱 제안·번역. 모든 처리는 기기 안에서만 이루어져요.", comment: "AI settings entry footer"))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: AppSymbol.sparkles)
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("키보드", comment: "Settings section: keyboard"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
                    .textCase(.uppercase)
                Text(NSLocalizedString("iOS 설정 > 일반 > 키보드에서 추가할 수 있어요", comment: "Keyboard optional section footer"))
                    .font(.caption2)
                    .foregroundColor(theme.textFaint)
                    .textCase(.none)
            }
        }
    }

    /// 단축어 - 무엇을 저장하고 어떻게 정리하는가.
    ///
    /// ⚠️ 예전에는 목록 화면 오른쪽 위 ⋯ 메뉴에 있던 것들이다. 바에 ⋯ 와 + 와
    ///    금고를 다 두려니 시스템이 넘친다고 보고 오버플로 ⋯ 를 하나 더 만들어서
    ///    ⋯ 가 둘로 보였고, 금고는 그 안에 접혀 사라졌다. 자주 안 여는 것들은
    ///    설정에 있는 편이 찾기도 쉽다.
    private var shortcutsSection: some View {
        Section {
            // 활용 사례는 페르소나로 고르는 화면이라 페르소나와 나란히 둔다.
            // ⚠️ 예전에는 이 행이 "단축어 관리"와 "도움말" 양쪽에 있었다(같은 UsageGuideView).
            //    같은 곳으로 가는 문이 둘이면 다른 화면인 줄 안다. 여기 하나만 남긴다.
            NavigationLink(destination: UsageGuideView()) {
                Label(NSLocalizedString("이렇게들 써요", comment: "Use cases / usage scenarios"),
                      systemImage: AppSymbol.lightbulb)
            }
            NavigationLink(destination: PersonaSettingsContainer()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("페르소나", comment: "Persona setting row title"))
                        if let p = CategoryStore.shared.selectedPersona {
                            Text(p.localizedTitle)
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                } icon: {
                    Image(systemName: AppSymbol.personCropCircleBadgeCheckmark)
                }
            }
            // ⚠️ 아래 세 행(빈칸 관리 · 카테고리 관리 · 보관함)은 **붙어 있어야 한다.**
            //    셋 다 "만들어 둔 것을 들여다보는" 자리다. 보관함이 위쪽 페르소나 옆에
            //    있었더니 고르는 것들 사이에 담아 두는 것이 하나 끼어 있는 꼴이었다.
            Button {
                HapticManager.shared.light()
                showPlaceholderManagement = true
            } label: {
                Label(NSLocalizedString("빈칸 관리", comment: "Placeholder management title (by name)"),
                      systemImage: AppSymbol.listBullet)
                    .foregroundColor(theme.text)
            }
            dateFormatRow
            timeFormatRow
            // 카테고리 아이콘은 이 화면 안에서 이어서 고른다(예전에는 형제 행이었다).
            NavigationLink(destination: CategorySettings()) {
                Label(NSLocalizedString("카테고리 관리", comment: "Manage categories settings entry"),
                      systemImage: AppSymbol.folderBadgeGearshape)
            }
            NavigationLink(destination: QuickNoteInboxView()) {
                Label(NSLocalizedString("보관함", comment: "Quick note inbox entry"),
                      systemImage: AppSymbol.trayFull)
            }
        } header: {
            Text(NSLocalizedString("단축어", comment: "Settings section: shortcuts"))
        }
    }

    /// `{날짜}` · `{시간}` 을 어떤 모양으로 넣을지 고르러 가는 행.
    ///
    /// ⚠️ 행에는 **지금 값을 그 모양으로 직접 그려서** 보여준다. "MM/DD/YYYY" 같은
    ///    패턴 글자는 개발자만 읽는다. 08/31/2026 은 누구나 읽는다.
    ///
    /// 예전에는 여기가 `Picker` 였다. 사용자가 자기 모양을 만들 수 있게 되면서
    /// (더하고 지우는 자리가 필요해) 화면으로 옮겼다.
    private func tokenFormatRow<Format: TokenFormat>(
        _ type: Format.Type,
        raw: String,
        title: String,
        systemImage: String,
        chips: [TokenFormatField.Chip]
    ) -> some View {
        NavigationLink {
            TokenFormatSettingsView(title: title, chips: chips, of: Format.self)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(TokenFormatOption<Format>(raw: raw).sampleText())
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
            }
        }
    }

    private var dateFormatRow: some View {
        tokenFormatRow(DateTokenFormat.self,
                       raw: dateTokenFormatRaw,
                       title: NSLocalizedString("날짜 형식", comment: "Date format setting row title"),
                       systemImage: AppSymbol.calendar,
                       chips: TokenFormatField.dateChips)
    }

    /// 날짜 바로 아래에 둔다 - 같은 종류의 선택이다.
    private var timeFormatRow: some View {
        tokenFormatRow(TimeTokenFormat.self,
                       raw: timeTokenFormatRaw,
                       title: NSLocalizedString("시간 형식", comment: "Time format setting row title"),
                       systemImage: AppSymbol.clock,
                       chips: TokenFormatField.timeChips)
    }

    /// 내 데이터 - 내 것이 어디에 있고 어떻게 지켜지는가.
    /// 되돌릴 수 없는 삭제는 반드시 맨 아래에 둔다.
    private var myDataSection: some View {
        Section {
            NavigationLink(destination: CloudBackupView()) {
                Label(NSLocalizedString("백업 및 복원", comment: "Backup and restore"),
                      systemImage: AppSymbol.icloudAndArrowUp)
            }
            // 기기 간 동기화(실험적, Pro 전용). 설명은 행 안에 둔다 - 예전에는 이 토글
            // 하나만을 위한 섹션이 따로 있었다.
            Toggle(isOn: Binding(
                get: { memoSyncEnabled },
                set: { newValue in
                    if newValue && !ProFeatureManager.hasFullAccess {
                        // 비Pro는 결제 유도하고 토글은 켜지 않는다.
                        showPaywall = true
                    } else {
                        memoSyncEnabled = newValue            // App Group(이 기기) 즉시 반영
                        MemoSyncFlags.setEnabled(newValue)    // iCloud KV로 다른 기기에도 전파
                        // 켜면 즉시 동기화 시작(끄면 다음 실행부터 비활성).
                        if newValue { MemoSyncEngine.shared.startIfEnabled() }
                    }
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("기기 간 동기화 (베타)", comment: "Cross-device sync section header"))
                        Text(NSLocalizedString("같은 iCloud 계정의 iPhone과 Mac 사이에서 단축어를 자동으로 동기화합니다. Pro 전용이며 실험적 기능이라, 먼저 두 기기에서 잘 맞는지 확인해 보세요. 보안 단축어는 암호화된 채로 동기화됩니다.", comment: "Cross-device sync explanation"))
                            .font(.caption)
                            .foregroundColor(theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: AppSymbol.icloudAndArrowDown)
                }
            }
            NavigationLink(destination: MemoHistoryView()) {
                Label(NSLocalizedString("변경 기록 (되돌리기)", comment: "Memo change history / undo"),
                      systemImage: AppSymbol.clockArrowCirclepath)
            }
            NavigationLink(destination: SecurePINSettings()) {
                HStack {
                    Label(NSLocalizedString("보안 단축어 PIN", comment: "Secure memo PIN"),
                          systemImage: AppSymbol.lockShield)
                    Spacer()
                    Text(securePINSet
                         ? NSLocalizedString("설정됨", comment: "PIN is set")
                         : NSLocalizedString("없음", comment: "PIN not set / none"))
                        .foregroundColor(theme.textMuted).font(.body)
                }
            }
            // ⚠️ 사용 기록과 자리를 맞바꿨다. 클립보드는 **키보드 안에서 꺼내 쓰는 것**이지
            //    탭을 열어 들여다보는 것이 아니었고, 사용 기록은 가끔 열어 보는 것이라 탭이 맞다.
            NavigationLink(destination: ClipboardList()) {
                Label(NSLocalizedString("클립보드 기록", comment: "Clipboard history settings entry"),
                      systemImage: AppSymbol.clockArrowCirclepath)
            }
            // 되돌릴 수 없는 작업 - 2단계 확인을 거친다.
            // 개인정보 처리방침이 약속한 "앱 내에서 데이터 삭제" 경로이기도 하다.
            Button(role: .destructive) {
                showWipeConfirm = true
            } label: {
                Label(NSLocalizedString("모든 데이터 삭제", comment: "Delete all data settings entry"),
                      systemImage: AppSymbol.trash)
            }
        } header: {
            Text(NSLocalizedString("내 데이터", comment: "Settings section: my data"))
        }
    }

    /// 도움말과 문의 - 막혔을 때 갈 곳.
    /// 예전에는 배우는 길이 셋으로 흩어져 있었다(튜토리얼 다시 하기는 단축어 관리에,
    /// 사용 가이드는 도움말에, 활용 사례는 양쪽에).
    private var helpSection: some View {
        Section {
            NavigationLink(destination: TutorialView()) {
                Label(NSLocalizedString("사용 가이드", comment: "User guide"),
                      systemImage: AppSymbol.bookClosed)
            }
            // 한 번 배우고 끝이 아니다 - 몇 달 만에 열어 본 사람은 템플릿이 뭐였는지
            // 기억하지 못한다. 그때 다시 볼 길이 없으면 "예전엔 됐는데"로 끝난다.
            Button {
                HapticManager.shared.light()
                showTutorialRestartConfirm = true
            } label: {
                Label(NSLocalizedString("튜토리얼 다시 하기", comment: "Restart the tutorial"),
                      systemImage: "graduationcap")
                    .foregroundColor(theme.text)
            }
            // 띄엄띄엄 오는 안내에는 반드시 다시 볼 자리가 있어야 한다 - 정작 필요해진 날
            // ("그때 잠글 수 있다고 하지 않았나?") 찾을 길이 없으면 안 알려 준 것과 같다.
            NavigationLink(destination: DidYouKnowListView()) {
                Label(NSLocalizedString("그거 아세요?", comment: "Did you know header"),
                      systemImage: "lightbulb")
            }
            NavigationLink(destination: AccessibilityGuideView()) {
                Label(NSLocalizedString("손쉬운 사용", comment: "Accessibility guide settings entry"),
                      systemImage: AppSymbol.figureWalkCircle)
            }
            // 업데이트 직후 1회 뜨는 WhatsNew 와 달리 언제든 다시 볼 수 있는 기록.
            NavigationLink(destination: ChangelogView()) {
                Label(NSLocalizedString("변경사항", comment: "Changelog settings entry"),
                      systemImage: AppSymbol.clockArrowCirclepath)
            }
            NavigationLink(destination: FeedbackView()) {
                Label(NSLocalizedString("피드백 보내기", comment: "Send feedback settings entry"),
                      systemImage: AppSymbol.envelopeBadge)
            }
            NavigationLink(destination: ReviewWriteView()) {
                Label(NSLocalizedString("리뷰 남기기", comment: "Leave review"),
                      systemImage: AppSymbol.star)
            }
            // 개발자 문의: 인스타그램 DM (이메일 문의는 위 피드백 보내기에서 처리)
            Link(destination: URL(string: "https://instagram.com/lee25_ios")!) {
                Label(NSLocalizedString("인스타그램 DM (@lee25_ios)", comment: "Instagram DM contact entry"),
                      systemImage: AppSymbol.paperplaneFill)
            }
        } header: {
            Text(NSLocalizedString("도움말과 문의", comment: "Settings section: help and contact"))
        }
    }

    /// 앱 정보 - 읽고 끝나는 것들. Mac 안내가 약관 뒤에 있으면 아무도 못 본다.
    ///
    /// 인앱결제가 있는 앱은 약관·처리방침을 앱 안에서 볼 수 있어야 한다(심사 대비).
    /// 처리방침 주소는 App Store Connect 에 등록한 것과 같아야 한다.
    private var appInfoSection: some View {
        Section {
            #if !targetEnvironment(macCatalyst)
            NavigationLink(destination: MacAppIntroView()) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: theme.radiusSm)
                            // 고른 키컬러를 따라간다 - 흑백을 고른 사람의 설정에서
                            // 이 타일만 혼자 주황으로 남으면 그것만 다른 앱에서 온 것처럼 보인다.
                            .fill(LinearGradient(colors: [theme.accent,
                                                          theme.accent.mixed(with: .black, amount: 0.7)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: AppSymbol.macbook)
                            .font(.body.weight(.semibold))
                            .foregroundColor(theme.accentFg)
                            .accessibilityHidden(true)
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("ClipKeyboard for Mac", comment: "Mac app intro title"))
                            .font(.body).fontWeight(.semibold)
                        Text(NSLocalizedString("Menu bar access · Global hotkey · iCloud sync", comment: "Mac promo subtitle"))
                            .font(.body).foregroundColor(theme.textMuted)
                    }
                }
                .padding(.vertical, 4)
            }
            #endif
            // 같은 사람이 만든 다른 앱. 목록·문구·이야기는 LeeoKit 카탈로그 한 곳에 있어서
            // 앱을 새로 내도 여기 코드는 그대로다(LeeoFamilyCatalog).
            LeeoFamilySettingsRow<ClipKeyboardSpec>()
                .leeoStyle(theme.leeoStyle)
            if let url = URL(string: Constants.privacyPolicyURL) {
                Link(destination: url) {
                    Label(NSLocalizedString("개인정보 처리방침", comment: "Privacy policy settings entry"),
                          systemImage: AppSymbol.lockShield)
                }
            }
            if let url = URL(string: Constants.termsOfUseURL) {
                Link(destination: url) {
                    Label(NSLocalizedString("이용약관", comment: "Terms of use settings entry"),
                          systemImage: AppSymbol.docText)
                }
            }
            HStack {
                Text(NSLocalizedString("버전", comment: "Version label"))
                    .foregroundColor(theme.textMuted)
                Spacer()
                Text(appVersion).foregroundColor(.primary)
            }
            .contentShape(Rectangle())
            .onTapGesture { handleVersionTap() }
        } header: {
            Text(NSLocalizedString("앱 정보", comment: "App info section"))
        }
    }

    /// 개발자 전용 - 버전 행을 7번 탭하면 열린다.
    /// 머리말을 두지 않는다. 행마다 "(개발자)"가 붙어 있어 한 번 더 말할 필요가 없다.
    private var developerSection: some View {
        Section {
            NavigationLink(destination: FeedbackInboxView()) {
                Label(NSLocalizedString("접수된 피드백 (개발자)", comment: "Feedback inbox settings entry (developer)"),
                      systemImage: AppSymbol.trayFull)
            }
            NavigationLink(destination: UsageStatsView()) {
                Label(NSLocalizedString("사용 통계 (개발자)", comment: "Usage stats settings entry (developer)"),
                      systemImage: AppSymbol.chartBarXaxis)
            }
            NavigationLink(destination: CrashReportsView()) {
                Label(NSLocalizedString("안정성 (개발자)", comment: "Stability settings entry (developer)"),
                      systemImage: AppSymbol.exclamationmarkTriangleFill)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            proSection
            keyboardSection
            shortcutsSection
            appearanceSection
            myDataSection
            helpSection
            appInfoSection
            if masterModeEnabled { developerSection }
        }
        .alert(NSLocalizedString("튜토리얼을 다시 할까요?", comment: "Restart tutorial alert title"),
               isPresented: $showTutorialRestartConfirm) {
            Button(NSLocalizedString("다시 하기", comment: "Restart tutorial confirm")) {
                TutorialReset.restartAll()
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("준비된 단축어·템플릿·콤보를 다시 하나씩 눌러보며 안내해요. 목록의 단축어는 그대로 남아요.", comment: "Restart tutorial alert message"))
        }
        // ⚠️ 제목을 안 단다. 탭의 뿌리 화면이고 아래 탭바가 이미 "설정"이라고 적고 있다.
        //    안쪽 화면들(단축어 표시·키 컬러 …)은 그대로 제목을 단다 - 거기서는
        //    어디까지 들어왔는지를 제목이 말해 준다.
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshSecurePINState()
            refreshMemoCount()
        }
        // 다른 화면에서 만들거나 지우면 남은 칸도 따라와야 한다.
        .onReceive(NotificationCenter.default.publisher(for: .memoDataChanged)) { _ in
            refreshMemoCount()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        // 상단은 시스템 엣지 이펙트를 살린다 - 인라인 "설정" 타이틀이 스크롤된 행 위에
        // 그대로 겹쳐 그려지고, 투명 네비바 영역이 행 터치까지 삼키던 문제(글래스 베일이
        // 있어야 "바 아래로 들어갔다"가 시각적으로 전달됨). 하단(탭바)만 계속 숨긴다.
        .scrollEdgeEffectHidden(true, for: .bottom)
        .background(theme.bg.ignoresSafeArea())
        .contentMargins(.top, 16, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .solidNavBar(theme.bg)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showPlaceholderManagement) {
            PlaceholderManagementSheet(allMemos: (try? MemoStore.shared.load(type: .memo)) ?? [])
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showKeyboardGuide) {
            KeyboardSetupOnboardingView { showKeyboardGuide = false }
                .presentationDetents([.large])
        }
        .alert(
            masterModeEnabled
                ? NSLocalizedString("개발자 모드가 켜졌어요", comment: "Master mode enabled alert")
                : NSLocalizedString("개발자 모드가 꺼졌어요", comment: "Master mode disabled alert"),
            isPresented: $showMasterModeAlert
        ) {
            Button(NSLocalizedString("확인", comment: "OK"), role: .cancel) { }
        } message: {
            if masterModeEnabled {
                Text(NSLocalizedString("지원 섹션에 '접수된 피드백' 메뉴가 나타납니다.", comment: "Master mode enabled message"))
            }
        }
        // MARK: 모든 데이터 삭제 - 2단계 확인
        // 1단계: 무엇이 지워지고 무엇이 남는지 알린다(구매는 유지된다는 점이 중요).
        .alert(NSLocalizedString("모든 데이터를 삭제할까요?", comment: "Wipe all data confirm title"),
               isPresented: $showWipeConfirm) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("계속", comment: "Continue to final confirmation"), role: .destructive) {
                showWipeFinalConfirm = true
            }
        } message: {
            Text(NSLocalizedString("단축어·클립보드 기록·콤보·이미지·임시 저장본이 이 기기에서 모두 지워집니다. 되돌릴 수 없어요.\n\nPro 구매 권한과 iCloud 백업은 그대로 남습니다.", comment: "Wipe all data confirm message"))
        }
        // 2단계: 실수 방지를 위한 마지막 확인.
        .alert(NSLocalizedString("정말 삭제할까요?", comment: "Wipe all data final confirm title"),
               isPresented: $showWipeFinalConfirm) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("삭제", comment: "Delete confirm"), role: .destructive) {
                let result = DataWipeService.wipeAll()
                wipeResultMessage = result.isCompleteSuccess
                    ? NSLocalizedString("모든 데이터를 삭제했어요.", comment: "Wipe success message")
                    : NSLocalizedString("일부 항목을 지우지 못했어요. 앱을 다시 실행한 뒤 시도해 주세요.", comment: "Wipe partial failure message")
            }
        } message: {
            Text(NSLocalizedString("이 작업은 되돌릴 수 없습니다.", comment: "Wipe all data final confirm message"))
        }
        .alert(NSLocalizedString("삭제 완료", comment: "Wipe result alert title"),
               isPresented: Binding(get: { wipeResultMessage != nil },
                                    set: { if !$0 { wipeResultMessage = nil } })) {
            Button(NSLocalizedString("확인", comment: "OK"), role: .cancel) { wipeResultMessage = nil }
        } message: {
            Text(wipeResultMessage ?? "")
        }
        // 데모 데이터 적용 실패 안내 (성공은 화면 변화로 충분해 알리지 않는다).
        .alert(NSLocalizedString("데모 데이터", comment: "Demo data alert title"),
               isPresented: Binding(get: { demoResultMessage != nil },
                                    set: { if !$0 { demoResultMessage = nil } })) {
            Button(NSLocalizedString("확인", comment: "OK"), role: .cancel) { demoResultMessage = nil }
        } message: {
            Text(demoResultMessage ?? "")
        }
    }

    /// 버전 행 7번 탭 → 마스터(개발자) 모드 토글.
    private func handleVersionTap() {
        versionTapCount += 1
        guard versionTapCount >= 7 else { return }
        versionTapCount = 0
        masterModeEnabled.toggle()
        HapticManager.shared.light()
        showMasterModeAlert = true
    }

    // 앱 버전 정보를 Info.plist에서 자동으로 가져오기
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
}

// MARK: - Display Settings

/// 메모 표시 방식(이 앱 전용) - 메모 셀 높이 + 우상단 카테고리 심볼 표시.
struct DisplaySettingsView: View {
    @Environment(\.appTheme) private var theme
    /// 메모 구분 표시 마스터 토글 - 기본 OFF(제목만). 켜면 타입 아이콘·배지·테두리·심볼·색을 모두 표시.
    /// App Group에 저장해 키보드 익스텐션도 동일 설정을 읽는다.
    @AppStorage("showVisualCues", store: AppGroup.defaults)
    private var visible: Bool = false
    /// 메모 셀 높이 - 작게 110 / 보통 140 / 크게 180.
    @AppStorage("memoCardHeight") private var memoCardHeight: Double = 140
    /// 카드 내용 힌트 - 카드가 화면에 2초쯤 머물면 한 번 살며시 나타났다 사라지는 미리보기.
    /// App Group에 저장해 키보드 익스텐션(제목↔내용 스왑)도 동일 설정을 따른다.
    @AppStorage(DefaultsKey.contentHintEnabled, store: AppGroup.defaults)
    private var contentHintEnabled: Bool = false

    var body: some View {
        List {
            // 라이브 미리보기 - 아래 설정을 바꾸면 즉시 반영된다(실제 메모 카드와 동일 모양).
            Section(header: Text(NSLocalizedString("미리보기", comment: "Preview"))) {
                HStack(spacing: 12) {
                    previewCell(title: NSLocalizedString("단축어", comment: "Snippet (saved key-value item) display name"),
                                symbol: "folder.fill", color: theme.accent, plusTemplate: false)
                    previewCell(title: NSLocalizedString("단축어 + 템플릿", comment: "Memo + template sample"),
                                symbol: "doc.text.fill", color: .blue, plusTemplate: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .animation(.easeInOut(duration: 0.2), value: memoCardHeight)
                .animation(.easeInOut(duration: 0.2), value: visible)
            }

            // 메모 높이
            Section {
                Picker(selection: $memoCardHeight) {
                    Text(NSLocalizedString("작게", comment: "Small")).tag(110.0)
                    Text(NSLocalizedString("보통", comment: "Medium")).tag(140.0)
                    Text(NSLocalizedString("크게", comment: "Large")).tag(180.0)
                } label: {
                    Label(NSLocalizedString("단축어 높이", comment: "Memo cell height"), systemImage: AppSymbol.arrowUpAndDown)
                }
                .pickerStyle(.segmented)
            } header: {
                Text(NSLocalizedString("단축어 높이", comment: "Memo cell height"))
            } footer: {
                Text(NSLocalizedString("리스트에서 단축어 카드의 높이를 정해요. 한 화면에 더 많이 보려면 작게, 제목을 크게 보려면 크게로.", comment: "Memo height explanation"))
                    .font(.body)
            }

            // 메모 구분 표시 (마스터 토글)
            Section {
                Toggle(isOn: $visible) {
                    Label(NSLocalizedString("단축어 구분 표시", comment: "Show visual cues toggle"), systemImage: AppSymbol.squareGrid2x2)
                }
            } header: {
                Text(NSLocalizedString("단축어 구분 표시", comment: "Visual cues section"))
            } footer: {
                Text(NSLocalizedString("기본은 심볼·테두리 없이 제목만 깔끔하게 보여요. 이 설정을 켜면 단축어 타입(템플릿·콤보·보안) 아이콘과 심볼, 카드·키보드 칸의 구분 테두리까지 함께 표시돼요.", comment: "Visual cues explanation v3"))
                    .font(.body)
            }

            // 메모 내용 힌트 (카드가 화면에 2초 머물면 한 번 살며시 나타나는 미리보기)
            Section {
                Toggle(isOn: $contentHintEnabled) {
                    Label(NSLocalizedString("단축어 내용 힌트", comment: "Content hint toggle"), systemImage: AppSymbol.sparkles)
                }
            } header: {
                Text(NSLocalizedString("단축어 내용 힌트", comment: "Content hint toggle"))
            } footer: {
                Text(NSLocalizedString("단축어 카드가 화면에 2초쯤 머물면 제목 아래에 내용이 한 번 살며시 나타났다 사라져요. 키보드에서는 제목이 잠시 내용으로 바뀌었다가 돌아와요. 보안 단축어의 내용은 표시되지 않아요.", comment: "Content hint explanation"))
                    .font(.body)
            }
        }
        .navigationTitle(NSLocalizedString("단축어 표시", comment: "Memo display settings entry"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
    }

    /// 실제 메모 그리드 셀(ClipKeyboardList.memoGridCell)과 동일한 모양의 미리보기.
    /// memoCardHeight·visible(심볼 토글)을 그대로 반영해 설정 변화를 즉시 보여준다.
    private func previewCell(title: String, symbol: String, color: Color, plusTemplate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                // 좌상단: 메모 심볼 (+ 템플릿이면 막대기 심볼) - 실제 카드와 동일하게
                // 구분 표시 ON일 때만. 기본(OFF)은 심볼 없이 제목만.
                if visible {
                    Image(systemName: AppSymbol.docFill)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                    if plusTemplate {
                        Image(systemName: AppSymbol.wandAndSparkles)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                Spacer()
                // 우상단: 카테고리 심볼
                if visible {
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            Spacer(minLength: 16)
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: memoCardHeight, alignment: .topLeading)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusXl, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

// MARK: - Memo Time Machine (변경 기록 / 되돌리기)

/// 메모의 최근 변경 스냅샷(최근 10개)을 보여주고, 한 시점으로 되돌릴 수 있는 화면.
struct MemoHistoryView: View {
    @Environment(\.appTheme) private var theme
    @State private var snapshots: [MemoSnapshot] = []
    @State private var pendingRestore: MemoSnapshot?
    @State private var showRestoredToast = false

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = .current
        // 로케일에 맞춰 자동 현지화(월/일 + 시각). 별도 번역 키 불필요.
        f.setLocalizedDateFormatFromTemplate("MMMdjmm")
        return f
    }

    var body: some View {
        List {
            if snapshots.isEmpty {
                Section {
                    Text(NSLocalizedString("아직 저장된 변경 기록이 없어요. 단축어를 추가·편집·삭제하면 직전 상태가 자동으로 여기에 보관돼요 (최근 10개).", comment: "Empty memo history"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
            } else {
                Section {
                    ForEach(snapshots) { snap in
                        Button {
                            pendingRestore = snap
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dateFormatter.string(from: snap.timestamp))
                                        .font(.body)
                                        .foregroundColor(theme.text)
                                    Text(String(format: NSLocalizedString("단축어 %d개", comment: "Snapshot memo count"), snap.memoCount))
                                        .font(.caption)
                                        .foregroundColor(theme.textMuted)
                                }
                                Spacer()
                                Image(systemName: AppSymbol.arrowUturnBackward)
                                    .foregroundColor(theme.accent)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("되돌릴 시점", comment: "Restore points header"))
                } footer: {
                    Text(NSLocalizedString("탭하면 그 시점의 단축어 상태로 되돌려요. 되돌리기 직전 상태도 기록에 남아 다시 되돌릴 수 있어요.", comment: "Memo history footer"))
                        .font(.body)
                }
            }
        }
        .navigationTitle(NSLocalizedString("변경 기록", comment: "Memo change history title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .onAppear { snapshots = MemoStore.shared.loadMemoHistory() }
        .alert(item: $pendingRestore) { snap in
            Alert(
                title: Text(NSLocalizedString("이 시점으로 되돌릴까요?", comment: "Restore confirm title")),
                message: Text(String(format: NSLocalizedString("%@ 시점의 단축어 %d개로 되돌립니다.", comment: "Restore confirm message"), dateFormatter.string(from: snap.timestamp), snap.memoCount)),
                primaryButton: .default(Text(NSLocalizedString("되돌리기", comment: "Restore"))) {
                    if MemoStore.shared.restoreMemoSnapshot(snap.id) {
                        snapshots = MemoStore.shared.loadMemoHistory()
                        withAnimation { showRestoredToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showRestoredToast = false }
                        }
                    }
                },
                secondaryButton: .cancel(Text(NSLocalizedString("취소", comment: "Cancel")))
            )
        }
        .overlay(alignment: .bottom) {
            if showRestoredToast {
                Text(NSLocalizedString("되돌렸어요", comment: "Restored toast"))
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.black.opacity(0.8), in: Capsule())
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Persona Settings (v4.0.8)
/// 설정 → 사용 패턴 진입점. PersonaSelectionView를 settings 모드로 감싸 dismiss 처리.
struct PersonaSettingsContainer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme
    @State private var showAppliedToast = false

    var body: some View {
        PersonaSelectionView(onContinue: {
            showAppliedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                dismiss()
            }
        }, mode: .settings)
        .navigationTitle(NSLocalizedString("페르소나", comment: "Persona setting nav title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
        .overlay(alignment: .bottom) {
            if showAppliedToast {
                Text(NSLocalizedString("페르소나 변경됨", comment: "Persona changed toast"))
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.bottom, 60)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: showAppliedToast) { _, visible in
            if visible {
                UIAccessibility.post(notification: .announcement,
                    argument: NSLocalizedString("페르소나 변경됨", comment: "Persona changed toast"))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showAppliedToast)
    }
}

struct CopyPasteView: View {

    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("📋 붙여넣기 허용 설정", comment: "Paste permission settings title"))
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text(NSLocalizedString("앱 실행 시 '붙여넣기 허용' 팝업이 뜬 경우, 아래 경로로 설정을 변경할 수 있습니다.", comment: "Paste permission settings description"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.vertical, 8)
            }

            Section(header: Text(NSLocalizedString("설정 경로", comment: "Settings path section header"))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.gear)
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("설정", comment: "Settings"))
                            .fontWeight(.medium)
                    }

                    Image(systemName: AppSymbol.chevronDown)
                        .font(.body)
                        .foregroundColor(theme.textFaint)
                        .padding(.leading, 8)
                        .accessibilityHidden(true)

                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.appFill)
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("ClipKeyboard", comment: "ClipKeyboard app name"))
                            .fontWeight(.medium)
                    }

                    Image(systemName: AppSymbol.chevronDown)
                        .font(.body)
                        .foregroundColor(theme.textFaint)
                        .padding(.leading, 8)
                        .accessibilityHidden(true)

                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.docOnClipboard)
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("다른 앱에서 붙여넣기", comment: "Paste from other apps"))
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 8)
            }

            Section(header: Text(NSLocalizedString("옵션 설명", comment: "Options description section header"))) {
                VStack(alignment: .leading, spacing: 16) {
                    // 묻기
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: AppSymbol.questionmarkCircleFill)
                            .foregroundColor(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("묻기", comment: "Ask option"))
                                .font(.headline)
                            Text(NSLocalizedString("복사/붙여넣기 시 매번 팝업이 표시됩니다.", comment: "Ask option description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }

                    Divider()

                    // 거부
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: AppSymbol.xmarkCircleFill)
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("거부", comment: "Deny option"))
                                .font(.headline)
                            Text(NSLocalizedString("자동 붙여넣기가 차단됩니다. 하지만 길게 눌러서 수동으로 붙여넣기는 가능합니다.", comment: "Deny option description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }

                    Divider()

                    // 허용 (권장)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: AppSymbol.checkmarkCircleFill)
                            .foregroundColor(Color.checkGreen)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(NSLocalizedString("허용", comment: "Allow option"))
                                    .font(.headline)
                                Text(NSLocalizedString("(권장)", comment: "Recommended badge"))
                                    .font(.body)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(theme.radiusXs)
                            }
                            Text(NSLocalizedString("팝업 없이 복사한 텍스트를 바로 확인하고 붙여넣을 수 있습니다. 클립보드 자동 분류 기능을 사용하려면 이 옵션을 권장합니다.", comment: "Allow option description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section {
                Button(action: {
                    if let url = URL.init(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }) {
                    HStack {
                        Image(systemName: AppSymbol.gear)
                        Text(NSLocalizedString("설정으로 이동", comment: "Go to Settings button"))
                        Spacer()
                        Image(systemName: AppSymbol.arrowUpForwardApp)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("붙여넣기 알림 허용 끄기", comment: "Paste notification settings title"))
        .navigationBarTitleDisplayMode(.inline)
        .solidNavBar(theme.bg)
    }
}

struct ReviewWriteView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.requestReview) var requestReview
    @Environment(\.appTheme) private var theme
    @State private var showingOptions = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("⭐️ 리뷰 및 평점 매기기", comment: "Review and rating header"))
                        .font(.headline)
                        .padding(.bottom, 4)

                    Text(NSLocalizedString("ClipKeyboard가 마음에 드셨나요? 여러분의 리뷰는 앱을 더 발전시키는 데 큰 도움이 됩니다.", comment: "Review description"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .padding(.vertical, 8)
            }

            Section {
                Button(action: {
                    requestReview()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: AppSymbol.starFill)
                            .foregroundColor(.yellow)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("앱 내에서 리뷰 작성", comment: "In-app review button"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("빠르고 간편하게 리뷰를 남길 수 있습니다 (권장)", comment: "In-app review description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: AppSymbol.chevronRight)
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 4)
                }

                Button(action: {
                    dismiss()
                    if let url = URL(string: Constants.appStoreReviewURL) {
                        #if os(iOS)
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        #elseif os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                }) {
                    HStack {
                        Image(systemName: AppSymbol.link)
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("App Store에서 리뷰 작성", comment: "App Store review button"))
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(NSLocalizedString("App Store 페이지에서 직접 작성합니다", comment: "App Store review description"))
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: AppSymbol.arrowUpForwardApp)
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityHint(NSLocalizedString("App Store 페이지로 이동합니다", comment: "Open App Store hint"))
            } footer: {
                Text(NSLocalizedString("리뷰는 다른 사용자에게 앱을 추천하는 데 도움이 되며, 개발자에게는 큰 힘이 됩니다.", comment: "Review footer message"))
                    .font(.body)
                    .foregroundColor(theme.textMuted)
            }
        }
        .navigationTitle(NSLocalizedString("리뷰 남기기", comment: "Leave review"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
    }
}

struct TutorialView: View {

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Button("Open Web Page") {

            }
            .onAppear(perform: {
                dismiss()

                if let url = URL(string: Constants.tutorialURL) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            })
        }
    }
}

#if canImport(MessageUI)
import MessageUI
import LeeoKit

class EmailController: NSObject, MFMailComposeViewControllerDelegate {
    public static let shared = EmailController()
    private override init() { }

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func sendEmail(subject: String, body: String, to: String) {
        guard MFMailComposeViewController.canSendMail() else {
            print("⚠️ [EmailController.sendEmail] 이 기기는 메일 발송을 지원하지 않음")
            return
        }
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients([to])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(body, isHTML: false)
        EmailController.getRootViewController()?.present(mailComposer, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        EmailController.getRootViewController()?.dismiss(animated: true, completion: nil)
    }

    static func getRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
}
#else
class EmailController: NSObject {
    public static let shared = EmailController()
    private override init() { }
    static var canSendMail: Bool { false }

    func sendEmail(subject: String, body: String, to: String) {}
}
#endif

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}

/// 첫 화면 고르기 - 단축어 탭을 열었을 때 목록을 볼지 키보드 무대를 볼지.
///
/// ⚠️ 두 줄 다 **실물을 짧게 설명**한다. 이름만 두면(목록 / 키보드) 뭐가 달라지는지
///    눌러 보기 전에는 알 수 없고, 첫 화면은 눌러 보고 되돌리기가 번거로운 설정이다.
///    그래서 설정 목록에서는 한 행으로 접되, 고르는 이 화면에서는 설명을 그대로 둔다.
struct FirstScreenSettingsView: View {

    @Environment(\.appTheme) private var theme
    /// ⚠️ 기본값은 목록 - 쓰던 사람의 첫 화면이 업데이트로 바뀌면 안 된다.
    @AppStorage(DefaultsKey.snippetsTabStyle)
    private var snippetsTabStyleRaw: String = SnippetsTabStyle.list.rawValue

    var body: some View {
        List {
            Section {
                ForEach(SnippetsTabStyle.allCases) { candidate in
                    ChoiceRow(name: candidate.localizedName,
                              detail: candidate.localizedDescription,
                              isSelected: snippetsTabStyleRaw == candidate.rawValue,
                              spacing: 12) {
                        Image(systemName: candidate.symbolName)
                            .font(.title3)
                            .foregroundColor(theme.accent)
                            .frame(width: 28)
                    } action: {
                        snippetsTabStyleRaw = candidate.rawValue
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(snippetsTabStyleRaw == candidate.rawValue ? [.isSelected] : [])
                }
            } footer: {
                Text(NSLocalizedString("단축어 탭을 열었을 때 보이는 화면이에요. 어느 쪽을 골라도 저장한 단축어는 그대로예요.",
                                       comment: "First screen section footer"))
            }
        }
        .navigationTitle(NSLocalizedString("첫 화면", comment: "Settings section: first screen"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
    }
}

// MARK: - 키 컬러 고르기

/// **누를 곳을 가리키는 색**을 고르는 자리.
///
/// ⚠️ 견본만 늘어놓지 않는다. 색 동그라미 여섯 개는 예쁘지만, 그걸 고르면 **내 화면이
///    어떻게 되는지**는 안 알려 준다. 그래서 아래에 진짜 카드와 진짜 버튼을 그대로
///    올려 둔다 - 고르는 순간 그 자리에서 바뀐다.
///
/// ⚠️ 고른 값은 App Group 에 저장돼 **키보드 익스텐션·위젯도 같은 색**을 쓴다
///    (`AppAccent.select`). 앱만 바뀌면 같은 앱이 두 색으로 갈린다.
struct KeyColorSettingsView: View {
    @EnvironmentObject private var prefs: AppThemePreference
    @Environment(\.appTheme) private var theme

    /// 동그라미 하나의 지름. 손가락으로 고르는 것이라 44pt 아래로 내리지 않는다.
    private let swatch: CGFloat = 46

    var body: some View {
        List {
            Section {
                swatchRow
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            } header: {
                Text(NSLocalizedString("키 컬러", comment: "Settings: key color"))
            } footer: {
                Text(prefs.accent.localizedNote)
                    .font(.body)
            }

            Section {
                previewCard
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            } header: {
                Text(NSLocalizedString("미리보기", comment: "Preview"))
            } footer: {
                Text(NSLocalizedString("고른 색은 키보드에서도 같이 써요. 갈래(카테고리) 색은 따로예요, 그건 \"무슨 종류인지\"를 말하는 색이라 그대로 둡니다.",
                                       comment: "Key color section footer"))
                    .font(.body)
            }
        }
        .navigationTitle(NSLocalizedString("키 컬러", comment: "Settings: key color"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .solidNavBar(theme.bg)
    }

    // MARK: 고르는 자리

    private var swatchRow: some View {
        HStack(spacing: 12) {
            ForEach(AppAccent.allCases) { candidate in
                swatchButton(candidate)
                if candidate != AppAccent.allCases.last { Spacer(minLength: 0) }
            }
        }
    }

    private func swatchButton(_ candidate: AppAccent) -> some View {
        let selected = prefs.accent == candidate
        let fill = candidate.accent(isDark: theme.isDark)
        return Button {
            guard !selected else { return }
            HapticManager.shared.light()
            withAnimation(.easeInOut(duration: 0.2)) { prefs.accent = candidate }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(fill)
                    .frame(width: swatch, height: swatch)
                    // 먹은 라이트에서 바탕과 붙지 않지만, 다크의 백지는 카드와 붙는다.
                    // 얇은 테두리 하나로 어느 쪽에서든 동그라미가 동그라미로 보인다.
                    .overlay(Circle().strokeBorder(theme.divider, lineWidth: 0.5))
                    .overlay {
                        if selected {
                            Image(systemName: AppSymbol.checkmark)
                                .font(.footnote.weight(.bold))
                                .foregroundColor(candidate.accentFg(isDark: theme.isDark))
                        }
                    }
                    // 고른 것에는 고리를 두른다. 체크만으로는 밝은 색 위에서 잘 안 보인다.
                    .overlay {
                        if selected {
                            Circle()
                                .strokeBorder(fill, lineWidth: 2)
                                .padding(-4)
                        }
                    }
                Text(candidate.localizedName)
                    .font(.caption2)
                    .foregroundColor(selected ? theme.text : theme.textFaint)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidate.localizedName)
        .accessibilityValue(candidate.localizedNote)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: 진짜 화면으로 보여준다

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 단축어 카드 한 장 - 갈래 칩이 키컬러를 쓴다.
            VStack(alignment: .leading, spacing: 5) {
                Text(NSLocalizedString("계좌", comment: "Bank account category name"))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.accentSoft))
                Text(NSLocalizedString("국민 123456-78-901234", comment: "Key color preview: sample snippet"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                Text(NSLocalizedString("어제 · 12번 씀", comment: "Key color preview: sample usage line"))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))

            // 주요 버튼 하나 - 키컬러 위에 글자가 읽히는지가 여기서 보인다.
            Text(NSLocalizedString("단축어 만들기", comment: "Key color preview: sample primary button"))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.accentFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: theme.radiusSm, style: .continuous)
                    .fill(theme.accent))
        }
        .padding(12)
        .background(theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: prefs.accent)
    }
}
