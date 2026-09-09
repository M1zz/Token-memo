//
//  DefaultsKey.swift
//  ClipKeyboard
//
//  자동 생성 가능 - 정적 UserDefaults 키 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation

enum DefaultsKey {
    static let autoBackupEnabled = "autoBackupEnabled"
    static let categoryBadgeNudgeDismissed = "categoryBadgeNudgeDismissed"
    /// "카테고리가 많아졌어요" 안내를 **마지막으로 띄웠을 때의 카테고리 수**(표준 UserDefaults).
    /// 0 이면 아직 안 물어본 것이다. 되풀이해 말하지 않되, 그 뒤로 또 크게 늘면 한 번 더 묻는다.
    /// ⚠️ 앱은 카테고리를 임의로 지우지 않는다. 이 값은 "물어봤다"는 표시일 뿐이다.
    static let categoryCleanupAskedAtCount = "category.cleanup.askedAtCount.v1"
    static let categoryFeatureEnabledV1 = "category.feature.enabled.v1"
    static let comboModelUnifyMigratedV1 = "comboModelUnifyMigrated_v1"
    /// 날인·편철·봉인 등 delight 연출과 햅틱의 마스터 스위치. 값이 없으면 켜짐(기본).
    /// App Group - 키보드 익스텐션도 같은 값을 읽어 입력 햅틱을 끈다.
    static let delightEffectsEnabled = "delight.effects.enabled.v1"
    /// 카드가 2초쯤 머물면 제목 아래에 내용이 살며시 맺혔다 사라지는 연출(App Group).
    /// ⚠️ 기본값은 **꺼짐**이다. 목록을 훑는 동안 카드마다 글이 맺혔다 흩어지면 눈이 쉴 곳이
    ///    없다. 보고 싶은 사람은 설정 > 화면과 표시에서 켠다.
    static let contentHintEnabled = "contentHintEnabled"
    /// 단축어별로 배운 "넣은 뒤 캐럿이 설 자리"(App Group, `[UUID문자열: CursorMemory.Learned]` JSON).
    /// ⚠️ 사용자의 본문에는 아무것도 안 쓴다. 배운 값은 전부 여기 따로 있다.
    ///    자세한 이유: ClipKeyboard/Service/CursorMemory.swift
    static let cursorMemory = "cursor.memory.v1"
    /// 한 번에 정리하기 권유를 사용자가 물렸다(App Group, Bool).
    /// ⚠️ 붙여넣기 순간의 제안은 이 값을 보지 않는다. 자세한 이유:
    ///    ClipKeyboard/Service/BulkImportNudge.swift
    static let bulkImportNudgeDismissed = "bulkImport.nudge.dismissed"
    /// 손으로 단축어를 만든 마지막 시각(App Group, epoch 초).
    static let bulkImportLastManualCreateAt = "bulkImport.lastManualCreateAt"
    /// 짧은 사이에 손으로 잇달아 만든 횟수(App Group, Int).
    static let bulkImportManualStreak = "bulkImport.manualStreak"
    static let didRemoveAds = "didRemoveAds"
    /// 칸 추가 상품으로 얻은 추가 단축어 칸수 (App Group, Int).
    /// ⚠️ 키보드 익스텐션은 StoreKit 을 못 보므로 앱이 결제 권한을 여기에 미러링한다.
    static let purchasedExtraSlots = "purchased.extraSlots"
    /// 단축어가 무료 한도 한 칸 앞(9개)에 **처음** 닿은 시각 (App Group, epoch 초).
    /// 반값 제안은 이 시각에서 일주일이 지난 뒤에 뜬다 - 닿자마자 들이밀면 한도를
    /// 미끼로 쓴 것처럼 보이고, 아직 이 앱이 자기에게 필요한지도 모르는 때다.
    static let discountOfferReachedLimitEdgeAt = "discount.offer.reachedLimitEdgeAt"
    /// 반값 제안을 이미 띄운 **기회들**(App Group, `DiscountOfferManager.Occasion.rawValue` 배열).
    /// 기회는 둘뿐이고(설치 직후·한도 한 칸 앞), 각각 한 번씩만 뜬다.
    static let discountOfferShownOccasions = "discount.offer.shownOccasions"
    static let enabledBuiltInCategoriesV1 = "enabledBuiltInCategories_v1"
    /// 앱을 처음 연 날 (standard UD, Date). 리뷰 요청·붙여넣기 안내·반값 제안이 모두 이 값을 본다.
    /// ⚠️ 읽기만 하는 자리에서 값을 쓰지 말 것 - 남의 초기화를 조용히 되돌린다.
    static let appInstallDate = "app_install_date"
    static let appLaunchCount = "appLaunchCount"
    /// 사용자가 고른 앱 언어 (App Group, `AppLanguage.rawValue`). 값이 없으면 기기 설정을 따른다.
    /// ⚠️ App Group 이어야 한다. 키보드 익스텐션은 다른 프로세스라 표준 UserDefaults 를 못 본다.
    static let appLanguage = "app.language.v1"
    /// 단축어별로 쌓인 "넣고 나서 고친 자리"(App Group, `[UUID문자열: EditPattern.Record]` JSON).
    /// ⚠️ 고친 **자리와 값**만 담는다. 사용자의 본문은 건드리지 않는다.
    ///    자세한 이유: ClipKeyboard/Service/EditPattern.swift
    static let editPatterns = "edit.patterns.v1"
    static let entries = "entries"
    static let fontSize = "fontSize"
    /// What's-New(새 기능) 시트를 마지막으로 보여준 기능 버전. 다르면 업데이트 유저에게 1회 노출.
    static let lastSeenWhatsNewVersion = "lastSeenWhatsNewVersion"
    static let hiddenCategoryTabsV1 = "hiddenCategoryTabs_v1"
    static let kbBeaconLastUse = "kb.beacon.lastUse"
    static let kbBeaconPendingCount = "kb.beacon.pendingCount"
    /// 키보드 비콘 누적 사용 횟수 (App Group) - flush 때마다 pendingCount를 더한다. 사용 통계 지표용.
    static let kbBeaconTotalCount = "kb.beacon.totalCount"
    /// 앱 **밖에서** `memos.data` 를 고친 시각 (App Group, epoch 초).
    /// ⚠️ 지금은 공유 익스텐션이 찍는다. `memos.data` 는 메인 앱이 통째로 덮어쓰는 파일이라,
    ///    앱이 낡은 목록을 들고 있다가 저장하면 밖에서 넣은 단축어가 **사라진다.**
    ///    앱은 돌아올 때 이 값을 보고 다시 읽는다(`ClipKeyboardListViewModel.onSceneResume`).
    static let memosExternalChangeAt = "memos.externalChangeAt"
    /// 앱이 마지막으로 위 변경을 반영한 시각 (standard UD) - 같은 변경을 두 번 읽지 않기 위한 표식.
    static let memosExternalChangeSeenAt = "memos.externalChangeSeenAt"

