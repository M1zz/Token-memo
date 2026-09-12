//
//  ClipKeyboardApp.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI
import TipKit
import WidgetKit
import LeeoKit

@main
struct ClipKeyboardApp: App {
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showReviewRequest = false
    @State private var showAccessibilityGuide = false
    /// 기존 사용자에게 데모 샘플 체험을 1회 물어보는 알림
    @State private var showDemoSampleOffer = false
    /// 새 기기 첫 실행에서 "기존 메모를 불러올 수 있어요"를 1회 안내
    @State private var showRestoreHint = false
    /// 그거 아세요? - 지금 보여 줄 이야기. **이 값이 곧 시트의 상태다.**
    ///
    /// ⚠️ `isPresented` 로 띄우지 않는다. 켜는 값과 그릴 값이 둘로 나뉘어 있으면,
    ///    SwiftUI 가 시트를 올리는 시점에 그릴 값이 아직 안 들어와 **빈 시트**가 뜬다.
    ///    실제로 그렇게 떴다(하얀 화면 하나가 올라오고 아무것도 안 보였다).
    ///    `item:` 은 값이 있을 때만 올라오므로 그 틈이 생기지 않는다.
    @State private var didYouKnowItem: DidYouKnow?
    /// 안내에서 "불러오기"를 누르면 백업/복원 화면을 시트로 띄운다
    @State private var showCloudBackupSheet = false
    private let restoreHintShownKey = "restoreHintShown_v1"
    /// 업데이트 후 "새로운 기능"(빠른 메모) 시트를 1회 노출
    @State private var showWhatsNew = false
    /// 가끔 "불편한 점 남겨주세요" 피드백 넛지 (10회째 실행 첫 노출, 이후 40회 간격)
    @State private var showFeedbackNudge = false
    /// "카테고리가 많아졌어요" 안내. 값이 있을 때만 뜬다(빈 시트 방지, `didYouKnowItem`과 같은 이유).
    @State private var categoryCleanup: CategoryCleanupRequest?
    /// 저장 파일을 못 읽었을 때 띄우는 복구 안내(전역 폴백).
    /// 조용히 빈 목록을 보여주면 사용자는 "데이터가 날아갔다"고 오해하고,
    /// 그 상태에서 저장하면 실제로 덮어써진다.
    @State private var showDataRecovery = false
    /// 넛지에서 "의견 남기기"를 누르면 피드백 화면을 시트로 띄운다
    @State private var showFeedbackSheet = false
    /// 반값 제안 시트 - 설치 직후·한도 한 칸 앞 두 자리에서 각각 1회 노출한다.
    @State private var showDiscountOffer = false
    /// 지금 띄운 제안이 어느 자리에서 온 것인가(문구·애널리틱스가 이 값을 따라간다).
    @State private var discountOccasion: DiscountOfferManager.Occasion = .limitEdge
    /// 언어를 바꿀 때마다 하나씩 올린다. 이 값이 곧 화면 트리의 `id` 라, 바뀌면 통째로 새로 그려진다.
    @State private var languageRefreshToken = 0

    /// 유닛 테스트 실행 중인지 - `XCTestConfigurationFilePath`는 xcodebuild test로
    /// (XCTest/Swift Testing 모두) 번들을 주입할 때만 설정되고, 프로덕션/TestFlight/
    /// 일반 실행에는 없다. 테스트 중에는 스케줄러·마이그레이션 등 무거운
    /// 런치 작업을 건너뛰어 테스트 러너가 곧바로 연결되게 한다.
    static let isRunningUnitTests: Bool =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// 4.4.4 부터 **새로 시작하는 사람만** 금고 스킨으로 연다.
    ///
    /// ⚠️ 쓰던 사람의 화면은 건드리지 않는다. 업데이트했다는 이유로 남의 카드에 갑자기
    ///    다이얼이 생기고 툴바에 금고가 서 있으면, 고른 적 없는 것이 얹힌 셈이다.
    ///    (`LivingSkin` 파일 머리말의 "기본값은 .none" 원칙과 같은 이유다
    ///     여기서 예외를 두는 건 **첫 화면을 처음 보는 사람**뿐이다.)
    ///
    /// 새 설치를 가리는 표식은 **설치일이 아직 없다**는 사실이다. 설치일은 첫 실행에
    /// 기록되므로, 이 시점에 이미 있으면 지난 버전에서 쓰던 사람이다.
    static func seedDefaultSkinForNewInstalls() {
        let standard = UserDefaults.standard
        // 한 번만 뿌린다. 두 번 뿌리면 사용자가 '없음'으로 바꾼 걸 되돌려 버린다.
        guard !standard.bool(forKey: DefaultsKey.skinSeededV444) else { return }
        standard.set(true, forKey: DefaultsKey.skinSeededV444)

        // **새 설치인가**를 가르는 표식은 실행 횟수다.
        //
        // ⚠️ 예전에는 설치일(`app_install_date`)이 비어 있는지로 봤는데, 그 값은 이 시점보다
        //    **먼저 쓰일 수 있다**(ReviewManager 등이 다른 경로로 깨어나면 자기가 찍는다).
        //    그러면 방금 지우고 깐 사람이 '기존 사용자'로 판정돼 튜토리얼이 통째로 사라진다.
        //    실행 횟수는 이 아래 `incrementAppLaunchCount()` 한 곳에서만 오르므로,
        //    **이 시점에 0이면 이번이 첫 실행**이라는 뜻이 흔들리지 않는다.
        guard standard.integer(forKey: DefaultsKey.appLaunchCount) == 0 else {
            print("🎨 [APP INIT] 기존 사용자, 스킨·샘플·첫 화면 그대로 둠")
            return
        }

        // 이 기기가 4.4.4 에서 처음 시작했다는 사실을 남긴다.
        // 스킨 기본값과 튜토리얼이 **같은 판단**을 근거로 움직여야 서로 어긋나지 않는다.
        standard.set(true, forKey: DefaultsKey.startedFreshV444)

        // 처음 쓰는 사람은 **키보드가 쓰이는 장면**부터 본다 - 이 앱의 값어치가 거기 있다.
        // ⚠️ 쓰던 사람에게는 뿌리지 않는다. 값이 없으면 목록이고, 그쪽에는 1회 제안이 따로 간다
        //    (SnippetsTab.offerKeyboardStageIfNeeded).
        standard.set(SnippetsTabStyle.keyboard.rawValue, forKey: DefaultsKey.snippetsTabStyle)
        // 이미 무대로 시작하므로 다시 권할 일이 없다.
        standard.set(true, forKey: DefaultsKey.keyboardStageOffered)
        print("🎬 [APP INIT] 새 설치, 키보드 화면으로 시작")

        // 생활 레이어가 꺼져 있는 동안에는 아무것도 뿌리지 않는다 - 고를 수 없는 것을
        // 미리 켜 두면 나중에 되살렸을 때 "고른 적 없는 것"이 이미 얹혀 있게 된다.
        guard LivingSkin.isEnabled else { return }

        guard let group = AppGroup.defaults,
              group.string(forKey: DefaultsKey.livingSkin) == nil else { return }

        group.set(LivingSkin.vault.rawValue, forKey: DefaultsKey.livingSkin)
        print("🎨 [APP INIT] 새 설치, 금고 스킨으로 시작")
    }

    /// ⚠️ **여기에는 "앱이 뜨기 전에 반드시 끝나야 하는 것"만 둔다.**
    ///
    /// 이 함수는 `didFinishLaunching` 안에서 돌기 때문에, 여기서 오래 붙잡으면 워치독이
    /// 앱을 죽이고(0x8badf00d) 그 기록은 크래시로 남는다. 여기서 죽으면 사용자는 화면을
    /// 한 장도 못 본다. 그래서 통계·CloudKit·진단처럼 **화면을 띄우는 일과 무관한 것들은
    /// 전부 첫 화면 뒤로 옮겼다** (`runLaunchSequence`).
    ///
    /// 남길 이유가 있는 것만 남았다.
    ///  - 새 설치 씨앗: 첫 화면이 무엇인지를 정하므로 화면보다 먼저여야 한다.
    ///  - 콤보 마이그레이션: 다른 어떤 load/save 보다 먼저여야 레거시 키가 살아 있다.
    ///  - 백그라운드 작업 등록: iOS 가 런치 사이클 안에서만 받아 준다(늦으면 등록 자체가 무시된다).
    init() {
        if ClipKeyboardApp.isRunningUnitTests {
            print("🧪 [APP INIT] 유닛 테스트 모드, 무거운 초기화 스킵")
            return
        }

        // ⚠️ 화면에 글자가 하나라도 나가기 **전에** 언어를 세운다. 늦으면 첫 화면만
        //    기기 언어로 그려졌다가 뒤늦게 바뀌는 깜빡임이 생긴다.
        AppLanguage.applyStored()

        // 직전 런치가 끝까지 갔는지 판정한다. 못 갔으면 이번 런치는 세이프 모드로 열린다.
        LaunchGuard.begin()

        // ⚠️ **다른 어떤 초기화보다 먼저.** 설치일(app_install_date)이 아직 없다는 사실로
        //    새 설치를 가려내는데, ReviewManager 가 한 번이라도 먼저 깨어나면 그 값을 써 버려서
        //    기존 사용자와 구분이 안 된다.
        LaunchGuard.essential(.seed) {
            ClipKeyboardApp.seedDefaultSkinForNewInstalls()
        }

        print("🚀 [APP INIT] ClipKeyboardApp 초기화 시작")

        // 콤보/attached 데이터 모델 통합 마이그레이션 - 다른 어떤 load/save보다 먼저 실행해
        // 레거시 키(isStack/stackValues/attachedTemplateId)가 신 모델 재저장으로 사라지기 전에 변환.
        LaunchGuard.essential(.comboMigration) {
            migrateComboModelIfNeeded()
        }

        #if DEBUG
        // 배경 발행 잡기 - 원인을 찾으면 지운다(`OffMainPublishDetector`).
        OffMainPublishDetector.watchKnownStores()
        #endif

        // 익명 사용 통계 → 공용 허브(FeedbackHub). 이벤트 훅을 먼저 꽂아야 이후 로그가 전달된다.
        // (클로저 대입뿐이라 여기서 죽을 일이 없다. 실제 전송은 첫 화면 뒤로 미룬다)
        AnalyticsService.eventSink = { UsageReportingService.record(event: $0) }

        // 백그라운드 새로고침 task 등록 - 메인 앱이 안 열려도 주기적으로 비콘 flush
        // (키보드만 쓰는 유저의 DAU 추적용)
        // ⚠️ 이것만은 미룰 수 없다. iOS 는 런치 사이클 안에서 등록한 핸들러만 인정한다.
        LaunchGuard.optional(.backgroundTask) {
            BeaconBackgroundScheduler.registerAndScheduleIfNeeded()
        }
        // 등록을 건너뛴 런치에서는 예약도 걷어낸다 - 핸들러 없는 작업으로 깨어나면
        // 그 백그라운드 런치는 그대로 종료 처리된다.
        if LaunchGuard.isSafeMode {
            BeaconBackgroundScheduler.cancelAll()
        }

        // 앱 실행 횟수 증가
        ReviewManager.shared.incrementAppLaunchCount()

        // TipKit 설정 - 온보딩 대신 상황에 맞는 팁으로 안내
        //
        // ⚠️ **한 번에 하나만 뜬다.** 빈도를 안 정하면 기본이 `.immediate` 라,
        //    조건을 만족한 팁이 전부 한꺼번에 뜬다(팁은 7개다). 화면 여기저기서
        //    동시에 말을 걸면 하나도 안 읽힌다.
        //    `.daily` 는 **앱 전체에서** 하루 한 개로 끊는다. 팁마다 거는 규칙이 아니라
        //    TipKit 이 들고 있는 전역 문지기라, 새 팁을 늘려도 저절로 지켜진다.
        //
        //    빠르게 하려면 `.hourly` 한 단어만 바꾸면 된다. 다만 이 앱의 팁들은
        //    서로 순서가 있어(탭 → 저장 → 키보드) 하루 간격이 흐름과 맞는다.
        LaunchGuard.optional(.tips) {
            try? Tips.configure([
                .displayFrequency(.daily),
                .datastoreLocation(.applicationDefault)
            ])
        }

        #if targetEnvironment(macCatalyst)
        setupMacCatalystCommands()
        #endif

        // 여기서부터 SwiftUI 가 `body` 를 처음 평가한다 - 워치독의 `scene-create` 창이다.
        // 이 표식이 없으면 첫 화면을 그리다 죽은 사고가 직전 단계(`tips`) 것으로 기록된다.
        LaunchGuard.markFirstFrame()
    }

