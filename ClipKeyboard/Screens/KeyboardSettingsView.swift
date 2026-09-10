//
//  KeyboardSettingsView.swift
//  ClipKeyboard
//
//  설정 > 키보드
//

import SwiftUI
import LeeoKit

/// 키보드 - 키보드로 입력할 때 일어나는 일을 전부 여기로 모은다.
/// 붙여넣기 알림은 예전에 "데이터 & 보안"에 있었지만 보안이 아니라 입력 동작이다.
struct KeyboardSettingsView: View {

    @Environment(\.appTheme) private var theme
    @State private var showKeyboardGuide = false
    /// 키보드에서 빈칸을 채울 때 한 칸만 펼칠지. App Group - 키보드도 같은 값을 읽는다.
    @AppStorage(DefaultsKey.keyboardCompactPlaceholders, store: AppGroup.defaults)
    private var compactPlaceholders: Bool = true

    var body: some View {
        List {
            setupSection
            typingSection
        }
        .settingsCategoryChrome(title: NSLocalizedString("키보드", comment: "Settings section: keyboard"))
        .sheet(isPresented: $showKeyboardGuide) {
            KeyboardSetupOnboardingView { showKeyboardGuide = false }
                .presentationDetents([.large])
        }
    }

    // MARK: - 섹션

    /// 키보드를 붙이고 모양을 잡는 것들.
    private var setupSection: some View {
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
        } header: {
            Text(NSLocalizedString("iOS 설정 > 일반 > 키보드에서 추가할 수 있어요", comment: "Keyboard optional section footer"))
                .textCase(.none)
        }
    }

    /// 키보드로 입력하는 동안 일어나는 일.
    private var typingSection: some View {
        Section {
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
        }
    }
}
