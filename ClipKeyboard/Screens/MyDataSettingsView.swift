//
//  MyDataSettingsView.swift
//  ClipKeyboard
//
//  설정 > 내 데이터
//

import SwiftUI
import LeeoKit

/// 내 데이터 - 내 것이 어디에 있고 어떻게 지켜지는가.
/// 되돌릴 수 없는 삭제는 반드시 맨 아래, 자기 섹션에 둔다.
struct MyDataSettingsView: View {

    @Environment(\.appTheme) private var theme
    @State private var showPaywall = false
    @State private var securePINSet = false
    /// 기기 간 메모 동기화(실험적) - App Group에 저장해 엔진/맥과 공유.
    @AppStorage(DefaultsKey.memoSyncEnabled, store: AppGroup.defaults)
    private var memoSyncEnabled: Bool = false
    /// 모든 데이터 삭제 - 되돌릴 수 없어 2단계로 확인받는다.
    @State private var showWipeConfirm = false      // 1단계: 무엇이 지워지는지 안내
    @State private var showWipeFinalConfirm = false // 2단계: 마지막 확인
    @State private var wipeResultMessage: String?

    var body: some View {
        List {
            backupSection
            storedSection
            wipeSection
        }
        .settingsCategoryChrome(title: NSLocalizedString("내 데이터", comment: "Settings section: my data"))
        // PIN 화면에서 돌아올 때도 다시 읽는다 - 방금 정한 PIN 이 "없음"으로 남아 보이지 않게.
        .onAppear { refreshSecurePINState() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
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
    }

    private func refreshSecurePINState() {
        let hash = AppGroup.defaults?.string(forKey: DefaultsKey.keyboardSecurePinHash) ?? ""
        securePINSet = !hash.isEmpty
    }

    // MARK: - 섹션

    /// 내 것을 잃지 않게 하는 것들.
    private var backupSection: some View {
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
        }
    }

    /// 기기 안에 담겨 있는 것들.
    private var storedSection: some View {
        Section {
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
        }
    }

    /// 되돌릴 수 없는 작업 - 2단계 확인을 거친다.
    /// 개인정보 처리방침이 약속한 "앱 내에서 데이터 삭제" 경로이기도 하다.
    private var wipeSection: some View {
        Section {
            Button(role: .destructive) {
                showWipeConfirm = true
            } label: {
                Label(NSLocalizedString("모든 데이터 삭제", comment: "Delete all data settings entry"),
                      systemImage: AppSymbol.trash)
            }
        }
    }
}