    // MARK: - 첫 화면 뒤에 하는 일

    /// 화면이 뜬 **다음에** 도는 런치 작업 전부.
    ///
    /// 여기 있는 것들은 하나도 첫 화면을 그리는 데 필요하지 않다. 그래서 늦게 해도 되고,
    /// 늦게 해야 한다 - 런치를 붙잡으면 워치독에 걸리고, 여기서 죽으면 사용자는 이미
    /// 자기 단축어를 보고 있는 상태다.
    ///
    /// 단계는 두 종류다.
    ///  - `essential`: 데이터 무결성에 필요 - 세이프 모드에서도 돈다.
    ///  - `optional`: 없어도 앱이 돈다 - 직전 런치가 못 끝났으면 통째로 쉰다.
    ///    (되풀이해서 같은 단계가 멈추면 `LaunchGuard` 가 그 단계를 이 버전 동안 격리한다)
    @MainActor
    private func runLaunchSequence() async {
        // 첫 프레임을 먼저 내보낸다. 아래 일들이 메인 스레드를 쓰긴 하지만, 그때는 이미
        // 화면이 떠 있어서 "런치가 안 끝난 앱"으로 죽지 않는다.
        await Task.yield()

        // ① 데이터 - 세이프 모드에서도 돈다.
        //    샘플 삽입 전에 "이 기기에 원래 내 메모가 있었는지"를 먼저 본다.
        //    (없으면 새 기기일 가능성 → 백업 복원 안내 대상)
        var localWasEmpty = false
        LaunchGuard.essential(.dataMigrations) {
            localWasEmpty = ((try? MemoStore.shared.load(type: .memo)) ?? []).isEmpty

            // 위 load 과정에서 파일 손상이 감지됐다면 복구 안내를 먼저 띄운다.
            // ⚠️ 다른 안내(샘플 제안·복원 힌트)보다 우선한다 - 이 상태에서 샘플을
            //    넣으면 읽지 못한 파일을 덮어쓸 수 있다.
            if MemoStore.hasDetectedCorruption {
                showDataRecovery = true
            }

            migrateComboModelIfNeeded()
            migrateVisualCuesIfNeeded()
            migrateKoreanEnabledIfNeeded()
            migrateSecureMemoEncryptionIfNeeded()
            insertDefaultSamplesIfNeeded()
            migrateSampleTemplateFlagsIfNeeded()
        }

        // ② 결제 권한 - 세이프 모드에서도 돈다. 여기를 쉬면 산 사람이 Pro 를 잃는다.
        LaunchGuard.essential(.entitlement) {
            // 심어 준 샘플의 id 를 App Group 으로 옮긴다. 한도가 자기 것만 세는 일이
            // 이 표에 달려 있어서, 한도를 묻기 **전에** 옮겨야 한다.
            SampleMemoStorage.migrateToAppGroupIfNeeded()

            // v4.0 그랜드파더 플래그 초기화 (최초 1회만 효과 있음, 이후는 no-op)
            bootstrapV4GrandfatherFlags()

            // TestFlight 여부 비동기 감지 - isPro 체크 전에 완료되도록 최우선 실행
            Task { await ProFeatureManager.bootstrapIsTestFlight() }

            // v4.0 이전 유료 앱 구매자 그랜드파더 (AppTransaction 영수증 기반).
            // bootstrap_done 1회 가드와 무관하게 매 실행 검증 → 이미 업데이트 후 Pro를 잃은
            // 기존 구매자도 다음 실행에서 자동 복구된다. (이미 부여됐으면 즉시 no-op)
            Task { await ProFeatureManager.grandfatherPaidUserIfNeeded() }

            // DEBUG 빌드에서만 계정/구매 상태 진단 덤프 (Xcode 콘솔에서 "🩺 [Diag]"로 검색)
            #if DEBUG
            Task {
                // TestFlight 감지·그랜드파더 검증이 먼저 끝나도록 잠깐 양보
                await ProFeatureManager.bootstrapIsTestFlight()
                await ProFeatureManager.grandfatherPaidUserIfNeeded()
                await StoreManager.shared.logAccountDiagnostics()
            }
            #endif
        }

        // ③ 익명 사용 통계.
        LaunchGuard.optional(.analytics) {
            // 직전 런치가 멈췄다면 그 단계 이름을 여기서 한 번 보낸다.
            // 재현 안 되는 런치 크래시를 남의 기기에서 알아내는 유일한 통로다.
            LaunchGuard.reportStallIfNeeded()

            // 키보드 익스텐션이 App Group에 기록한 사용 비콘을 flush (콘솔 + 허브 이벤트)
            AnalyticsService.flushKeyboardBeacon()

            // 세그먼트 유저 속성 - 모든 퍼널을 Pro 여부·페르소나·키보드 활성으로 쪼갤 수 있게.
            let keyboardActive = (AppGroup.defaults?
                .double(forKey: DefaultsKey.kbBeaconLastUse) ?? 0) > 0
            AnalyticsService.applyLaunchUserProperties(
                isPro: ProFeatureManager.hasFullAccess,
                persona: CategoryStore.shared.selectedPersona?.rawValue,
                keyboardActive: keyboardActive
            )

            // 설치 스냅샷(사용자 수·활성·앱 지표) 갱신 - 12시간 쓰로틀. 끄는 설정은 없다(항상 수집).
            UsageReportingService.reportProcessStart()

            // 콜드 런치 - scenePhase 변화만 믿으면 이미 .active 인 채로 첫 화면이
            // 뜬 경우를 놓친다. 양쪽에서 불러도 실행 횟수는 프로세스당 1회,
            // app_open 은 20시간 쓰로틀이라 중복으로 세지 않는다.
            reportForegroundActivity()

            // 오래된 월 원장·일별 키 정리 - 하루 한 번만 실제로 돈다.
            // ⚠️ 반드시 **앱에서만**. 전체 사전을 훑는 일이라 키보드 익스텐션의 입력 경로에 두면
            //    메모리 상한(약 60MB) 안에서 매 입력마다 값을 치르게 된다.
            RefundLedger.pruneIfNeeded()
        }

        // ④ 원격 기능 플래그 갱신(6시간 쓰로틀, 실패해도 무시) - 문제 기능을 심사 없이 끄기 위한 장치.
        //    이번 실행은 캐시된 값으로 동작하고, 여기서 받은 값은 다음 실행부터 반영된다.
        LaunchGuard.optional(.remoteFlags) {
            RemoteFlagsService.shared.refreshInBackground()
        }

        // ④-b 시스템 키보드 높이 재기 - 알림 구독 하나가 전부다.
        //     **우리 키보드가 시스템 키보드와 같은 높이로 서는 유일한 길이다.** 익스텐션에는
        //     시스템 키보드 높이를 물어볼 API 가 없어서, 앱이 대신 재서 App Group 에 적어 둔다.
        //     (자세한 이유: ClipKeyboard/Service/KeyboardHeightBook.swift)
        LaunchGuard.optional(.keyboardHeight) {
            KeyboardHeightBook.startWatching()
        }

        // ⑤ 크래시·행 진단 구독(MetricKit) - 구독만 하고 즉시 반환한다.
        //    페이로드는 iOS가 하루 한 번꼴로 묶어서 준다(실시간 아님).
        LaunchGuard.optional(.diagnostics) {
            DiagnosticsService.shared.start()
        }

        // ⑥ 자동 백업 서비스를 런치 시 초기화한다.
        //    (기존엔 iCloud 백업 화면을 열 때만 생성돼, 화면을 안 본 사용자는
        //     데이터 변경 리스너·타이머·시작 백업이 전혀 안 돌아 "마지막 백업"이 멈춰 있었다.)
        //    .shared 접근만으로 계정확인·자동백업 타이머·변경 리스너·시작 백업이 시작된다.
        //    ⚠️ 시뮬레이터에서는 통째로 건너뛰는 경로다(CloudKitBackupService 참고).
        //       즉 **실기기에서만 도는 코드**라 개발 중에는 한 번도 안 밟힌다.
        LaunchGuard.optional(.cloudBackup) {
            _ = CloudKitBackupService.shared
        }

        // ⑦ 메모 실시간 동기화 시작(Pro + 플래그 ON일 때만). 시작 시 원격을 당겨온다.
        //    시작 전에 실제 접근 권한을 공유 키에 미러링한다 - 안 하면 그랜드파더/TestFlight
        //    사용자는 토글이 켜져 있어도 엔진이 "not Pro"로 거부한다.
        LaunchGuard.optional(.sync) {
            ProFeatureManager.mirrorSyncEntitlement()
            MemoSyncEngine.shared.startIfEnabled()
        }

        // ⑧ 제어센터 컨트롤 재등록 - 업데이트로 인텐트 타입이 바뀌어도
        //    이미 추가된 컨트롤이 죽은 채 남지 않게 런치마다 갱신한다.
        LaunchGuard.optional(.controls) {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadAllControls()
            }
            #endif
        }

        // ⑨ 런치 직후 안내·제안.
        LaunchGuard.optional(.prompts) {
            offerDemoSamplesToExistingUserIfNeeded()
            offerRestoreHintIfNeeded(localWasEmpty: localWasEmpty)

            // 마스터 모드(개발자): 새 피드백 푸시 구독을 위해 APNs 재등록.
            // 프롬프트 없이 조용히 동작 - 알림 권한은 인박스 토글에서 요청한다.
            if UserDefaults.standard.bool(forKey: DefaultsKey.masterModeEnabled) {
                UIApplication.shared.registerForRemoteNotifications()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // 데모 체험 질문이 떠 있으면 리뷰 요청은 양보 (모달 중첩 방지)
                if !showDemoSampleOffer, ReviewManager.shared.shouldShowReview() {
                    showReviewRequest = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                checkVoiceOverAndNudge()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                maybeShowWhatsNew()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                maybeShowFeedbackNudge()
            }

            // 카테고리 정리 안내 - 앞의 안내들에게 자리를 내주고 조용히 한 번만 묻는다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                maybeOfferCategoryCleanup()
            }

            // 반값 제안은 맨 뒤에 - 앞의 안내들이 자리를 잡고 난 다음에야 물어본다.
            // (상품 로드가 늦을 수 있어 3초를 준다. 못 받으면 다음 실행에 다시 본다)
            noteShortcutCountForDiscountOffer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                maybeShowDiscountOffer()
            }