    /// 키보드를 쓴 **날짜별** 횟수 (App Group, `"yyyy-MM-dd"` → Int).
    /// ⚠️ pendingCount와 역할이 다르다 - 저쪽엔 "언제"가 없어서, 앱을 2주 만에 열면
    ///    그 2주가 통째로 '앱을 연 날 하루'로 뭉친다. 키보드만 쓰는 사람의 활동일을
    ///    소급해서 복원하려고 날짜를 따로 남긴다. 자세한 건 `KeyboardDayLedger`.
    static let kbBeaconDayCounts = "kb.beacon.dayCounts"
    static let keyboardExtensionDidLoad = "keyboard_extension_did_load"
    static let keyboardKoreanEnabled = "keyboardKoreanEnabled"
    /// 생활 레이어 프리셋(LivingSkin rawValue) - 카드 위에 사는 것. 값이 없으면 `.none`.
    /// ⚠️ 앱 전용이다. 키보드 익스텐션은 메모리 상한 때문에 이 레이어를 그리지 않는다.
    static let livingSkin = "livingSkin.v1"
    /// 단축어 탭이 무엇을 보여주는가 - `SnippetsTabStyle` rawValue("list" / "keyboard").
    /// ⚠️ 기존 사용자는 값이 없으면 **목록**이다. 쓰던 사람의 첫 화면이 업데이트로 바뀌면 안 된다.
    ///    새 설치에만 첫 실행에서 `keyboard`를 뿌린다(ClipKeyboardApp.seedSnippetsTabStyle).
    static let snippetsTabStyle = "snippetsTabStyle.v1"
    /// 단축어를 만들 때 "쓸 때 채우는 칸" 서랍을 펼쳐 두는가.
    ///
    /// ⚠️ **기본은 닫힘.** 예전에는 내용 칸에 커서만 가면 파란 버튼 아홉 개가 통째로
    ///    올라왔다. 대부분은 그냥 글을 적으러 온 사람이라, 그 줄은 도움이 아니라
    ///    "이걸 다 골라야 하나" 라는 물음이었다.
    ///
    /// ⚠️ 그렇다고 한 번 편 사람에게 매번 다시 닫아 주지는 않는다. 빈칸을 쓰는 사람은
    ///    거의 매번 쓰므로, 편 채로 두는 것이 그 사람의 선택이다.
    static let contentTokenBarExpanded = "memoAdd.tokenBar.expanded.v1"
    /// 사용자가 고른 **키컬러**(`AppAccent` rawValue). 값이 없으면 `.ink`(흑백).
    ///
    /// ⚠️ **App Group 이다.** 키보드 익스텐션과 위젯이 같은 값을 읽어야 앱과 키보드가
    ///    두 색으로 갈리지 않는다. 표준 UserDefaults 에 두면 앱만 바뀐다.
    static let appAccent = "app.accent.v1"
    /// 키보드 화면을 한 번 권했는가(기존 사용자 1회 제안). 다시 묻지 않기 위한 표식.
    static let keyboardStageOffered = "keyboardStageOffered.v1"
    /// 배우는 장(단축어·템플릿·콤보)을 다 지났는가.
    /// ⚠️ 개별 완료 표식만으로는 판단하지 않는다 - 가리킬 것이 없어 조용히 건너뛴 장이 있으면
    ///    영영 안 끝난 것으로 남는다. 챕터 기계가 "더 없다"고 알려줄 때 켠다.
    static let tutorialChaptersDone = "tutorialChaptersDone.v1"
    /// 직접 단축어를 하나 만들어 보는 마지막 걸음을 지났는가(만들었든 미뤘든).
    static let tutorialMakeOwnDone = "tutorialMakeOwnDone.v1"
    /// 튜토리얼이 쓰던 샘플을 **치울지 물어봤는가.** 답이 무엇이든 한 번만 묻는다.
    static let tutorialSampleCleanupAsked = "tutorialSampleCleanupAsked.v1"
    /// 튜토리얼을 **끝낸 시각**(초, 1970 기준). 0이면 아직 걷는 중이거나 걷지 않는 사람.
    /// 무대의 키보드 켜기 띠가 한 호흡 쉬었다 뜨는 기준(`KeyboardSetupBannerGate`).
    static let tutorialFinishedAt = "tutorialFinishedAt.v1"
    /// 튜토리얼이 끝나던 그 실행의 앱 실행 횟수. 지금 실행이 이보다 크면 **다시 연 것**이다.
    static let tutorialFinishedAtLaunch = "tutorialFinishedAtLaunch.v1"
    /// 새 단축어 화면에서 칸을 하나씩 짚어 주는 안내를 **손수 껐는가.**
    /// ⚠️ "만들다 말고 나갔다"와 "안내가 필요 없다"는 다르다. 앞은 다시 데려와야 하고,
    ///    뒤는 다시 걸리적거리면 안 된다. 그래서 끈 것만 여기 남긴다.
    static let tutorialMakeOwnCoachSkipped = "tutorialMakeOwnCoachSkipped.v1"
    /// 키보드 켜기 안내를 **마지막으로 밀어 둔 시각**(초, 1970 기준).
    ///
    /// ⚠️ 더는 읽지 않는다. 키보드 켜기가 첫 흐름을 막고 서던 시절의 값으로, 지금은
    ///    무대의 띠가 켜질 때까지 그냥 떠 있는다(`SnippetsOnboardingStep` 주석).
    ///    **지우지는 않는다** - 예전 버전에서 올라온 기기에 남아 있는 값이라, 키를
    ///    없애도 기기에서 사라지지 않고 이름만 잃는다.
    static let keyboardSetupSnoozedAt = "keyboardSetupSnoozedAt.v1"
    /// 지금 무대에서 **가리키고 있는** 단축어 id(UUID 문자열). 그 키가 빛나고,
    /// **그걸 눌러야** 그 장이 끝난다. 누르면 비운다.
    static let tutorialFirstUseMemoId = "tutorialFirstUseMemoId.v1"
    /// 첫 흐름에서 **키보드 켜기 안내까지** 지나왔는가(끝냈든 건너뛰었든).
    /// 없으면 첫 단축어를 만든 직후 키보드 설치 안내가 곧바로 이어진다.
    static let keyboardSetupTutorialDone = "keyboardSetupTutorialDone.v1"
    /// 키캡 물성 프리셋(KeyboardSkin rawValue). 값이 없으면 `.standard`.
    /// App Group - 익스텐션이 렌더에 쓴다. 색은 건드리지 않는다(테마·커스텀 색이 담당).
    static let keyboardSkin = "keyboardSkin.v1"
    /// 키 이름이 길 때 접는 방식(KeyLabelTruncation rawValue). 값이 없으면 `.middle`.
    /// App Group - 익스텐션이 렌더에 쓴다.
    static let keyLabelTruncation = "keyLabelTruncation.v1"
    static let keyboardPasteCount = "keyboard_paste_count"
    static let keyboardSecurePinHash = "keyboard_secure_pin_hash"
    /// 키보드 위줄에 리턴(보내기) 키를 세울지. App Group - 익스텐션이 읽는다. 기본 켬.
    static let keyboardShowReturnKey = "keyboardShowReturnKey"
    /// 키보드에 검색줄을 세울지. App Group. 기본 끔(자리를 한 줄 먹는다).
    static let keyboardShowSearch = "keyboardShowSearch"
    /// 키보드에 '최근 사용' 줄을 세울지. App Group.
    ///
    /// ⚠️ **값이 없는 것과 false 가 다르다.** 값이 없으면 "아직 안 정했다"는 뜻이고,
    ///    그때는 단축어 수를 보고 `KeyboardDisplayDefaults` 가 알아서 정한다.
    ///    그래서 이 키는 `bool(forKey:)` 로 읽으면 안 된다(없는 것이 false 로 뭉개진다).
    static let keyboardShowRecent = "keyboardShowRecent"
    /// 키보드를 마지막으로 닫을 때 보고 있던 갈래 페이지 번호. App Group.
    ///
    /// 왜 저장하나: 익스텐션은 앱을 옮길 때마다 새로 만들어지고 iOS 가 먼저 죽인다.
    /// `@State` 로 두면 카톡에서 한 번, 메일에서 한 번, 사파리에서 한 번, 하루에도
    /// 수십 번 같은 갈래를 다시 찾아 들어가야 한다.
    /// 갈래가 지워져 번호가 넘치는 경우는 읽는 쪽에서 잘라 낸다.
    static let keyboardLastCategoryPage = "keyboardLastCategoryPage.v1"
    static let keyboardTypingLang = "keyboardTypingLang"
    static let koreanEnabledMigratedV1 = "koreanEnabledMigrated_v1"
    static let lastBackupDate = "lastBackupDate"
    static let memoCopyCount = "memoCopyCount"
    /// '순서 바꾸기'로 지정한 수동 순서(메모 id 문자열 배열). App Group - 키보드 익스텐션도 이 순서를 따른다.
    static let memoManualOrderV1 = "memoManualOrder_v1"
    /// 수동 순서 활성 여부. true면 즐겨찾기 상단 고정 대신 저장된 순서 그대로 정렬.
    static let memoManualOrderActiveV1 = "memoManualOrderActive_v1"
    /// 온보딩이 심어 준 샘플 단축어의 id 목록.
    ///
    /// ⚠️ App Group 이다. 예전에는 표준 UserDefaults 에 있었는데, 그러면 키보드
    ///    익스텐션이 "심어 준 것" 과 "직접 만든 것" 을 구분하지 못해 남은 칸을
    ///    앱과 다르게 센다. 한도를 세는 두 쪽이 같은 표를 봐야 한다.
    static let sampleMemoIdsV1 = "sampleMemoUUIDs_v1"
    static let onboarding = "onboarding"
    /// 맥 앱의 온보딩을 마쳤는지 (standard UD).
    /// ⚠️ **맥 전용이지만 iOS 원본에 둔다.** 이 파일은 맥 저장소가 그대로 복사해 가는 원본이라
    ///    (`ClipKeyboardMac/scripts/sync_shared.sh`), 여기 없으면 동기화가 맥 빌드를 깨뜨린다.
    ///    iOS 의 온보딩 상태는 위의 `onboarding` 이다.
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let pasteTipDismissed = "pasteTipDismissed"
    /// 클립보드 화면 첫 진입 시 붙여넣기 허용 안내 알림을 한 번 띄웠는지 여부.
    static let pastePermissionPromptShownV1 = "pastePermissionPromptShown_v1"
    /// Siri/단축어 OpenQuickNoteInboxIntent가 켠 "보관함 열기" 보류 플래그(앱 활성화/onAppear 시 소비).
    static let pendingOpenQuickNoteInbox = "pendingOpenQuickNoteInbox"
    /// Control Center 빠른 메모 컨트롤·quicknote 딥링크가 켠 "빠른 메모 입력 시트 열기" 보류 플래그.
    /// 위젯 타겟은 같은 문자열 리터럴 사용(QuickNoteControl.swift).
    static let pendingQuickNoteAdd = "pendingQuickNoteAdd"
    static let proValueNudgeDismissedV1 = "proValueNudgeDismissed_v1"
    static let recentEmojis = "recentEmojis"
    static let recentlyUsedCategories = "recentlyUsedCategories"
    static let reviewBannerDismissed = "review_banner_dismissed"
    static let reviewBannerLaterDate = "review_banner_later_date"
    static let sampleTemplateFlagsMigratedV1 = "sampleTemplateFlagsMigrated_v1"
    static let secureMemoEncryptionMigratedV1 = "secureMemoEncryptionMigrated_v1"
    /// 앱이 실제로 잰 **시스템 키보드 높이** 장부(App Group, `[화면키: Double]`).
    /// 화면키는 `"390x844-P"` 처럼 크기와 방향을 함께 담는다.
    /// ⚠️ 적는 쪽은 메인 앱뿐이다. 익스텐션이 적으면 자기 높이를 정답으로 삼는 고리가 생긴다.
    ///    자세한 이유: ClipKeyboard/Service/KeyboardHeightBook.swift
    static let systemKeyboardHeights = "systemKeyboardHeights.v1"
    static let showVisualCues = "showVisualCues"
    static let useCaseSelection = "useCaseSelection"
    static let userCategoryColorsV1 = "userCategoryColors_v1"
    static let userCategoryIconsV1 = "userCategoryIcons_v1"
    static let userDefinedCategoriesV1 = "userDefinedCategories_v1"
    static let visualCuesMigratedV1 = "visualCuesMigrated_v1"
    /// v4.3.6 "메모 심볼 기본 숨김" 1회 리셋 플래그 (standard UD)
    static let visualCuesDefaultOffV436 = "visualCuesDefaultOff_v436"

