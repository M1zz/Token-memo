//
//  AppInfoSettingsView.swift
//  ClipKeyboard
//
//  설정 > 앱 정보
//

import SwiftUI
import LeeoKit

/// 앱 정보 - 읽고 끝나는 것들. Mac 안내가 약관 뒤에 있으면 아무도 못 본다.
///
/// 인앱결제가 있는 앱은 약관·처리방침을 앱 안에서 볼 수 있어야 한다(심사 대비).
/// 처리방침 주소는 App Store Connect 에 등록한 것과 같아야 한다.
struct AppInfoSettingsView: View {

    @Environment(\.appTheme) private var theme
    /// 마스터(개발자) 모드 - 버전 행을 7번 탭하면 토글. 설정 첫 화면에 개발자 섹션이 열린다.
    @AppStorage(DefaultsKey.masterModeEnabled) private var masterModeEnabled: Bool = false
    @State private var versionTapCount = 0
    @State private var showMasterModeAlert = false

    var body: some View {
        List {
            familySection
            legalSection
        }
        .settingsCategoryChrome(title: NSLocalizedString("앱 정보", comment: "App info section"))
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
    }

    // MARK: - 섹션

    /// 같은 사람이 만든 다른 것들.
    private var familySection: some View {
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
            // 같은 사람이 만든 다른 앱. 목록·문구·이야기·아이콘은 LeeoKit 카탈로그 한 곳에 있어서
            // 앱을 새로 내도 여기 코드는 그대로다(LeeoFamilyCatalog).
            LeeoFamilySettingsRow<ClipKeyboardSpec>()
                .leeoStyle(theme.leeoStyle)
        }
    }

    private var legalSection: some View {
        Section {
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
        }
    }

    // MARK: - 버전

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