            // ⚠️ **정말 맨 마지막.** 이건 급한 이야기가 아니라서 앞의 것들에게 자리를
            //    다 내주고 남으면 한다. 다른 안내가 떠 있으면 조용히 접고 다음 실행을
            //    기다린다(`markShown` 을 부르지 않으므로 그 이야기는 없어지지 않는다).
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                maybeShowDidYouKnow()
            }
        }

        // ⚠️ 마지막 안내가 뜨는 자리(3.5초)까지 지켜본 뒤에 런치를 닫는다.
        //    시트가 올라오다 죽는 것도 사용자에게는 똑같은 "런치 크래시"라, 그 구간을
        //    빵부스러기 밖에 두면 정작 알고 싶은 사고를 못 잡는다.
        try? await Task.sleep(for: .seconds(4))
        LaunchGuard.finish()
    }

    /// v3.x → v4.0 업그레이드 유저에게 그랜드파더 상태를 부여한다.
    /// - Pro 구매 이력 있으면 영구 unlock
    /// - 메모를 하나라도 보유했다면 기존 무료 유저로 기록 (키보드 익스텐션 접근 유지)
    /// - 메모가 새 freeMemoLimit 초과면 grace 플래그
    private func bootstrapV4GrandfatherFlags() {
        // 이미 한 번 초기화됐으면 skip
        let defaults = AppGroup.defaults
        let initKey = DefaultsKey.v4GrandfatherBootstrapDone
        if defaults?.bool(forKey: initKey) == true { return }

        let currentMemoCount: Int
        if let memos = try? MemoStore.shared.load(type: .memo) {
            currentMemoCount = memos.count
        } else {
            currentMemoCount = 0
        }

        ProStatusManager.shared.bootstrapV4GrandfatherFlags(
            existingMemoCount: currentMemoCount,
            isProNow: ProFeatureManager.isPro
        )

        defaults?.set(true, forKey: initKey)
        print("✅ [APP INIT] v4.0 그랜드파더 부트스트랩 완료 (memos=\(currentMemoCount), isPro=\(ProFeatureManager.isPro))")
    }

    // MARK: - What's New (업데이트 1회 안내)

    /// 업데이트한 기존 사용자에게 "새로운 기능" 시트를 1회 노출한다.
    /// - 신규 설치(첫 실행)는 새 기능이 아니므로 노출하지 않고 본 것으로 표시만 한다.
    /// - 데이터성 알림(복원/데모)·리뷰 요청이 떠 있으면 양보한다(모달 중첩 방지).
    private func maybeShowWhatsNew() {
        guard !ClipKeyboardApp.isRunningUnitTests else { return }
        let defaults = UserDefaults.standard
        let current = WhatsNewContent.version

        // 처음 온 사람인지 쓰던 사람인지는 **한 곳**에서 가른다(`LaunchAudience`).
        // 여기서 따로 판단하면 온보딩과 어긋나, 처음 온 사람이 "새로워졌어요"를 보게 된다.
        let audience = LaunchAudience.resolve(
            launchCount: defaults.integer(forKey: DefaultsKey.appLaunchCount),
            startedFresh: defaults.bool(forKey: DefaultsKey.startedFreshV444),
            lastSeenWhatsNewVersion: defaults.string(forKey: DefaultsKey.lastSeenWhatsNewVersion),
            currentWhatsNewVersion: current)

        if audience.marksWhatsNewSeenSilently {
            defaults.set(current, forKey: DefaultsKey.lastSeenWhatsNewVersion)
            print("🎉 [WhatsNew] 처음 온 사람 - 안내 대신 온보딩이 맞이한다")
            return
        }
        guard audience.showsWhatsNew else { return }
        // 데이터성 알림·리뷰 요청이 떠 있으면 양보한다(모달 중첩 방지). 다음 실행에 다시 온다.
        guard !showDemoSampleOffer, !showRestoreHint, !showReviewRequest, !showWhatsNew else { return }

        defaults.set(current, forKey: DefaultsKey.lastSeenWhatsNewVersion)
        showWhatsNew = true
        print("🎉 [WhatsNew] 쓰던 사람에게 \(current) 새 단장 안내")
    }

    // MARK: - Feedback Nudge (가끔 의견 요청)

    /// 사용자에게 가끔 "불편한 점/필요한 기능을 남겨주세요"를 묻는다.
    /// - 10회째 실행에서 처음, 이후 40회 실행 간격으로 노출
    /// - "다시 보지 않기"를 누르면 6개월 유예 후 다시 노출 대상이 된다(영구 아님)
    /// - 다른 모달(리뷰 요청·What's New 등)이 떠 있으면 양보한다
    // MARK: - 그거 아세요?

    /// 이 앱의 좋은 점은 대부분 **안 보이는 곳**에 있다. 서버가 없다는 것, 설정 어딘가의
    /// 기능들, 길게 누르면 되는 동작들. 화면에 안 나오는 것은 아무리 좋아도 없는 것과 같다.
    ///
    /// ⚠️ 언제 말을 걸지는 `DidYouKnowScheduler` 가 혼자 판단한다(첫날 침묵 · 사흘 간격 ·
    ///    다 하면 멈춤). 여기서는 **다른 안내가 떠 있지 않은지**만 본다 - 모달이 모달 위에
    ///    얹히는 것이 이 화면들에서 가장 나쁜 일이다.
    private func maybeShowDidYouKnow() {
        guard !ClipKeyboardApp.isRunningUnitTests, noOtherModalIsUp else { return }
        // 처음 오는 길을 지나는 중이면 말하지 않는다 - 온보딩 위에 얹히면 둘 다 안 읽힌다.
        let d = UserDefaults.standard
        let stillOnboarding = d.bool(forKey: DefaultsKey.startedFreshV444)
            && !d.bool(forKey: DefaultsKey.tutorialMakeOwnDone)
        guard let item = DidYouKnowScheduler.candidate(
            onboardingFinished: !stillOnboarding,
            installedAt: d.object(forKey: DefaultsKey.appInstallDate) as? Date) else { return }

        DidYouKnowScheduler.markShown(item)
        didYouKnowItem = item
        print("💡 [DidYouKnow] \(item.id)")
    }

    /// 읽고 나서 갈 곳으로 데려간다.
    ///
    /// ⚠️ **읽고 닫으면 아무것도 안 달라진다.** "설정에서 켤 수 있어요"를 읽은 사람이
    ///    설정을 스스로 찾아 들어가는 일은 드물다. 알려 준 그 자리로 직접 데려간다.
    private func handleDidYouKnowAction(_ action: DidYouKnow.Action) {
        didYouKnowItem = nil
        // 시트가 내려간 뒤에 다음 화면을 연다 - 겹치면 둘 다 제대로 안 뜬다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            switch action {
            case .openSettings:
                NotificationCenter.postOnMain(name: .showSettings, object: nil)
            case .openStage:
                NotificationCenter.postOnMain(name: .showMemoList, object: nil)
            case .openBackup:
                showCloudBackupSheet = true
            case .openList:
                NotificationCenter.postOnMain(name: .showMemoList, object: nil)
            case .openQuickNoteInbox:
                NotificationCenter.postOnMain(name: .openQuickNoteInbox, object: nil)
            case .openBulkImport:
                NotificationCenter.postOnMain(name: .showMemoList, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.postOnMain(name: .openBulkImport, object: nil)
                }
            case .openShortcutMart:
                // 목록으로 먼저 보내고 마트를 연다 - 마트는 목록이 들고 있는 시트다.
                NotificationCenter.postOnMain(name: .showMemoList, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.postOnMain(name: .openShortcutMart, object: nil)
                }
            }
        }
    }

    private func maybeShowFeedbackNudge() {
        guard !ClipKeyboardApp.isRunningUnitTests else { return }
        let defaults = UserDefaults.standard

        // 구버전 영구 옵트아웃(Bool) 마이그레이션 - 지금부터 6개월 유예로 전환.
        if defaults.bool(forKey: DefaultsKey.feedbackNudgeOptOut) {
            defaults.set(Date().timeIntervalSince1970, forKey: DefaultsKey.feedbackNudgeOptOutDate)
            defaults.removeObject(forKey: DefaultsKey.feedbackNudgeOptOut)
            return
        }
        // "다시 보지 않기" 유예: 6개월 안 지났으면 침묵, 지났으면 해제하고 다시 노출 대상.
        let optOutAt = defaults.double(forKey: DefaultsKey.feedbackNudgeOptOutDate)
        if optOutAt > 0 {
            let sixMonths: TimeInterval = 60 * 60 * 24 * 182
            guard Date().timeIntervalSince1970 - optOutAt >= sixMonths else { return }
            defaults.removeObject(forKey: DefaultsKey.feedbackNudgeOptOutDate)
        }

        let launchCount = defaults.integer(forKey: DefaultsKey.appLaunchCount)
        let lastShown = defaults.integer(forKey: DefaultsKey.feedbackNudgeLastShownLaunch)
        let due = (lastShown == 0 && launchCount >= 10)
            || (lastShown > 0 && launchCount - lastShown >= 40)
        guard due else { return }
        guard !showDemoSampleOffer, !showRestoreHint, !showReviewRequest,
              !showWhatsNew, !showFeedbackNudge else { return }

        defaults.set(launchCount, forKey: DefaultsKey.feedbackNudgeLastShownLaunch)
        showFeedbackNudge = true
    }

    /// 카테고리 정리 안내에 넘길 것. 세어 둔 결과를 그대로 들고 간다
    /// (시트가 뜬 뒤 다시 세면 화면이 한 번 더 흔들린다).
    struct CategoryCleanupRequest: Identifiable {
        let id = UUID()
        let categories: [String]
        let empty: [String]
    }

    /// 카테고리가 너무 늘었으면 한 번 물어본다.
    ///
    /// ⚠️ **앱이 지우지 않는다.** 어느 것이 사용자가 만든 것이고 어느 것이 동기화 사고로
    ///    불어난 것인지 앱은 구분할 수 없다. 보여 주고 정리할 자리로 데려다주는 데까지가
    ///    앱의 몫이다. 자세한 사연: ClipKeyboard/Screens/CategoryCleanupNotice.swift
    private func maybeOfferCategoryCleanup() {
        // 다른 안내가 떠 있으면 양보한다. 급한 이야기가 아니다.
        guard !showDemoSampleOffer, !showRestoreHint, !showReviewRequest,
              !showWhatsNew, !showFeedbackNudge, !showDataRecovery,
              !showDiscountOffer, categoryCleanup == nil else { return }

        // 개수부터 본다. 여기서 걸리면 단축어를 읽지 않는다(런치 뒤라도 공짜는 아니다).
        let categories = CategoryStore.shared.categories
        guard categories.count >= 12 else { return }

        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        let empty = CategoryCleanupNudge.emptyCategories(categories, memos: memos)
        guard CategoryCleanupNudge.shouldAsk(categoryCount: categories.count,
                                             emptyCount: empty.count) else { return }

        CategoryCleanupNudge.markAsked(categoryCount: categories.count)
        categoryCleanup = CategoryCleanupRequest(categories: categories, empty: empty)
    }

    // MARK: - 반값 제안 (한도 한 칸 앞에서 일주일)

    /// 지금 단축어가 몇 개인지 세어 "한 칸 앞에 닿은 시각"을 기록한다.
    /// (판정과 저장은 `DiscountOfferManager` 가 한다 - 여기서는 개수만 넘긴다)
    private func noteShortcutCountForDiscountOffer() {
        // 한도와 같은 개수를 센다. 전체를 세면 자기 걸 5개 만든 사람에게
        // "한 칸 남았다" 며 할인이 나간다.
        let count = ProFeatureManager.ownMemoCount(((try? MemoStore.shared.load(type: .memo)) ?? []))
        DiscountOfferManager.noteShortcutCount(count)
    }

    /// 조건이 다 맞으면 반값 제안을 띄운다. 기회는 둘뿐이고 각각 한 번씩이다.
    ///
    /// ⚠️ 상품이 아직 안 왔으면 그냥 넘어간다 - **다음 실행에 다시 물어본다.** 여기서
    ///    본 것으로 표시해 버리면, 네트워크가 느렸다는 이유만으로 제안을 영영 잃는다.
    private func maybeShowDiscountOffer() {
        guard !ClipKeyboardApp.isRunningUnitTests else { return }
        guard noOtherModalIsUp else { return }
        // 때가 됐는지부터 본다 - 아닌 사람에게 스토어를 두드리지 않기 위해서다.
        guard DiscountOfferManager.isDueIgnoringProduct(isMidFirstShortcut: isMidFirstShortcut) else { return }

        Task { @MainActor in
            // ⚠️ 상품을 **여기서** 부른다. 이 앱은 런치에 상품을 미리 읽지 않아서
            //    (페이월 화면이 필요할 때 읽는다) 미리 확인하면 언제나 "없음"이 된다.
            if storeManager.discountedProProduct == nil {
                await storeManager.loadProducts()
            }
            // 상품이 온 뒤에 다시 판정한다 - 기다리는 동안 조건이 바뀌었을 수 있다.
            guard let occasion = DiscountOfferManager.dueOccasionNow(
                discountAvailable: storeManager.discountedProProduct != nil,
                isMidFirstShortcut: isMidFirstShortcut
            ) else {
                print("ℹ️ [DiscountOffer] 지금은 띄우지 않는다(상품 없음이면 다음 실행에 다시 본다)")
                return
            }
            // 기다리는 동안 다른 안내가 떴을 수 있다.
            guard noOtherModalIsUp else { return }

            // 여는 그 자리에서 못박는다 - 어떻게 닫든 그 기회는 다시 오지 않는다.
            DiscountOfferManager.markShown(occasion)
            discountOccasion = occasion
            showDiscountOffer = true
        }
    }

    /// 튜토리얼의 환영 화면을 아직 지나지 않았는가.
    /// ⚠️ 이때는 튜토리얼이 화면을 잡고 있다. 그 위에 결제 창을 얹으면 처음 쓰는 사람이
    ///    무엇을 하라는 건지 보기도 전에 값부터 보게 된다.
    private var isMidFirstShortcut: Bool {
        let d = UserDefaults.standard
        return d.bool(forKey: DefaultsKey.startedFreshV444)
            && !d.bool(forKey: DefaultsKey.tutorialWelcomeDone)
    }

    /// 지금 화면에 다른 안내가 떠 있지 않은가 - 모달이 모달 위에 얹히는 것을 막는다.
    /// (결제 창이 남의 위에 올라타면 가장 나쁘다)
    private var noOtherModalIsUp: Bool {
        !showDemoSampleOffer && !showRestoreHint && !showReviewRequest
            && !showWhatsNew && !showFeedbackNudge && !showDataRecovery && !showDiscountOffer
            && didYouKnowItem == nil
    }

    // MARK: - Default Sample Data

    /// 최초 설치 후 온보딩 완료 시 4종(일반 메모·템플릿·콤보·일반메모+템플릿)을 1개씩 삽입한다.
    /// "이런 것도 되는구나"를 첫 화면에서 바로 보여주기 위한 시드 데이터.
    /// UserDefaults 플래그로 중복 삽입을 방지한다(기존 설치 유저에겐 재삽입 안 함).
    private let samplesInsertedKey = "defaultSamplesInserted_v1"
    /// 기존 사용자에게 "체험해 볼래요?"를 이미 물어봤는지(신규 설치는 자동 처리되어 묻지 않음).
    private let demoOfferResolvedKey = "demoSampleOfferResolved_v1"

    /// 현재 페르소나·로케일에 맞는 샘플 4종 + 카테고리 2개를 만들어 저장한다. 성공 여부 반환.
    /// 샘플이 속한 카테고리를 실제로 생성·활성화해 "색 = 카테고리 = 스와이프 페이지"가
    /// 첫 화면에서 일관되게 동작하도록 한다.
    @discardableResult
    private func performSampleInsertion() -> Bool {
        let isKorean = (Locale.current.language.languageCode?.identifier ?? "en") == "ko"
        let persona = CategoryStore.shared.selectedPersona ?? .general
        let result = persona == .nomad ? nomadSamples(isKorean: isKorean) : generalSamples(isKorean: isKorean)
        do {
            var memos = (try? MemoStore.shared.load(type: .memo)) ?? []
            memos.append(contentsOf: result.memos)
            try MemoStore.shared.save(memos: memos, type: .memo)
            SampleMemoStorage.save(ids: result.memos.map { $0.id })
            seedPlaceholderValues(from: result.memos)
            // 샘플이 속한 카테고리를 실제로 만들고 기능을 켜 → 스와이프 페이지(탭)가 생긴다.
            result.categories.forEach { CategoryStore.shared.add($0) }
            CategoryStore.shared.enableFeature()
            print("✅ [APP INIT] 샘플 \(result.memos.count)개 + 카테고리 \(result.categories.count)개 시드 (persona=\(persona.rawValue))")
            // 시딩 후 리스트가 카테고리/메모를 다시 읽도록 알림 (신규 설치·체험 수락 공통)
            DispatchQueue.main.async {
                NotificationCenter.postOnMain(name: .demoSamplesInserted, object: nil)
            }
            return true
        } catch {
            print("❌ [APP INIT] 기본 샘플 삽입 실패: \(error)")
            return false
        }
    }

    /// 신규 설치에서만 자동 삽입. 신규 설치는 데모 질문 대상이 아니므로 resolved로 표시.
    /// 한국어 입력 토글 기본값은 OFF지만, 기존에 키보드 기본 언어를 한국어로 쓰던 사용자는
    /// 토글이 갑자기 사라지지 않도록 1회 자동 활성화한다. (영어 기본 사용자는 OFF 유지 → 한 안 보임)
    private func migrateKoreanEnabledIfNeeded() {
        let g = AppGroup.defaults
        guard g?.bool(forKey: DefaultsKey.koreanEnabledMigratedV1) != true else { return }
        if g?.string(forKey: DefaultsKey.keyboardTypingLang) == "korean" {
            g?.set(true, forKey: DefaultsKey.keyboardKoreanEnabled)
            print("🔄 [APP INIT] 기존 한국어 사용자, 한국어 입력 자동 활성화")
        }
        g?.set(true, forKey: DefaultsKey.koreanEnabledMigratedV1)
    }

    /// 기존 평문 보안 메모를 암호화한다(1회). 암호화 키가 아직 없으면 생성된다.
    /// 키 확보 실패(키체인 불가) 시 플래그를 세우지 않아 다음 실행에서 재시도.
    private func migrateSecureMemoEncryptionIfNeeded() {
        let g = AppGroup.defaults
        guard g?.bool(forKey: DefaultsKey.secureMemoEncryptionMigratedV1) != true else { return }
        do {
            var memos = try MemoStore.shared.load(type: .memo)
            var changed = false
            var allEncrypted = true
            for i in memos.indices where memos[i].isSecure && !SecureMemoCrypto.isEncrypted(memos[i].value) {
                if let enc = SecureMemoCrypto.encrypt(memos[i].value) {
                    memos[i].value = enc
                    changed = true
                } else {
                    allEncrypted = false
                }
            }
            if changed { try MemoStore.shared.save(memos: memos, type: .memo) }
            if allEncrypted {
                g?.set(true, forKey: DefaultsKey.secureMemoEncryptionMigratedV1)
                print("🔐 [APP INIT] 보안 메모 암호화 마이그레이션 완료 (변경: \(changed))")
            } else {
                print("⏳ [APP INIT] 보안 키 미확보, 다음 실행에서 보안 메모 암호화 재시도")
            }
        } catch {
            print("❌ [APP INIT] 보안 메모 암호화 마이그레이션 실패: \(error)")
        }
    }

    /// 시드 샘플 중 본문에 {변수}가 있는데도 templateVariables가 비어 isTemplate=false가 된
    /// 메모(예: "인사말 + 회신", "송금 안내 + 양식")를 1회 보정한다. 탭 시 하프모달이 뜨도록.
    /// 사용자가 직접 만든 메모(코드/JSON 안의 리터럴 중괄호 등)는 건드리지 않기 위해
    /// SampleMemoStorage가 추적하는 샘플 메모로만 범위를 한정한다.
    private func migrateSampleTemplateFlagsIfNeeded() {
        let g = AppGroup.defaults
        guard g?.bool(forKey: DefaultsKey.sampleTemplateFlagsMigratedV1) != true else { return }
        do {
            var memos = try MemoStore.shared.load(type: .memo)
            let sampleIds = SampleMemoStorage.load()
            var changed = false
            for i in memos.indices
            where sampleIds.contains(memos[i].id) && memos[i].templateVariables.isEmpty {
                let custom = memos[i].value.extractTemplatePlaceholders()
                if !custom.isEmpty {
                    memos[i].templateVariables = custom
                    changed = true
                    print("🔄 [APP MIGRATION] 샘플 템플릿 플래그 보정: \(memos[i].title) → \(custom)")
                }
            }
            if changed { try MemoStore.shared.save(memos: memos, type: .memo) }
            g?.set(true, forKey: DefaultsKey.sampleTemplateFlagsMigratedV1)
            print("🔄 [APP MIGRATION] 샘플 템플릿 플래그 마이그레이션 완료 (변경=\(changed))")
        } catch {
            print("❌ [APP MIGRATION] 샘플 템플릿 플래그 마이그레이션 실패: \(error)")
        }
    }

    /// 레거시 메모의 콤보/attached 필드만 원본 JSON에서 읽기 위한 경량 디코더.
    /// (신 Memo 모델은 이 키들을 더 이상 디코드하지 않으므로 별도로 읽어야 한다.)
    private struct LegacyMemoFields: Decodable {
        let id: UUID
        var isStack: Bool = false
        var stackValues: [String] = []
        var attachedTemplateId: UUID?
        // ⚠️ 이건 **옛 파일을 읽으려고** 있는 것이다. 글자를 새 이름으로 바꾸면
        //    읽으려던 그 옛 파일을 못 읽는다.
        enum CodingKeys: String, CodingKey {
            case id
            case isStack = "isCombo"
            case stackValues = "comboValues"
            case attachedTemplateId
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            isStack = try c.decodeIfPresent(Bool.self, forKey: .isStack) ?? false
            stackValues = try c.decodeIfPresent([String].self, forKey: .stackValues) ?? []
            attachedTemplateId = try c.decodeIfPresent(UUID.self, forKey: .attachedTemplateId)
        }
    }

    private var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    /// 플랫 콤보 파일(`combos.data`)이 비어있지 않게 남아 있는가.
    ///
    /// **싸다.** 콤보 파일은 작고, 변환이 끝난 뒤에는 대개 존재하지 않는다.
    /// 옛 백업을 CloudKit 으로 복원하면 이 파일이 되살아나므로 그 경우를 여기서 잡는다.
    private func hasLegacyComboFile() -> Bool {
        guard let url = appGroupContainerURL?.appendingPathComponent(StorageFile.combos),
              let d = try? Data(contentsOf: url) else { return false }
        return d.count > 2
    }

    /// `memos.data` 원본에 레거시 콤보/attached 키가 살아 있는가.
    ///
    /// ⚠️ **비싸다.** 메모 파일 전체를 읽어 전수 스캔한다. 아직 한 번도 변환하지
    ///    않은 런치에서만 부를 것.
    ///
    /// 측정(Instruments, iPhone15,3 / iOS 26.5.2 / Release / 메모 505개 · 339 KB):
    /// 예전에는 `String(data:encoding:)` 으로 통째로 문자열을 만든 뒤 `contains` 를
    /// 두 번 돌려 **호출당 17 ms** 였고, 첫 프레임 이전 구간이라 106 ms 짜리 행의
    /// 가장 큰 앱 코드 지분이었다. 바이트에서 바로 찾으면 String 변환이 통째로 빠진다.
    private func hasLegacyKeysInMemoFile() -> Bool {
        guard let url = appGroupContainerURL?.appendingPathComponent(StorageFile.memos),
              let d = try? Data(contentsOf: url) else { return false }
        let isStack = Data("\"isStack\":true".utf8)
        let attached = Data("\"attachedTemplateId\":\"".utf8)
        return d.range(of: isStack) != nil || d.range(of: attached) != nil
    }

    /// 변환되지 않은 레거시 콤보/attached 데이터가 디스크에 남아있는지 감지.
    ///
    /// ⚠️ 이미 변환을 끝낸 런치에서는 **부르지 않는다.** `migrateComboModelIfNeeded()`
    ///    의 guard 를 볼 것.
    private func hasLegacyComboData() -> Bool {
        hasLegacyComboFile() || hasLegacyKeysInMemoFile()
    }

    /// 콤보/메모+템플릿 데이터 모델 통합 마이그레이션.
    /// - 레거시 메모 내장 콤보(isStack+stackValues) → 자식 메모 생성 + childMemoIds
    /// - attachedTemplateId → 본문을 합쳐 일반 메모로 (compose)
    /// - 플랫 Combo(combos.data) → childMemoIds를 가진 콤보 Memo
    ///
    /// 하위호환 강화 포인트:
    /// - init 맨 앞 + onAppear + CloudKit 복원 후 모두에서 호출(멱등). 다른 load/save가 레거시 키를
    ///   지우기 전에 원본 JSON에서 먼저 읽는다.
    /// - 플래그가 set돼 있어도 `hasLegacyComboData()`가 참이면 재실행(옛 백업 복원 대비).
    /// - 단일 save로 원자적 적용. 실패 시 플래그 미set → 다음 기회에 재시도.
    private func migrateComboModelIfNeeded() {
        let g = AppGroup.defaults
        let alreadyMigrated = (g?.bool(forKey: DefaultsKey.comboModelUnifyMigratedV1) == true)
        // 이미 변환됐고 남은 레거시 데이터도 없으면 빠르게 종료.
        //
        // ⚠️ 변환이 끝난 런치에서는 **싼 검사만** 한다. 예전에는 여기서 무조건
        //    `hasLegacyComboData()` 를 불렀는데, 그 안에 메모 파일 전수 스캔이 들어
        //    있어서 몇 달 전에 변환이 끝난 사용자도 **매 런치마다 17 ms** 를 냈다.
        //    그것도 첫 프레임 이전, 워치독의 `scene-create` 창 안에서다.
        //    (docs/postmortem/LAUNCH_WATCHDOG_4_4_6.md 가 바로 그 구간의 사고다)
        //
        //    비싼 검사를 빼도 안전한 이유: 옛 백업 복원이 되살리는 것은 `combos.data`
        //    이고 그건 싼 검사가 잡는다. 게다가 CloudKit 복원 경로는 플래그 자체를
        //    명시적으로 내린다(`CloudKitBackupService.restore`). 그러면 아래 guard 의
        //    `!alreadyMigrated` 가 참이 되어 비싼 검사까지 정상적으로 돈다.
        if alreadyMigrated, !hasLegacyComboFile() { return }
        do {
            // 1) 원본 JSON에서 레거시 필드 먼저 읽기 (이후 save로 사라지기 전에).
            //    OldMemo 등 과거 포맷도 id만 있으면 디코드됨(콤보 필드는 기본값).
            var legacyById: [UUID: LegacyMemoFields] = [:]
            if let url = appGroupContainerURL?.appendingPathComponent(StorageFile.memos),
               let data = try? Data(contentsOf: url),
               let legacy = try? JSONDecoder().decode([LegacyMemoFields].self, from: data) {
                for l in legacy { legacyById[l.id] = l }
            }

            var memos = try MemoStore.shared.load(type: .memo)   // 신 모델 (stackValues 보유 메모는 그대로 디코드)
            var converted = false

            // 2) attachedTemplate → 본문 합치기 + dev childMemoIds 콤보 → stackValues.
            //    (레거시 메모 내장 콤보의 comboValues는 모델에 그대로 디코드되어 별도 변환 불필요.)
            let valueById = Dictionary(memos.map { ($0.id, $0.value) }, uniquingKeysWith: { a, _ in a })
            for i in memos.indices {
                if let L = legacyById[memos[i].id],
                   let tId = L.attachedTemplateId,
                   let tmpl = memos.first(where: { $0.id == tId }) {
                    memos[i].value = TemplateVariableProcessor.compose(
                        memoValue: memos[i].value, templateBody: tmpl.value, templateInputs: [:])
                    converted = true
                }
                // dev(미출시)에서 만든 childMemoIds 콤보 → 참조 메모 value를 stackValues 단계로 펼침.
                if memos[i].stackValues.isEmpty, !memos[i].childMemoIds.isEmpty {
                    let steps = memos[i].childMemoIds.compactMap { valueById[$0] }.filter { !$0.isEmpty }
                    if !steps.isEmpty {
                        memos[i].stackItems = steps.map { StackItem(value: $0) }
                        memos[i].childMemoIds = []
                        converted = true
                    }
                }
            }

            // 3) 플랫 Combo(combos.data) → comboValues를 가진 콤보 Memo (기존 Combo 타입으로 디코드)
            let combos = (try? MemoStore.shared.loadCombos()) ?? []
            for c in combos where !memos.contains(where: { $0.id == c.id }) {
                var steps: [String] = []
                for item in c.items.sorted(by: { $0.order < $1.order }) {
                    if item.type == .memo || item.type == .template,
                       let v = valueById[item.referenceId], !v.isEmpty {
                        steps.append(v)
                    } else {
                        let v = item.displayValue ?? ""
                        let t = (item.displayTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !v.isEmpty { steps.append(v) } else if !t.isEmpty { steps.append(t) }
                    }
                }
                guard !steps.isEmpty else { continue }   // 빈 콤보는 만들지 않음
                var stackMemo = Memo(
                    id: c.id, title: c.title, value: "",
                    isFavorite: c.isFavorite, category: c.category,
                    stackValues: steps, stackInterval: c.interval, lastUsedAt: c.lastUsed)
                stackMemo.clipCount = c.useCount
                memos.append(stackMemo)
                converted = true
            }
            // 변경이 있을 때만 저장(불필요한 디스크 쓰기 방지).
            if converted {
                try MemoStore.shared.save(memos: memos, type: .memo)
            }

            // 4) combos.data 삭제(없으면 무시) + 플래그
            if let url = appGroupContainerURL?.appendingPathComponent(StorageFile.combos) {
                try? FileManager.default.removeItem(at: url)
            }
            g?.set(true, forKey: DefaultsKey.comboModelUnifyMigratedV1)
            print("🔄 [APP MIGRATION] 콤보 모델 통합 완료 (변경=\(converted))")
        } catch {
            print("❌ [APP MIGRATION] 콤보 모델 마이그레이션 실패: \(error)")
        }
    }

    /// v4.3.6 정책: 메모 심볼은 **기본 숨김** - showVisualCues를 1회 강제 OFF로 리셋한다.
    /// 구 카테고리 심볼 토글(categoryBadgeVisible) 승계 마이그레이션이 일부 사용자에게
    /// 심볼을 되살리던 문제를 함께 정리. 원하는 사용자는 설정 > 메모 표시에서 다시 켠다.
    /// (심볼 노출은 오직 이 토글만 따른다 - iOS '색상 없이 구별' 접근성과 무관.)
    private func migrateVisualCuesIfNeeded() {
        let std = UserDefaults.standard
        guard !std.bool(forKey: DefaultsKey.visualCuesDefaultOffV436) else { return }
        AppGroup.defaults?.set(false, forKey: DefaultsKey.showVisualCues)
        std.set(true, forKey: DefaultsKey.visualCuesDefaultOffV436)
        std.set(true, forKey: DefaultsKey.visualCuesMigratedV1)   // 구 승계 마이그레이션도 종료 처리
        print("🔄 [APP MIGRATION] 메모 심볼 기본 숨김 리셋 완료 (v4.3.6)")
    }

    private func insertDefaultSamplesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: samplesInsertedKey) else { return }

        // ⚠️ 새로 시작하는 사람에게 **반드시** 넣는다. 튜토리얼이 가리킬 것이 바로 이것이다.
        //
        //    한동안은 반대로 했다 - 새 설치에는 샘플을 넣지 않고 첫 단축어를 자기 손으로
        //    만들게 했다. 그런데 처음 온 사람에게 필요한 건 만드는 법이 아니라 **이게 무엇을
        //    해주는 물건인지**였다. 이제 단축어·템플릿·콤보를 한 벌 넣어 두고,
        //    튜토리얼은 그것들을 차례로 눌러 보게 한다(`SnippetsTab` · `TutorialScenarios`).
        if performSampleInsertion() {
            UserDefaults.standard.set(true, forKey: samplesInsertedKey)
            UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
        }
    }

    /// 이미 설치돼 자동 삽입을 못 받은 기존 사용자에게만 1회 체험을 묻는다.
    private func offerDemoSamplesToExistingUserIfNeeded() {
        guard UserDefaults.standard.bool(forKey: samplesInsertedKey),
              !UserDefaults.standard.bool(forKey: demoOfferResolvedKey) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showDemoSampleOffer = true
        }
    }

    /// 새 기기(또는 재설치) 첫 실행에서 "기존에 쓰던 메모를 불러올 수 있어요"를 1회 안내한다.
    /// 조건: ① 아직 안내 안 함, ② 시작 시 로컬에 내 메모가 없었음(새 기기 신호),
    ///       ③ iCloud에 실제 백업이 존재함(복원할 게 있을 때만 안내 - 신규 유저에겐 안 뜸).
    /// 안내는 한 번만(표시 시 플래그 기록). 백업이 아직 확인 안 되면 다음 실행에서 재시도.
    private func offerRestoreHintIfNeeded(localWasEmpty: Bool) {
        guard !UserDefaults.standard.bool(forKey: restoreHintShownKey) else { return }
        guard localWasEmpty else { return }   // 이미 내 메모가 있는 기기면 안내 불필요
        Task {
            let hasBackup = await CloudKitBackupService.shared.hasBackup()
            guard hasBackup else { return }   // 복원할 백업이 없으면 안내하지 않음(플래그도 유지)
            await MainActor.run {
                guard !showDemoSampleOffer else { return }   // 다른 모달과 중첩 방지
                UserDefaults.standard.set(true, forKey: restoreHintShownKey)
                showRestoreHint = true
            }
        }
    }

    // MARK: - 심어 두는 빈칸 값

    /// 일반 샘플 템플릿의 빈칸에 미리 넣어 두는 값.
    ///
    /// ⚠️ **그대로 써도 말이 되는 것**으로 고른다. "홍길동" 같은 예시용 가짜를 넣으면
    ///    사용자는 그걸 지우는 것부터 배우게 된다. "고객님"은 지울 필요 없이 바로 쓰인다.
    ///
    /// ⚠️ 내장 토큰({날짜}·{시간}·{통화} 등)에는 값을 심지 않는다. 시스템이 채우는 자리다.
    static func starterPlaceholderValues(isKorean: Bool) -> [String: [String]] {
        isKorean
            ? ["{이름}": ["고객님", "대표님", "선생님"]]
            : ["{name}": ["there", "team"]]
    }

    /// 노마드 샘플 템플릿에 심는 값.
    ///
    /// ⚠️ **계좌정보({iban}·{swift}·{수신인})에는 심지 않는다.** 예시 IBAN 을 넣어 두면
    ///    사용자가 그것을 자기 계좌로 착각하고 청구서에 붙여넣을 수 있다. 돈이 남에게 간다.
    ///    그 자리는 비워 두고, 값 화면에서 **바로 적어 넣을 수 있게** 열어 두었다
    ///    (`PlaceholderInputView.emptyValuesSection`). 비어 있는 것과 막힌 것은 다르다.
    ///
    /// ⚠️ 나머지는 누구에게나 같은 것이라 심어도 안전하다.
    static func starterNomadPlaceholderValues(isKorean: Bool) -> [String: [String]] {
        isKorean
            ? ["{금액}": ["USD 500", "EUR 1,200", "USD 1,000"],
               "{참조번호}": ["INV-001", "2026-08"]]
            : ["{amount}": ["USD 500", "EUR 1,200", "USD 1,000"],
               "{reference}": ["INV-001", "2026-08"]]
    }

    /// 심어 둔 값을 **앱 전체가 함께 보는 저장소**에도 적는다.
    ///
    /// ⚠️ **본진은 공용 저장소(`placeholder_values_{토큰}`)다.** 앱의 입력 화면·빈칸 관리·
    ///    키보드가 모두 그곳을 본다. 단축어에 붙은 사본(`Memo.placeholderValues`)은 옛 데이터를
    ///    위한 폴백으로만 남아 있다(키보드는 공용 저장소가 비었을 때만 그것을 본다).
    ///    그래서 심어 둔 값도 **공용 저장소에 적어야** 화면에 보인다.
    private func seedPlaceholderValues(from memos: [Memo]) {
        for memo in memos {
            for (token, values) in memo.placeholderValues {
                // 시스템이 채우는 자리에는 값을 심지 않는다 - 심어 봐야 쓰이지 않고,
                // 빈칸 관리 화면에 "고를 수 없는 값"으로 남는다.
                guard !TemplateVariableProcessor.autoVariableTokens.contains(token) else { continue }
                // 뒤에서부터 넣는다 - addPlaceholderValue 가 맨 앞에 꽂으므로 순서가 뒤집힌다.
                for value in values.reversed() {
                    MemoStore.shared.addPlaceholderValue(value,
                                                         for: token,
                                                         sourceMemoId: memo.id,
                                                         sourceMemoTitle: memo.title)
                }
            }
        }
    }

    private func generalSamples(isKorean: Bool) -> (memos: [Memo], categories: [String]) {
        let work = isKorean ? "업무" : "Work"
        let personal = isKorean ? "개인" : "Personal"
        // 1) 일반 메모 (즐겨찾기) - 기본 제공되는 즐겨찾기 탭에 바로 들어가 분홍으로 표시
        //    hint: 각 샘플이 "어떤 타입의 단축어인지"를 카드에서 살며시 알려주는 학습 장치.
        let memo = Memo(
            title: isKorean ? "내 이메일" : "My Email",
            value: "example@email.com",
            isFavorite: true,
            hint: isKorean ? "가장 단순한 단축어, 탭 한 번이면 입력 끝" : "The simplest snippet: one tap to type"
        )
        // 2) 템플릿 - 본문에 {변수}가 있으면 자동으로 템플릿(templateVariables로 판정)
        //
        // ⚠️ {날짜} 는 여기 **적지 않는다.** 시스템이 오늘 날짜로 알아서 채우는 내장 토큰이라
        //    (`TemplateVariableProcessor.autoVariableTokens`), 사용자 빈칸 목록에 넣으면
        //    이미 채워질 자리를 사람에게 채우라고 묻게 된다. 사람이 채울 것만 여기 적는다.
        //
        // ⚠️ 값은 **함께 심는다.** 빈칸만 만들어 두면 튜토리얼에서 이 키를 누른 사람이
        //    "저장된 값이 없어요"를 만난다. 처음 온 사람에게 처음 보여 주는 것이
        //    비어 있다는 안내면, 가르치려던 것을 가르치지 못한다.
        //    (아래 값들은 그대로 써도 말이 되는 것으로 골랐다. 예시용 가짜가 아니다)
        let template = Memo(
            title: isKorean ? "회신 템플릿" : "Reply Template",
            value: isKorean
                ? "{이름}님, 문의 주셔서 감사합니다.\n{날짜}까지 답변드릴게요."
                : "Hi {name}, thanks for reaching out.\nI'll reply by {date}.",
            category: work,
            templateVariables: isKorean ? ["{이름}"] : ["{name}"],
            placeholderValues: Self.starterPlaceholderValues(isKorean: isKorean),
            hint: isKorean ? "{변수} 빈칸을 채워 쓰는 템플릿" : "A template: fill in the {blanks}"
        )
        // 3) 콤보 - 메모 안에 순서 있는 단계들(stackValues)
        let stack = Memo(
            title: isKorean ? "이름 + 연락처" : "Name + Contact",
            value: "",
            category: personal,
            stackValues: isKorean ? ["홍길동", "010-0000-0000"] : ["John Doe", "555-0000"],
            hint: isKorean ? "값 여러 개를 순서대로 입력하는 콤보" : "A combo: types multiple values in order"
        )
        // 4) 인사말 + 회신 양식을 한 메모로 합침 - 본문에 {변수}가 있으므로 템플릿이어야 한다.
        //    templateVariables를 넘기지 않으면 isTemplate=false가 되어 탭 시 {변수}가
        //    그대로 복사되는 버그가 생긴다. 합쳐진 본문의 커스텀 토큰을 그대로 사용.
        let memoWithTemplate = Memo(
            title: isKorean ? "인사말 + 회신" : "Greeting + Reply",
            value: (isKorean ? "안녕하세요, 연락 주셔서 반갑습니다!" : "Hi, great to hear from you!") + "\n" + template.value,
            category: work,
            templateVariables: template.templateVariables,
            placeholderValues: template.placeholderValues,
            hint: isKorean ? "단축어에 템플릿을 이어 붙인 중첩 단축어" : "A nested snippet: a snippet plus a template"
        )
        return ([memo, template, stack, memoWithTemplate], [work, personal])
    }

    private func nomadSamples(isKorean: Bool) -> (memos: [Memo], categories: [String]) {
        let finance = isKorean ? "금융" : "Finance"
        let travel = isKorean ? "여행" : "Travel"
        let template = Memo(
            title: isKorean ? "국제 송금 양식" : "Bank Transfer",
            value: isKorean
                ? "{금액}을 {수신인}에게 보냅니다\nIBAN: {iban}\nSWIFT: {swift}\n참조: {참조번호}"
                : "Pay {amount} to {recipient}\nIBAN: {iban}\nSWIFT: {swift}\nRef: {reference}",
            category: finance,
            templateVariables: isKorean
                ? ["{금액}", "{수신인}", "{iban}", "{swift}", "{참조번호}"]
                : ["{amount}", "{recipient}", "{iban}", "{swift}", "{reference}"],
            // ⚠️ **IBAN·SWIFT 에는 값을 심지 않는다.** 남의 계좌번호를 예시로 넣어 두면
            //    사용자가 그것을 자기 것으로 착각하고 청구서에 붙여넣을 수 있다.
            //    그 자리는 비워 두고, 대신 키보드에서 바로 채울 수 있게 열어 뒀다
            //    (`KeyboardOverlays` 의 값 추가). 통화 단위처럼 **누구에게나 같은 것**만 심는다.
            placeholderValues: Self.starterNomadPlaceholderValues(isKorean: isKorean),
            hint: isKorean ? "{변수} 빈칸을 채워 쓰는 템플릿" : "A template: fill in the {blanks}"
        )
        let stack = Memo(
            title: isKorean ? "내 연락처" : "My Contact",
            value: "",
            category: travel,
            stackValues: isKorean ? ["이름", "이메일", "전화번호"] : ["Full Name", "Email", "Phone"],
            hint: isKorean ? "값 여러 개를 순서대로 입력하는 콤보" : "A combo: types multiple values in order"
        )
        // 즐겨찾기 - 기본 제공되는 즐겨찾기 탭에 바로 들어가 분홍으로 표시
        let checklist = Memo(
            title: isKorean ? "여행 체크리스트" : "Travel Checklist",
            value: isKorean
                ? "여권 ✓\n비자 ✓\n여행자보험 ✓\n긴급 연락처: "
                : "Passport ✓\nVisa ✓\nTravel Insurance ✓\nEmergency Contact: ",
            isFavorite: true,
            hint: isKorean ? "가장 단순한 단축어, 탭 한 번이면 입력 끝" : "The simplest snippet: one tap to type"
        )
        // 고정 안내문 + 송금 양식을 한 메모로 합침 - 본문에 {변수}가 있으므로 템플릿이어야 한다.
        let noteWithTemplate = Memo(
            title: isKorean ? "송금 안내 + 양식" : "Payment note + form",
            value: (isKorean ? "아래 계좌로 송금 부탁드립니다." : "Please send payment to the account below.") + "\n" + template.value,
            category: finance,
            templateVariables: template.templateVariables,
            placeholderValues: template.placeholderValues,
            hint: isKorean ? "단축어에 템플릿을 이어 붙인 중첩 단축어" : "A nested snippet: a snippet plus a template"
        )
        return ([template, stack, checklist, noteWithTemplate], [finance, travel])
    }

    var body: some Scene {
        WindowGroup {
            // 테스트 호스트: 무거운 화면/onAppear 마이그레이션 없이 빈 뷰만 띄워
            // 테스트 러너가 즉시 연결되게 한다. (ViewBuilder 조건 분기)
            if ClipKeyboardApp.isRunningUnitTests {
                Color.clear
            } else {
            AppThemedContainer {
            MainTabView()
                .environmentObject(storeManager)
                // 언어를 바꾸면 화면을 통째로 새로 그린다. NSLocalizedString 은 그릴 때
                // 값을 읽으므로, 다시 그리기만 하면 앱을 껐다 켤 필요가 없다.
                .id(languageRefreshToken)
                .environment(\.locale, AppLanguage.locale)
                .onReceive(NotificationCenter.default.publisher(for: .appLanguageChanged)) { _ in
                    languageRefreshToken += 1
                }
                // 팁은 앱 어디에서 뜨든 **마스코트가 말을 거는 모양**이다.
                // 여기 한 곳에 걸어 두면 TipView·popoverTip 이 모두 같은 얼굴로 나온다.
                #if targetEnvironment(macCatalyst)
                .frame(minWidth: 520, minHeight: 640)
                #endif
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                // 런치 작업 전부를 **첫 화면 뒤로** 미룬다. `onAppear` 가 아니라 `task` 인 이유는
                // 화면이 실제로 붙은 다음에 돌기 시작하고, 중간에 기다릴(await) 수 있어서다.
                .task {
                    await runLaunchSequence()
                }
                // 단축어를 만들거나 지울 때마다 개수를 다시 센다 - 9개에 닿는 순간이 시계의 시작이다.
                .onReceive(NotificationCenter.default.publisher(for: .memoDataChanged)) { _ in
                    noteShortcutCountForDiscountOffer()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIAccessibility.voiceOverStatusDidChangeNotification
                    )
                ) { _ in
                    checkVoiceOverAndNudge()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 앱이 다시 앞으로 오면 즉시 동기화 - 다른 기기의 최신 메모를 바로 반영.
                    // (start는 멱등 - 토글이 KV로 전파돼 막 켜진 경우 여기서 시작될 수 있음.)
                    // ⚠️ 세이프 모드에서는 쉰다. 런치에서 죽은 원인이 이 근처일 수 있는데,
                    //    복귀할 때마다 같은 것을 다시 부르면 세이프 모드의 뜻이 없어진다.
                    if phase == .active, !LaunchGuard.isSafeMode {
                        ProFeatureManager.mirrorSyncEntitlement()
                        MemoSyncEngine.shared.startIfEnabled()
                        MemoSyncEngine.shared.syncNow()
                        reportForegroundActivity()
                    }
                    // 사용자가 앱을 뒤로 보냈다면 이 런치는 성공한 것이다 - 화면을 보고
                    // 손으로 나간 것이니까. 여기서 런치를 닫아, 나중에 메모리 정리로
                    // 죽더라도 "런치가 멈췄다"고 잘못 읽지 않게 한다.
                    if phase == .background {
                        LaunchGuard.finish()
                    }
                }
                // 데이터 손상 복구 안내 - 다른 시트보다 먼저 붙여 우선 노출시킨다.
                .sheet(isPresented: $showDataRecovery) {
                    DataRecoveryView()
                }
                .sheet(isPresented: $showReviewRequest) {
                    ReviewRequestView()
                        .presentationDetents([.medium])
                }
                .sheet(isPresented: $showAccessibilityGuide) {
                    AccessibilityGuideView()
                }
                .alert(
                    NSLocalizedString("이런 기능도 있어요", comment: "Demo samples offer title"),
                    isPresented: $showDemoSampleOffer
                ) {
                    Button(NSLocalizedString("체험해 보기", comment: "Demo samples offer accept")) {
                        // performSampleInsertion 내부에서 .demoSamplesInserted 알림을 발행해 리스트가 갱신됨
                        performSampleInsertion()
                        UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
                    }
                    Button(NSLocalizedString("괜찮아요", comment: "Demo samples offer decline"), role: .cancel) {
                        UserDefaults.standard.set(true, forKey: demoOfferResolvedKey)
                    }
                } message: {
                    Text(NSLocalizedString("템플릿·콤보·단축어+템플릿 예시 4개를 추가해 직접 써볼 수 있어요. 기존 단축어는 그대로 유지돼요.", comment: "Demo samples offer message"))
                }
                .alert(
                    NSLocalizedString("기존 단축어를 불러올 수 있어요", comment: "Restore hint title"),
                    isPresented: $showRestoreHint
                ) {
                    Button(NSLocalizedString("불러오기", comment: "Restore hint: open restore")) {
                        showCloudBackupSheet = true
                    }
                    Button(NSLocalizedString("나중에", comment: "Restore hint: dismiss"), role: .cancel) { }
                } message: {
                    Text(NSLocalizedString("기존에 쓰던 단축어를 불러오는 방법이 있습니다. iCloud 백업에서 복원할 수 있어요.", comment: "Restore hint message"))
                }
                .sheet(isPresented: $showCloudBackupSheet) {
                    NavigationStack { CloudBackupView() }
                }
                // 반값 제안 - 조건은 maybeShowDiscountOffer 가 다 본다.
                .sheet(isPresented: $showDiscountOffer) {
                    DiscountOfferView(occasion: discountOccasion)
                        .presentationDetents([.large])
                }
                .alert(
                    NSLocalizedString("혹시 불편한 점이 있으세요?", comment: "Feedback nudge title"),
                    isPresented: $showFeedbackNudge
                ) {
                    Button(NSLocalizedString("의견 남기기", comment: "Feedback nudge: leave feedback")) {
                        showFeedbackSheet = true
                    }
                    Button(NSLocalizedString("다음에", comment: "Feedback nudge: later"), role: .cancel) { }
                    Button(NSLocalizedString("다시 보지 않기", comment: "Feedback nudge: never show again")) {
                        // 영구 중단이 아니라 6개월 유예 - maybeShowFeedbackNudge가 기간 판정.
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: DefaultsKey.feedbackNudgeOptOutDate)
                    }
                } message: {
                    Text(NSLocalizedString("필요한 기능이나 불편했던 점을 남겨주시면 개발자가 직접 읽고 반드시 해결해 드릴게요.", comment: "Feedback nudge message"))
                }
                .sheet(isPresented: $showFeedbackSheet) {
                    FeedbackView()
                }
                .sheet(item: $categoryCleanup) { request in
                    CategoryCleanupNotice(categories: request.categories, empty: request.empty)
                }
                // 설정 안쪽 목록에서 고른 행선지도 여기로 모인다 - 행선지를 아는 곳은 한 군데다.
                .onReceive(NotificationCenter.default.publisher(for: .didYouKnowAction)) { note in
                    guard let action = note.object as? DidYouKnow.Action else { return }
                    handleDidYouKnowAction(action)
                }
                .sheet(item: $didYouKnowItem) { item in
                    DidYouKnowView(item: item,
                                   onAction: { handleDidYouKnowAction($0) },
                                   onClose: { didYouKnowItem = nil })
                        .presentationDetents([.medium])
                }
                .sheet(isPresented: $showWhatsNew) {
                    WhatsNewView(
                        onClose: { showWhatsNew = false },
                        onPrimaryAction: {
                            showWhatsNew = false
                            // 읽고 닫으면 아무것도 안 달라진다 - 소개한 그 화면으로 직접 데려간다.
                            //
                            // ⚠️ 5.0 의 목적지는 **사용 기록**이다. 이번 안내에서 가장 크게
                            //    달라진 것이 거기 있고, 무엇보다 그 화면은 "당신이 이만큼
                            //    아꼈다"고 말해 준다. 새 단장을 알리는 자리의 끝으로 맞다.
                            NotificationCenter.postOnMain(name: .openUsageTab, object: nil)
                        }
                    )
                    .presentationDetents([.large])
                }
        } // AppThemedContainer
            } // else (비테스트 실행)

        }
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 620, height: 780)
        #endif
        #if targetEnvironment(macCatalyst)
        .commands {
            // 클립키보드 전용 메뉴
            // v4.2: ⌃⇧ (Control+Shift) + 영문자 3-key 조합으로 통일.
            // Mac에서 Control+Shift 계열 단축키는 거의 표준 바인딩이 없어
            // 타 유틸(Raycast/Maccy/Alfred 등)과 충돌 가능성이 낮음.
            CommandMenu(NSLocalizedString("ClipKeyboard", comment: "App menu name")) {
                Button(NSLocalizedString("Memo List", comment: "Menu: memo list")) {
                    NotificationCenter.postOnMain(name: .showMemoList, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.control, .shift])

                Button(NSLocalizedString("New Memo", comment: "Menu: new memo")) {
                    NotificationCenter.postOnMain(name: .showNewMemo, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.control, .shift])

                Divider()

                Button(NSLocalizedString("Clipboard History", comment: "Menu: clipboard history")) {
                    NotificationCenter.postOnMain(name: .showClipboardHistory, object: nil)
                }
                .keyboardShortcut("h", modifiers: [.control, .shift])

                Button(NSLocalizedString("Paywall", comment: "Menu: paywall")) {
                    NotificationCenter.postOnMain(name: .showPaywall, object: nil)
                }

                Divider()

                Button(NSLocalizedString("Preferences…", comment: "Menu: preferences")) {
                    NotificationCenter.postOnMain(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(replacing: .help) {
                Button(NSLocalizedString("ClipKeyboard Help", comment: "Menu: help")) {
                    if let url = URL(string: "https://m1zz.github.io/ClipKeyboard/tutorial.html") {
                        #if targetEnvironment(macCatalyst)
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
            }
        }
        #endif
    }

    // MARK: - Accessibility Nudge

    /// VoiceOver가 켜진 상태로 앱에 진입하면 최초 1회 접근성 안내 시트를 띄운다.
    private func checkVoiceOverAndNudge() {
        #if os(iOS)
        let nudgeKey = "a11y_guide_nudge_shown_v1"
        guard UIAccessibility.isVoiceOverRunning,
              !(UserDefaults.standard.bool(forKey: nudgeKey)) else { return }
        UserDefaults.standard.set(true, forKey: nudgeKey)
        // 리뷰 시트와 겹치지 않도록 약간 지연
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showAccessibilityGuide = true
        }
        #endif
    }

    // MARK: - 사용 통계 (사람이 앱을 앞으로 가져온 순간)

    /// 화면이 실제로 떴을 때만 불린다 - 백그라운드 새로고침으로 프로세스만 깨어난 경우는 제외.
    /// 그래야 "앱을 여는 사람"과 "키보드만 쓰는 사람"이 통계에서 섞이지 않는다.
    private func reportForegroundActivity() {
        UsageReportingService.reportForegroundOpen()

        // 키보드 익스텐션이 App Group에만 쌓아 둔 활동일을 그날 날짜 그대로 소급 전송.
        // 앱을 오랜만에 열었어도 그 사이 키보드를 쓴 날들이 추이 차트에 복원된다.
        Task(priority: .utility) {
            await UsageReportingService.reportKeyboardActiveDays()
        }
    }

    // MARK: - URL Scheme Handler

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "clipkeyboard" else { return }
        print("🔗 [URL] App opened with URL: \(url)")

        if url.host == "copy", let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "id" })?.value,
           let memoId = UUID(uuidString: idString) {
            // 위젯에서 메모 복사 요청
            copyMemoToClipboard(memoId: memoId)
        } else if url.host == "paywall" {
            // 키보드 익스텐션에서 paywall 직행 요청 (v4.0)
            NotificationCenter.postOnMain(name: .showPaywall, object: nil)
        } else if url.host == "quicknote" {
            // Control Center 빠른 메모 컨트롤 → 빠른 메모 입력 시트 열기.
            // 콜드 런치에선 이 알림이 리스트의 구독 설치보다 먼저 발행돼 유실될 수 있어
            // 보류 플래그도 함께 켠다(리스트가 활성화/onAppear에서 소비, 소비 시 해제라 중복 없음).
            AppGroup.defaults?.set(true, forKey: DefaultsKey.pendingQuickNoteAdd)
            NotificationCenter.postOnMain(name: .openQuickNoteAdd, object: nil)
        }
    }

    private func copyMemoToClipboard(memoId: UUID) {
        let store = MemoStore.shared
        if store.memos.isEmpty {
            try? store.memos = store.load(type: .memo)
        }

        guard let memo = store.memos.first(where: { $0.id == memoId }) else {
            print("⚠️ [Widget Copy] 메모를 찾을 수 없음: \(memoId)")
            return
        }

        #if os(iOS)
        // 위젯은 보안 메모를 노출하지 않지만, 방어적으로 암호문이면 복호화(키 없으면 중단).
        let widgetValue: String
        if SecureMemoCrypto.isEncrypted(memo.value) {
            guard let dec = SecureMemoCrypto.decrypt(memo.value) else {
                print("🔒 [Widget Copy] 보안 키 미동기화 - 복사 중단")
                return
            }
            widgetValue = dec
        } else {
            widgetValue = memo.value
        }
        UIPasteboard.general.string = widgetValue
        print("✅ [Widget Copy] 클립보드에 복사됨: \(memo.title)")

        // 복사 완료 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func setupMacCatalystCommands() {
        print("⌨️ [MAC CATALYST] 단축키 설정 완료")

        // 메뉴바 아이콘 설정
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            MenuBarManager.shared.setupMenuBar()
        }

        // 전역 핫키 등록
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            GlobalHotkeyManager.shared.registerGlobalHotkey()
        }
    }
    #endif
}