    // MARK: - Pro / 그랜드파더링 / 템플릿 (iOS·macOS 공유 - 이전엔 타겟별 중복 정의)
    static let proStatus = "clipkeyboard_is_pro"
    static let wasProAtV3 = "clipkeyboard_was_pro_at_v3"
    static let existingFreeUser = "clipkeyboard_existing_free_user"
    static let v4GraceMemos = "clipkeyboard_v4_grace_memos"
    static let v4GraceBannerDismissed = "clipkeyboard_v4_grace_banner_dismissed"
    static let v4GrandfatherBootstrapDone = "clipkeyboard_v4_grandfather_bootstrap_done"
    static let trialStartedAt = "clipkeyboard_trial_started_at"
    static let trialLastSeen = "clipkeyboard_trial_last_seen"
    static let userTimezone = "clipkeyboard_user_timezone"
    static let userCurrency = "clipkeyboard_user_currency"
    /// `{날짜}` 를 어떤 모양으로 넣을지 (App Group - 키보드도 같은 값을 읽는다).
    /// 값은 `DateTokenFormat.rawValue`. 없으면 `.automatic`(언어에 맞춰 고름).
    static let templateDateFormat = "clipkeyboard_template_date_format"
    /// `{시간}` 을 어떤 모양으로 넣을지. 값은 `TimeTokenFormat.rawValue`.
    static let templateTimeFormat = "clipkeyboard_template_time_format"
    /// 사용자가 직접 적어 넣은 `{날짜}` 서식들 (JSON `[String]`, ICU 패턴).
    /// 준비된 보기로 모자란 사람이 자기 모양을 만들어 쓴다.
    static let templateDateCustomFormats = "clipkeyboard_template_date_custom_formats"
    /// 빈칸을 채울 때 **한 칸만 펼치고 나머지는 접을지** (App Group, 기본 켬).
    ///
    /// 왜 있나: 키보드는 약 290pt 다. 머리 줄과 미리보기를 빼면 182pt 가 남는데
    /// 빈칸 한 칸이 102pt 라 1.8개밖에 안 보인다. 빈칸이 넷인 템플릿(송금 양식)은
    /// 절반도 안 보여서 계속 굴려야 한다. 접으면 세 개가 한눈에 들어온다.
    /// 끄면 예전처럼 전부 펼친다.
    static let keyboardCompactPlaceholders = "clipkeyboard_keyboard_compact_placeholders"
    /// 사용자가 직접 적어 넣은 `{시간}` 서식들 (JSON `[String]`).
    static let templateTimeCustomFormats = "clipkeyboard_template_time_custom_formats"

