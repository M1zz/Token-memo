//
//  AppearanceSettingsView.swift
//  ClipKeyboard
//
//  설정 > 화면과 표시
//

import SwiftUI
import LeeoKit

/// 화면과 표시 - 눈에 보이는 것을 바꾸는 설정을 한자리에 모은다.
/// 예전에는 "배경 이미지"만 단축어 관리에 떨어져 있어 같은 일을 두 군데서 찾아야 했다.
struct AppearanceSettingsView: View {

    @Environment(\.appTheme) private var theme
    /// 단축어 탭의 첫 화면(목록 / 키보드 무대). 앱 안에서만 쓰므로 표준 UserDefaults.
    /// ⚠️ 기본값은 목록 - 쓰던 사람의 첫 화면이 업데이트로 바뀌면 안 된다.
    @AppStorage(DefaultsKey.snippetsTabStyle)
    private var snippetsTabStyleRaw: String = SnippetsTabStyle.list.rawValue
    /// 날인·봉인 등 입력 반응 마스터 스위치. App Group - 키보드 익스텐션도 같은 값을 읽는다.
    @AppStorage(DefaultsKey.delightEffectsEnabled, store: AppGroup.defaults)
    private var delightEffectsEnabled: Bool = true
    /// 데모 데이터 토글 - 켜면 샘플 페르소나 데이터, 끄면 내 데이터 복원(DemoDataService).
    @AppStorage(DefaultsKey.demoDataActive, store: AppGroup.defaults)
    private var demoDataActive: Bool = false
    /// 마스터(개발자) 모드에서는 데모 토글이 늘 보인다.
    @AppStorage(DefaultsKey.masterModeEnabled) private var masterModeEnabled: Bool = false
    @State private var demoResultMessage: String?

    var body: some View {
        List {
            lookSection
            delightSection
            languageSection
            // ⚠️ 데모는 **맨 아래**다. 예전에는 위에서 두 번째 섹션이라, 매일 쓰는 설정보다
            //    "둘러보기용 가짜 데이터"가 먼저 보였다. 켜 둔 사람이 끌 수 있게 남기되,
            //    자리는 화면을 바꾸는 것들 뒤에 둔다(자주 안 만지는 것은 아래로).
            if showsDemoSection { demoSection }
        }
        .settingsCategoryChrome(title: NSLocalizedString("화면과 표시", comment: "Settings section: appearance"))
        // 데모 데이터 적용 실패 안내 (성공은 화면 변화로 충분해 알리지 않는다).
        .alert(NSLocalizedString("데모 데이터", comment: "Demo data alert title"),
               isPresented: Binding(get: { demoResultMessage != nil },
                                    set: { if !$0 { demoResultMessage = nil } })) {
            Button(NSLocalizedString("확인", comment: "OK"), role: .cancel) { demoResultMessage = nil }
        } message: {
            Text(demoResultMessage ?? "")
        }
    }

    // MARK: - 섹션

    private var lookSection: some View {
        Section {
            firstScreenRow
            // 키 컬러가 이 섹션의 맨 위쪽에 있는 이유: 이 하나가 앱 전체의 인상을 바꾼다.
            // 아래 항목들(높이·배경)은 그다음에 손보는 것들이다.
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
        }
    }

    private var delightSection: some View {
        Section {
            // @AppStorage가 App Group에 직접 쓴다 - Delight.isEnabled / 키보드 익스텐션이 같은 키를 읽는다.
            Toggle(isOn: $delightEffectsEnabled) {
                Label(NSLocalizedString("입력 반응", comment: "Delight effects toggle title"),
                      systemImage: AppSymbol.handTap)
            }
        } footer: {
            Text(NSLocalizedString("입력 반응은 문구를 넣을 때의 진동과 짧은 연출이에요.",
                                   comment: "Appearance section footer"))
                .font(.body)
        }
    }

    private var languageSection: some View {
        Section {
            // 기기 언어와 읽고 싶은 언어가 다른 사람이 있다. iOS 설정까지 가지 않아도
            // 여기서 바로 고르게 한다(자세한 건 AppLanguage 머리말).
            NavigationLink(destination: LanguageSettingsView()) {
                Label(NSLocalizedString("언어", comment: "Settings: app language"),
                      systemImage: "globe")
            }
        }
    }

    // MARK: - 첫 화면

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

    // MARK: - 데모 데이터
    // 앱을 처음 둘러보거나 스크린샷·영상을 찍을 때, 잘 짜인 샘플 한 벌을 즉시 켜고 끌 수 있게 한다.
    // 켤 때 내 데이터는 백업되고 끄면 그대로 복원된다(DemoDataService).

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

    private var demoSection: some View {
        Section {
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
                Text(NSLocalizedString("샘플 단축어와 클립보드 기록을 채워 앱을 바로 체험해 봅니다. 켜는 순간 내 데이터는 안전하게 보관되고, 끄면 그대로 돌아옵니다.", comment: "Demo data section explanation"))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