// MARK: - Main Tab View (iOS 26 순정 플로팅 glass 탭바)

/// 앱 루트 - 순정 시스템 탭바(Liquid Glass 캡슐) 그대로 사용.
/// 한때 캡슐 없는 커스텀 하단 바로 대체했으나 순정 대비 어색해서 네이티브로 원복.
struct MainTabView: View {
    /// 단축어 탭이 지금 무엇을 보여주고 있는가 - 탭 이름·아이콘이 이 값을 따라간다.
    /// (`SnippetsTab` 이 쓰는 것과 **같은 키·같은 저장소**라 전환 버튼을 누르면 여기도 바뀐다)
    @AppStorage(DefaultsKey.snippetsTabStyle) private var snippetsStyleRaw: String = SnippetsTabStyle.list.rawValue

    /// 클립보드 기록 시트(맥 메뉴·딥링크에서 열린다).
    @State private var showClipboardSheet = false

    /// 지금 어느 탭인가. 이미 선택된 탭을 **한 번 더** 누른 것을 잡아내려면 선택 값이 필요하다.
    @State private var selection: MainTab = .snippets

    // MARK: - "이 탭에는 화면이 둘이에요" 를 띄우는 동안

    /// ⚠️ 조건을 **여기서 다시 적지 않는다.** 처음에는 그렇게 했다가 "다 배운 뒤"라는
    ///    조건이 빠져, 앱을 켜자마자 탭만 빛나고 그게 무슨 뜻인지 말해 주는 띠는 없었다.
    ///    조건은 `SnippetsTab.showsSwitchHint` 한 곳에서 정하고 여기로 흘러온다.
    @ObservedObject private var switchHint = SwitchHintBeacon.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 잰 탭바 첫 칸의 자리(화면 좌표). 못 재면 nil - 그러면 아무것도 안 그린다.
    @State private var firstTabFrame: CGRect?