    /// 마스터(개발자) 모드 - 설정 > 앱 정보의 버전 행 7번 탭으로 토글 (standard UD)
    static let masterModeEnabled = "masterModeEnabled"

    // MARK: - 익명 사용 통계 (FeedbackHub 전송, 항상 켜짐)
    /// 이벤트 이름별 마지막 전송 시각 키 접두사 - `usage.event.lastSent.<이름>` (standard UD)
    static let usageEventLastSentPrefix = "usage.event.lastSent."

    // MARK: - 피드백 넛지
    /// 피드백 넛지 "다시 보지 않기" - 구버전 영구 옵트아웃 Bool(마이그레이션용으로만 읽음, standard UD)
    static let feedbackNudgeOptOut = "feedbackNudgeOptOut"
    /// 피드백 넛지 "다시 보지 않기"를 누른 시각(timeIntervalSince1970) - 6개월 유예 후 재노출 (standard UD)
    static let feedbackNudgeOptOutDate = "feedbackNudgeOptOutDate"
    /// 피드백 넛지를 마지막으로 보여준 실행 횟수 (standard UD)
    static let feedbackNudgeLastShownLaunch = "feedbackNudgeLastShownLaunch"

    // MARK: - Apple Intelligence (온디바이스 AI, iOS 26+)
    /// AI 클립보드 재분류 토글 (App Group, 기본 ON - 지원 기기에서만 동작)
    static let aiClassificationEnabled = "aiClassificationEnabled"
    /// 붙여넣을 앱 예측 → 단축 액션 제안 토글 (App Group, 기본 ON)
    static let aiActionSuggestionsEnabled = "aiActionSuggestionsEnabled"
    /// 기본 번역 대상 언어 (BCP-47, `Locale.Language.minimalIdentifier`. App Group)
    static let aiTranslationTargetLang = "aiTranslationTargetLang"

