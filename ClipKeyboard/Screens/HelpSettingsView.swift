//
//  HelpSettingsView.swift
//  ClipKeyboard
//
//  설정 > 도움말과 문의
//

import SwiftUI
import LeeoKit

/// 도움말과 문의 - 막혔을 때 갈 곳.
/// 예전에는 배우는 길이 셋으로 흩어져 있었다(튜토리얼 다시 하기는 단축어 관리에,
/// 사용 가이드는 도움말에, 활용 사례는 양쪽에).
struct HelpSettingsView: View {

    @Environment(\.appTheme) private var theme
    /// 튜토리얼 다시 하기 확인 - 무엇이 지워지고 무엇이 남는지 먼저 알린다.
    @State private var showTutorialRestartConfirm = false

    var body: some View {
        List {
            learnSection
            contactSection
        }
        .settingsCategoryChrome(title: NSLocalizedString("도움말과 문의", comment: "Settings section: help and contact"))
        .alert(NSLocalizedString("튜토리얼을 다시 할까요?", comment: "Restart tutorial alert title"),
               isPresented: $showTutorialRestartConfirm) {
            Button(NSLocalizedString("다시 하기", comment: "Restart tutorial confirm")) {
                TutorialReset.restartAll()
            }
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("준비된 단축어·템플릿·콤보를 다시 하나씩 눌러보며 안내해요. 목록의 단축어는 그대로 남아요.", comment: "Restart tutorial alert message"))
        }
    }

    // MARK: - 섹션

    /// 스스로 알아보는 길.
    private var learnSection: some View {
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
        }
    }

    /// 만든 사람에게 닿는 길.
    ///
    /// ⚠️ 피드백 보내기·리뷰 남기기는 여기 두지 않는다. 설정 첫 화면에 있다
    ///    (`SettingView.feedbackSection`). 같은 곳으로 가는 문이 둘이면 다른 화면인 줄 안다.
    private var contactSection: some View {
        Section {
            // 개발자 문의: 인스타그램 DM (이메일 문의는 설정 첫 화면의 피드백 보내기에서 처리)
            Link(destination: URL(string: "https://instagram.com/lee25_ios")!) {
                Label(NSLocalizedString("인스타그램 DM (@lee25_ios)", comment: "Instagram DM contact entry"),
                      systemImage: AppSymbol.paperplaneFill)
            }
        }
    }
}