    /// 단축어 탭을 보고 있을 때만 짚는다 - 다른 탭에서 1번 칸이 빛나면 그건 딴소리다.
    private var showsSwitchHint: Bool {
        switchHint.isShowing && selection == .snippets
    }

    private enum MainTab: Hashable {
        case snippets, usage, settings, search
    }

    private var snippetsStyle: SnippetsTabStyle {
        SnippetsTabStyle(rawValue: snippetsStyleRaw) ?? .list
    }

    /// 탭바가 값을 다시 써 넣을 때 **같은 값인지**를 본다.
    ///
    /// 단축어 탭을 보는 중에 그 탭을 한 번 더 누르면 목록 ↔ 키보드가 뒤집힌다.
    /// 툴바의 전환 버튼과 같은 일을 하는 두 번째 길이라, 버튼을 못 찾아도 오갈 수 있다.
    ///
    /// ⚠️ 예전에는 **키보드 → 목록** 한 방향만 두었다. 다시 누르기는 되돌아오는 동작이어야
    ///    예측이 된다고 봤기 때문이다. 지금은 양방향이다. 탭 이름과 아이콘이 지금 보는 화면을
    ///    따라가므로(목록일 땐 격자, 키보드일 땐 키보드), 탭바만 봐도 다음에 어디로 갈지
    ///    읽히기 때문이다. 한 방향만 되면 목록에서는 다시 눌러도 아무 일이 없어
    ///    "이 탭은 원래 그런가" 로 끝난다.
    private var selectionBinding: Binding<MainTab> {
        Binding {
            selection
        } set: { tapped in
            if tapped == .snippets, selection == .snippets {
                HapticManager.shared.light()
                // 값만 바꾼다 - 연출은 `SnippetsTab.content` 가 건다.
                snippetsStyleRaw = snippetsStyle.toggled.rawValue
            }
            selection = tapped
        }
    }