    // MARK: - 메모 실시간 동기화 (CKSyncEngine)
    static let memoSyncEnabled = "memoSyncEnabled"
    /// iCloud KV 에 켜져 있던 동기화 설정을 **이 기기가 받아들일지** 한 번 판정했는가 (App Group).
    /// 판정 자체를 한 번만 하기 위한 표식이라, 결과(켬/끔)는 `memoSyncEnabled` 에 남는다.
    static let memoSyncCloudAdoptedV1 = "memoSync.cloudAdopted.v1"
    static let syncEngineState = "sync.engine.state"
    static let syncShadow = "sync.shadow"
    static let syncTombstones = "sync.tombstones"
    /// 마지막으로 원격 변경을 이 기기에 적용한 시각과 건수 (App Group) - 동기화 상태 화면 표시용
    static let syncLastPullAt = "sync.lastPullAt"
    /// 사진 위를 문질러 글자를 담는 화면의 안내 문구를 보여준 횟수.
    /// 몇 번 해보면 몸이 먼저 기억한다 - 그다음부터 안내는 자리만 차지한다.
    static let smearHintShownCount = "smear.hint.shownCount"
    static let syncLastPullCount = "sync.lastPullCount"
    /// 마지막으로 이 기기 변경을 올린 시각과 건수 (App Group)
    static let syncLastPushAt = "sync.lastPushAt"
    static let syncLastPushCount = "sync.lastPushCount"
    /// 마지막으로 원격 확인(fetch)을 마친 시각 - 받을 게 없어도 갱신된다 (App Group)
    static let syncLastCheckAt = "sync.lastCheckAt"
    /// 마지막 동기화 오류 메시지와 시각 (App Group)
    static let syncLastError = "sync.lastError"
    static let syncLastErrorAt = "sync.lastErrorAt"
    /// 동기화 사용 권한 - iOS가 `ProFeatureManager.hasFullAccess`(결제·그랜드파더·체험 전부)를
    /// 이 키에 미러링한다. 공유 엔진은 iOS 전용 타입에 의존할 수 없어 이 키로 판단한다.
    static let syncEntitled = "clipkeyboard_sync_entitled"

