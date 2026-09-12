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

    @Environment(\.appTheme) private var theme
    @ObservedObject private var proManager = StoreManager.shared
    @State private var showPaywall = false
    /// 지금 가진 단축어 개수 - 화면에 들어올 때와 데이터가 바뀔 때만 다시 센다.
    /// ⚠️ 그릴 때마다 세면 설정을 스크롤하는 내내 저장 파일을 읽는다.
    @State private var memoCountState = 0
    /// 마스터(개발자) 모드 - 앱 정보의 버전 행을 7번 탭하면 토글. 피드백 인박스 진입점 노출.
    @AppStorage(DefaultsKey.masterModeEnabled) private var masterModeEnabled: Bool = false

    private func refreshMemoCount() {
        // 한도와 같은 개수를 센다 - 심어 준 샘플은 칸을 차지하지 않는다.
        memoCountState = ProFeatureManager.ownMemoCount(((try? MemoStore.shared.load(type: .memo)) ?? []))
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
                // 누르면 **지금 누리는 혜택과 그 양**을 본다(ProBenefitsView).
                // 산 사람에게 "활성화됨" 한 줄은 영수증일 뿐이다. 무엇을 얼마나 쓰고 있는지가 보여야 산 값이 보인다.
                NavigationLink(destination: ProBenefitsView()) {
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

    /// 피드백과 리뷰 - 설정 첫 화면의 **맨 아래**, 따로 한 섹션으로 둔다.
    ///
    /// ⚠️ 한때 "도움말과 문의" 안쪽에 있었다. 한 칸 들어가야 보이는 문은 거의 열리지 않는다.
    ///    그래서 첫 화면에 꺼내 두되, 갈래 목록을 다 훑고 난 끝자리에 둔다. 갈래 이름이
    ///    먼저 보여야 설정 화면이 무엇을 하는 곳인지 읽힌다.
    private var feedbackSection: some View {
        Section {
            NavigationLink(destination: FeedbackView()) {
                Label(NSLocalizedString("피드백 보내기", comment: "Send feedback settings entry"),
                      systemImage: AppSymbol.envelopeBadge)
            }
            NavigationLink(destination: ReviewWriteView()) {
                Label(NSLocalizedString("리뷰 남기기", comment: "Leave review"),
                      systemImage: AppSymbol.star)
            }
        }
    }

    // MARK: - 갈래
    //
    // 첫 화면에는 갈래 이름만 세우고, 행은 한 칸 안쪽 화면에 둔다.
    // ⚠️ 예전에는 여섯 섹션의 행 서른 개가 한 화면에 이어져 있었다. 찾는 줄이 어느 섹션에
    //    있는지 모르면 끝까지 내려 봐야 했다. 이름을 보고 들어가는 편이 빠르다.
    //    갈래 화면은 같은 폴더의 `*SettingsView.swift` 에 하나씩 있다.

    /// 매일 손대는 것 - 입력, 단축어, 모양.
    private var everydaySection: some View {
        Section {
            categoryRow(NSLocalizedString("키보드", comment: "Settings section: keyboard"),
                        systemImage: AppSymbol.keyboard) { KeyboardSettingsView() }
            categoryRow(NSLocalizedString("단축어", comment: "Settings section: shortcuts"),
                        systemImage: AppSymbol.textQuote) { ShortcutsSettingsView() }
            categoryRow(NSLocalizedString("화면과 표시", comment: "Settings section: appearance"),
                        systemImage: AppSymbol.paintbrush) { AppearanceSettingsView() }
        }
    }

    /// 가끔 여는 것 - 내 데이터, 도움, 앱에 대한 것.
    private var aboutSection: some View {
        Section {
            categoryRow(NSLocalizedString("내 데이터", comment: "Settings section: my data"),
                        systemImage: AppSymbol.externaldrive) { MyDataSettingsView() }
            categoryRow(NSLocalizedString("도움말과 문의", comment: "Settings section: help and contact"),
                        systemImage: AppSymbol.questionmarkCircle) { HelpSettingsView() }
            categoryRow(NSLocalizedString("앱 정보", comment: "App info section"),
                        systemImage: AppSymbol.infoCircle) { AppInfoSettingsView() }
        }
    }

    private func categoryRow<Destination: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            Label(title, systemImage: systemImage)
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
            everydaySection
            aboutSection
            // 사용자가 보는 설정의 **맨 끝**. 아래 개발자 섹션은 마스터 모드에서만 보인다.
            feedbackSection
            if masterModeEnabled { developerSection }
        }
        // ⚠️ 제목을 안 단다. 탭의 뿌리 화면이고 아래 탭바가 이미 "설정"이라고 적고 있다.
        //    안쪽 화면들(키보드·단축어 표시 …)은 그대로 제목을 단다 - 거기서는
        //    어디까지 들어왔는지를 제목이 말해 준다.
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshMemoCount() }
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
    }
}

// MARK: - 갈래 화면 공통 모양

extension View {
    /// 설정 안쪽 갈래 화면(키보드·단축어 …)이 첫 화면과 같은 바탕·목록 모양을 쓰게 한다.
    /// 한 칸 들어갔을 뿐인데 바탕색이 바뀌면 다른 곳으로 넘어간 것처럼 보인다.
    func settingsCategoryChrome(title: String) -> some View {
        modifier(SettingsCategoryChrome(title: title))
    }
}

struct SettingsCategoryChrome: ViewModifier {
    @Environment(\.appTheme) private var theme
    let title: String

    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectHidden(true, for: .bottom)
            .background(theme.bg.ignoresSafeArea())
            .contentMargins(.bottom, 24, for: .scrollContent)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .solidNavBar(theme.bg)
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
            //
            // ⚠️ 예전에는 작게(110)·보통(140)·크게(180) 세 칸이었다. 세 칸은 고르기는 쉬운데
            //    **그 사이에 있고 싶은 사람**에게 줄 것이 없었다(사용자 요청: 커스텀하게
            //    조절하고 싶다). 위 미리보기가 끄는 대로 즉시 따라오므로, 눈으로 맞추는
            //    편이 이름으로 고르는 것보다 정확하다.
            //
            // ⚠️ 예전 세 값은 이 범위 **안**에 있다. 쓰던 사람의 값이 그대로 살아 있고,
            //    슬라이더가 그 자리에서 시작한다.
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(NSLocalizedString("단축어 높이", comment: "Memo cell height"),
                              systemImage: AppSymbol.arrowUpAndDown)
                        Spacer()
                        Text("\(Int(memoCardHeight))pt").foregroundColor(.secondary)
                    }
                    Slider(value: $memoCardHeight, in: 90...220, step: 2).tint(theme.accent)
                    HStack {
                        Text(NSLocalizedString("작게", comment: "Small")).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(NSLocalizedString("크게", comment: "Large")).font(.caption).foregroundColor(.secondary)
                    }
                }
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