    var body: some View {
        TabView(selection: selectionBinding) {
            // 목록이냐 키보드 무대냐는 **사용자가 고른다**(설정 > 첫 화면).
            // 쓰던 사람의 기본은 목록 - 업데이트했다고 첫 화면이 바뀌면 안 된다.
            //
            // ⚠️ 탭 이름과 아이콘이 **지금 보고 있는 화면**을 따라간다. 예전에는 늘 "단축어"에
            //    격자 아이콘이라, 키보드 무대를 보는 중에도 탭바만 격자를 가리켜 어긋났다.
            //    탭바는 "여기가 어디인지"를 말하는 자리이므로 화면과 같은 말을 해야 한다.
            Tab(snippetsStyle.tabName,
                systemImage: snippetsStyle.symbolName,
                value: MainTab.snippets, role: nil) {
                SnippetsTab()
            }
            // ⚠️ 예전에는 이 자리가 **클립보드**였고 사용 기록은 설정 안에 있었다. 둘을 맞바꾼다.
            //    클립보드는 키보드 안에서 꺼내 쓰는 것이지 탭을 열어 들여다보는 것이 아니었고,
            //    사용 기록(내가 얼마나 아꼈나)은 오히려 가끔 열어 보는 자리라 탭이 어울린다.
            //    클립보드는 설정 > 내 데이터에 있고, 맥 메뉴/딥링크는 아래 시트로 계속 닿는다.
            Tab(NSLocalizedString("사용 기록", comment: "Usage passport settings entry"),
                systemImage: AppSymbol.checkmarkSealFill,
                value: MainTab.usage, role: nil) {
                NavigationStack { UsagePassportView().alwaysTransparentBars() }
            }
            Tab(NSLocalizedString("설정", comment: "Menu: settings"),
                systemImage: AppSymbol.gearshape,
                value: MainTab.settings, role: nil) {
                NavigationStack { SettingView().alwaysTransparentBars() }
            }
            Tab(NSLocalizedString("검색", comment: "Search"),
                systemImage: AppSymbol.magnifyingglass,
                value: MainTab.search, role: .search) {
                NavigationStack { MemoSearchView().alwaysTransparentBars() }
            }
        }
        // ⚠️ 물결은 **`TabView` 바깥쪽**에 얹는다. 탭바는 UIKit 이 콘텐츠 위에 그리므로
        //    탭 안쪽(무대)에 그리면 탭바 유리 뒤로 들어가 뭉개진다. 여기라야 위로 올라온다.
        //
        //    무대 머리말의 격자 버튼도 같이 빛난다(`SnippetsStyleSwitchButton.highlighted`).
        //    안내가 두 길을 적어 두었으니(버튼·탭 다시 누르기) 가리키는 것도 둘이어야 한다.
        .overlay {
            if showsSwitchHint, let frame = firstTabFrame {
                KeyRipple(shape: Capsule(), color: .accentColor, reach: 7)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        // 무대의 띠·격자 버튼과 **같은 곡선**으로 든다(`InAppKeyboardStage.guidanceCurve`).
        // 하나가 먼저 뜨면 같은 이야기가 따로 도착한 것으로 읽힌다.
        .animation(reduceMotion ? nil : InAppKeyboardStage.guidanceCurve, value: showsSwitchHint)
        // ⚠️ 자리는 **미리 재 두고 들고 있는다.** 안내가 켜질 때 재기 시작하면 재는 데 걸린
        //    시간만큼 탭바 물결만 늦게 떠서, 무대의 띠·격자 버튼과 따로 노는 그림이 된다.
        //    켜고 끄는 것은 `showsSwitchHint` 하나가 정하고, 자리는 늘 준비돼 있어야 한다.
        .onAppear { measureFirstTab() }
        // 탭 이름이 바뀌면(목록 ↔ 키보드) 칸 너비도 따라 바뀐다. 탭을 옮겨도 마찬가지.
        .onChange(of: snippetsStyleRaw) { _, _ in measureFirstTab() }
        .onChange(of: selection) { _, _ in measureFirstTab() }
        // 맥 메뉴·딥링크의 "클립보드 기록"이 갈 곳 - 탭에서 내려온 뒤로도 길은 남긴다.
        // ⚠️ 예전에는 이 알림을 **아무도 받지 않아** 메뉴를 눌러도 조용히 아무 일이 없었다.
        .sheet(isPresented: $showClipboardSheet) {
            NavigationStack { ClipboardList() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showClipboardHistory)) { _ in
            showClipboardSheet = true
        }
        // 새 단장 안내에서 "내가 아낀 시간 보기"를 누르면 그 탭으로 데려간다.
        // ⚠️ 안내는 **보여주는 데서 끝나면 안 된다** - 읽고 닫으면 아무것도 안 달라진다.
        .onReceive(NotificationCenter.default.publisher(for: .openUsageTab)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { selection = .usage }
        }
        // [디자인 불변식] 하단(탭바) 배경 언제나 투명 - 스크롤 엣지 이펙트는 하단만 숨김.
        // 상단은 시스템 기본(맨 위 투명 → 스크롤 시 glass 베일)에 맡긴다. 상단까지 숨기면
        // 인라인 타이틀이 콘텐츠와 겹치고 네비바 영역 터치가 막힌다.
        // (각 탭 루트의 alwaysTransparentBars()와 함께 동작; 지우면 회귀)
        .scrollEdgeEffectHidden(true, for: .bottom)
    }

    /// 탭바 첫 칸의 자리를 잰다.
    ///
    /// ⚠️ **화면이 다 바뀌고 나서** 잰다. 재는 일은 창의 뷰 계층을 훑는 일이라,
    ///    무대가 오르내리는 도중에 끼면 그 프레임에서 화면이 한 번 걸린다.
    ///    (`SnippetsTab.swapSettleDelay` 와 같은 이유로 기다린다)
    private func measureFirstTab() {
        DispatchQueue.main.asyncAfter(deadline: .now() + SnippetsTab.swapSettleDelay) {
            let measured = TabBarProbe.firstItemFrame()
            // ⚠️ 못 잰 값으로 **들고 있던 자리를 지우지 않는다.** 탭바가 잠깐 안 잡히는
            //    순간(화면 전환 중)에 지워 버리면 물결이 깜빡인다.
            guard let measured, measured != firstTabFrame else { return }
            firstTabFrame = measured
        }
    }
}

// MARK: - Memo Search (검색 탭, 순정 .searchable)

/// 검색 탭 - iOS 26 Tab(role: .search)와 짝을 이루는 순정 .searchable 화면.
/// 탭을 누르면 탭바가 검색 필드로 모핑되고, 여기서는 메모 제목/내용을 필터한다.
/// 보안 메모는 내용 검색·탭 복사에서 제외(값 노출 방지) - 제목으로만 찾을 수 있다.
struct MemoSearchView: View {
    @State private var query: String = ""
    @State private var memos: [Memo] = []
    /// 방금 복사한 메모 id - 행 오른쪽 아이콘을 잠시 체크로 바꿔 복사 피드백.
    @State private var copiedMemoId: UUID?
    @Environment(\.appTheme) private var theme

    private var results: [Memo] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return memos }
        return memos.filter { memo in
            memo.title.localizedCaseInsensitiveContains(q)
                || (!memo.isSecure && memo.value.localizedCaseInsensitiveContains(q))
        }
    }