    // MARK: - 리스트 배경 이미지
    /// 선택된 배경 이미지 에셋 이름 (빈 문자열 = 배경 없음, App Group) - 모든 탭 기본값
    static let listBackgroundImageV1 = "listBackgroundImage_v1"
    /// 탭별 배경 덮어쓰기 [CategoryTab.storageKey: 에셋 이름] ("" = 이 탭만 배경 없음, App Group)
    static let listBackgroundPerTabV1 = "listBackgroundPerTab_v1"
    /// "새 배경 써보시겠어요?" 1회 제안을 이미 답했는지 (App Group)
    static let backgroundOfferResolvedV1 = "backgroundOfferResolved_v1"

    // MARK: - 처음 쓰는 사람이 지나는 길
    /// 환영 화면("바로 써 볼 수 있게 준비해 뒀어요")을 지났는지. 시작했든 건너뛰었든.
    ///
    /// ⚠️ 옛 키(`firstShortcut.done.v1`)를 그대로 쓴다. 4.4.x 에서 첫 단축어를 이미 만들고
    ///    지나온 사람에게 새 키를 주면 **환영 화면이 다시 뜬다** - 그 사람에게는 다 아는 이야기다.
    static let tutorialWelcomeDone = "firstShortcut.done.v1"
    /// 4.4.4 기본 스킨 씨앗을 이미 뿌렸는지(1회). 두 번 뿌리면 사용자가 바꾼 걸 되돌린다.
    static let skinSeededV444 = "skinSeeded.v444"
    /// 이 기기가 4.4.4 에서 **처음** 시작했는지. 금고 스킨 기본값과 튜토리얼이
    /// 같은 판단을 근거로 움직이게 하는 표식이다.
    static let startedFreshV444 = "startedFresh.v444"
    /// 준비된 단축어를 한 번 눌러 봤는지(또는 가리킬 것이 없어 건너뛰었는지).
    static let tutorialSnippetDone = "tutorial.snippet.done.v1"
    /// 준비된 템플릿을 한 번 써 봤는지.
    static let tutorialTemplateDone = "tutorial.template.done.v1"
    /// 준비된 콤보를 한 번 써 봤는지.
    static let tutorialComboDone = "tutorial.combo.done.v1"
    /// 콤보 장 **안쪽**의 어느 걸음에 서 있는가(`ComboTutorialStep.rawValue`). 빈 값이면 그 장이 아니다.
    ///
    /// ⚠️ 저장해 두어야 한다. 콤보 장은 다섯 걸음이라 그 중간에 앱을 끄는 일이 실제로 생기는데,
    ///    기억해 두지 않으면 다시 열었을 때 가리키는 키는 그대로인데 걸음만 사라져
    ///    **눌러도 아무 일이 안 일어나는 화면**이 된다.
    static let tutorialComboStep = "tutorial.combo.step.v1"
    /// 목록과 키보드를 오가는 법을 한 번 알려 줬는지.
    ///
    /// ⚠️ 이 앱의 단축어 탭은 **화면이 둘**(목록 · 키보드 무대)인데, 그걸 아무도 안 알려 줬다.
    ///    무대에서 시작한 사람은 자기 목록이 어디 있는지 모른 채로 남고, 목록에서 시작한
    ///    사람은 무대를 아예 못 본다. 튜토리얼을 다 지난 뒤 **한 번만** 짚어 준다.
    static let tutorialSwitchHintSeen = "tutorial.switchHint.seen.v1"