    var body: some View {
        Group {
            if results.isEmpty {
                // 순정 빈 상태 - 검색어가 있으면 시스템 검색 빈 화면, 없으면 안내.
                if query.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("단축어 검색", comment: "Search empty state title"),
                        systemImage: AppSymbol.magnifyingglass,
                        description: Text(NSLocalizedString("제목이나 내용으로 저장한 단축어를 찾아보세요.", comment: "Search empty state description"))
                    )
                } else {
                    ContentUnavailableView.search(text: query)
                }
            } else {
                List(results) { memo in
                    Button {
                        copy(memo)
                    } label: {
                        searchRow(memo)
                    }
                    .buttonStyle(.plain)
                    .disabled(memo.isSecure)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
                .listStyle(.plain)
                // 하단만 숨김 - 상단은 시스템 glass 베일 유지(타이틀·콘텐츠 겹침 방지).
                .scrollEdgeEffectHidden(true, for: .bottom)
            }
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("검색", comment: "Search"))
        .searchable(text: $query, prompt: NSLocalizedString("검색", comment: "Search"))
        // ⚠️ **처음 한 번만** 읽는다. 예전에는 조건 없는 `onAppear` 였는데, `onAppear` 는
        //    이 뷰가 계층에 다시 들어올 때마다 다시 불린다. 그래서 목록을 스크롤하는
        //    도중에도 메모 파일 전체가 다시 디코딩됐다.
        //
        //    측정(Instruments, iPhone15,3 / iOS 26.5.2 / Release / 메모 505개 · 339 KB):
        //    스크롤 중 258 ms 짜리 행의 스택 뿌리가 바로 여기였다.
        //    `MemoSearchView.body` 의 `_AppearanceActionModifier` 안에서
        //    `JSONScanner.scanObject` 가 돌고 있었다.
        //
        //    바뀐 내용은 `.memoDataChanged` 로 듣는다. 이 화면 밖에서 단축어를 고쳐도
        //    검색 결과가 낡지 않는다. (목록 화면이 쓰는 것과 같은 신호다)
        .onAppear {
            guard memos.isEmpty else { return }
            reloadMemos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .memoDataChanged)) { _ in
            reloadMemos()
        }
    }

    private func reloadMemos() {
        memos = (try? MemoStore.shared.load(type: .memo)) ?? []
    }

    /// 검색 결과 행 - 메인 리스트와 같은 디자인 언어(테마 표면 카드, 타입 아이콘, 본문 크기 글자).
    private func searchRow(_ memo: Memo) -> some View {
        let style = typeStyle(memo)
        return HStack(spacing: 12) {
            Image(systemName: style.icon)
                .font(.body.weight(.semibold))
                .foregroundColor(style.color)
                .frame(width: 38, height: 38)
                .background(style.color.opacity(0.12))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(memo.title.templateAwareAttributed(theme: theme, font: .body.weight(.semibold)))
                    .font(.body.weight(.semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                let preview = MemoPreviewFormatter.preview(for: memo, resolvedType: memo.autoDetectedType)
                if !preview.isEmpty {
                    Text(preview.templateAwareAttributed(theme: theme, font: .subheadline))
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // 보안 메모는 복사 불가(값 노출 방지) - 자물쇠로 이유를 보여준다.
            if memo.isSecure {
                Image(systemName: AppSymbol.lockFill)
                    .font(.body)
                    .foregroundColor(theme.textFaint)
            } else {
                Image(systemName: copiedMemoId == memo.id ? AppSymbol.checkmarkCircleFill : AppSymbol.docOnDoc)
                    .font(.body)
                    .foregroundColor(copiedMemoId == memo.id ? Color.checkGreen : theme.textFaint)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMd, style: .continuous))
        .accessibilityHint(memo.isSecure
                           ? NSLocalizedString("보안 단축어는 목록에서 인증 후 사용할 수 있어요", comment: "Search: secure row hint")
                           : NSLocalizedString("탭하면 클립보드에 복사됩니다", comment: "Clipboard item copy hint"))
    }

    /// 타입별 아이콘·색 - 카드/키보드와 동일한 구분 언어(보안 회색·템플릿 보라·콤보 주황·이미지 초록).
    private func typeStyle(_ memo: Memo) -> (icon: String, color: Color) {
        if memo.isSecure { return (AppSymbol.lockFill, .gray) }
        if memo.isTemplate { return ("wand.and.stars", .purple) }
        if memo.isStack { return ("square.stack.3d.up.fill", .orange) }
        if memo.contentType == .image || memo.contentType == .mixed { return ("photo.fill", .green) }
        return ("doc.text.fill", .blue)
    }

    /// 비보안 메모만 복사(보안 메모는 버튼 자체가 비활성).
    private func copy(_ memo: Memo) {
        #if os(iOS)
        UIPasteboard.general.string = memo.value
        HapticManager.shared.success()
        withAnimation { copiedMemoId = memo.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedMemoId == memo.id {
                withAnimation { copiedMemoId = nil }
            }
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: String(format: NSLocalizedString("[%@] 복사됨", comment: ""), memo.title)
        )
        #endif
    }
}

#if DEBUG
import Combine

// MARK: - 배경 발행 잡기 (DEBUG 전용)

/// "Publishing changes from background threads is not allowed" 의 **범인을 찍는다.**
///
/// 이 경고는 어느 줄에서 났는지를 잘 알려주지 않는다. Xcode 가 붙여 주는 파일·행은
/// 발행을 촉발한 자리이지 발행한 자리가 아니라, 그 줄만 고쳐서는 안 사라진다
/// (실제로 두 번 헛짚었다).
///
/// 그래서 감시 대상의 `objectWillChange` 를 듣고, 메인이 아닐 때 **호출 스택을 통째로**
/// 찍는다. 그 스택 한 장이면 어느 경로인지 바로 나온다.
///
/// ⚠️ 원인을 찾으면 이 파일에서 통째로 지운다. 진단용 발판이지 기능이 아니다.
enum OffMainPublishDetector {
    nonisolated(unsafe) private static var bag: [AnyCancellable] = []

    static func watch<O: ObservableObject>(_ object: O, _ name: String)
    where O.ObjectWillChangePublisher == ObservableObjectPublisher {
        bag.append(object.objectWillChange.sink { _ in
            guard !Thread.isMainThread else { return }
            let stack = Thread.callStackSymbols.dropFirst(2).prefix(14)
                .map { "    " + $0 }
                .joined(separator: "\n")
            print("⚠️ [OFF-MAIN PUBLISH] \(name) 가 배경에서 발행했다\n\(stack)")
        })
    }

    /// 화면이 보는 싱글톤은 **전부** 건다. 다섯 개만 걸어 두면 못 걸린 하나가 범인일 때
    /// 또 헛짚는다 - 지난번이 그랬다.
    @MainActor
    static func watchKnownStores() {
        watch(MemoStore.shared, "MemoStore")
        watch(CategoryStore.shared, "CategoryStore")
        watch(QuickNoteStore.shared, "QuickNoteStore")
        watch(DraftStore.shared, "DraftStore")
        watch(ProStatusManager.shared, "ProStatusManager")
        watch(CloudKitBackupService.shared, "CloudKitBackupService")
        watch(StackExecutionService.shared, "ComboExecutionService")
        watch(SuggestionManager.shared, "SuggestionManager")
        watch(StoreManager.shared, "StoreManager")
    }
}
#endif