    // MARK: - 런치 안전장치 (LaunchGuard)
    /// 지금 진행 중인 런치 단계 `"<tier>:<stage>"`. 런치를 끝내면 지운다 (App Group).
    /// 다음 런치에 이 값이 남아 있으면 **직전 런치가 그 자리에서 죽었다**는 뜻이다.
    static let launchStageInFlight = "launch.stage.inFlight"
    /// 마지막으로 런치를 못 끝낸 단계 이름 - 같은 자리에서 되풀이하는지 판정한다 (App Group).
    static let launchLastStalledStage = "launch.stage.lastStalled"
    /// 연속으로 런치를 못 끝낸 횟수. 끝까지 가면 0으로 돌아간다 (App Group).
    static let launchFailStreak = "launch.failStreak"
    /// 되풀이해 멈춘 탓에 이번 빌드에서는 시작하지 않는 단계 이름들 (App Group).
    static let launchQuarantinedStages = "launch.quarantinedStages"
    /// 격리 목록을 기록한 앱 버전. 버전이 바뀌면 목록을 비우고 다시 시도한다 (App Group).
    static let launchQuarantineVersion = "launch.quarantineVersion"

    // MARK: - 데모 데이터
    /// 데모(샘플 페르소나) 데이터가 켜져 있는지 (App Group - 키보드도 같은 데이터를 본다).
    /// 켤 때 원본을 demo.backup.data로 백업하고, 끄면 복원한다. DemoDataService 참고.
    static let demoDataActive = "demoDataActive_v1"
}

// MARK: - 키보드 표시 옵션의 "아직 안 정했다"

/// 사람이 아직 손대지 않은 표시 옵션을 **단축어 수를 보고** 정해 준다.
///
/// 왜 필요한가: '최근 사용' 줄은 찾는 시간을 없애 주는 기능인데 기본이 꺼짐이었고,
/// 켜는 곳은 설정 > 키보드 레이아웃 > 표시 옵션, 두 단계 아래였다. 그래서 그 줄을
/// 켜 본 사람만 이득을 봤다. 반대로 단축어가 서넛뿐인 사람에게는 그 줄이 자리만 먹는다.
/// 둘 다 맞는 말이라 **개수로 가른다.**
///
/// ⚠️ 값이 **없는 것**과 **false** 는 다르다. 없으면 "아직 안 정했다", false 는
///    "꺼 달라고 했다"이다. 한 번 손대면 그 뜻을 끝까지 지킨다. 그래서 이 판정은
///    `bool(forKey:)` 가 아니라 `object(forKey:)` 로 시작한다.
///    설정 화면과 키보드가 **같은 답**을 보려면 양쪽 다 여기를 거쳐야 한다.
enum KeyboardDisplayDefaults {

    /// 이 수를 넘으면 '최근 사용' 줄이 저절로 선다.
    ///
    /// 12는 한 화면에 들어가는 키 수(3열 x 4줄 남짓)에서 왔다. 스크롤을 해야
    /// 보이는 것이 생기는 지점부터 "찾는 일"이 시작되기 때문이다.
    static let recentSectionThreshold = 12

    /// '최근 사용' 줄을 세울지. 사람이 정한 값이 있으면 그것, 없으면 개수로 정한다.
    /// - Parameter memoCount: 사용자가 가진 단축어 수.
    static func showRecentSection(memoCount: Int) -> Bool {
        if let chosen = AppGroup.defaults?.object(forKey: DefaultsKey.keyboardShowRecent) as? Bool {
            return chosen
        }
        return memoCount >= recentSectionThreshold
    }

    /// 사람이 이 옵션을 직접 정한 적이 있는지. 설정 화면의 안내 문구가 이걸 본다.
    static var hasChosenRecentSection: Bool {
        AppGroup.defaults?.object(forKey: DefaultsKey.keyboardShowRecent) != nil
    }

    /// 설정 화면에서 토글을 움직였을 때. 이 순간부터 개수 판정은 끝난다.
    static func chooseRecentSection(_ on: Bool) {
        AppGroup.defaults?.set(on, forKey: DefaultsKey.keyboardShowRecent)
    }
}
