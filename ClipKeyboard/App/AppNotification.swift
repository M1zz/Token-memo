//
//  AppNotification.swift
//  ClipKeyboard
//
//  자동 생성 가능 - 정적 Notification 이름 단일 출처(Single Source of Truth).
//  메인앱·키보드(ClipKeyboardExtension)·macOS(.tap) 3개 타겟이 공유한다.
//  하드코딩 리터럴 대신 항상 이 상수를 사용할 것.
//

import Foundation

extension Notification.Name {
    static let addTextEntry = Notification.Name("addTextEntry")
    /// 이미지 단축어를 눌렀다 - **앱 안(무대)에서만** 쓴다.
    /// object = 이미지 파일 이름(String), userInfo["memoId"] = UUID.
    /// (익스텐션에는 이미지를 넣을 자리가 없어 클립보드 복사로 끝난다. 앱 무대에는
    ///  입력창이 우리 것이라 붙여넣은 모습까지 보여줄 수 있다)
    static let addImageEntry = Notification.Name("addImageEntry")
    static let stackCompleted = Notification.Name("comboCompleted")
    static let stackItemExecuted = Notification.Name("comboItemExecuted")
    /// iCloud에서 데이터를 복원(자동/수동)한 뒤 열려 있는 화면을 새로고침.
    static let dataRestored = Notification.Name("dataRestored")
    /// 기존 사용자가 데모 샘플 체험을 수락해 샘플이 삽입됨 → 리스트 리로드 트리거
    static let demoSamplesInserted = Notification.Name("demoSamplesInserted")
    static let draftsChanged = Notification.Name("draftsChanged")
    static let filterChanged = Notification.Name("filterChanged")
    static let memoDataChanged = Notification.Name("MemoDataChanged")
    /// 단축어를 **방금 저장했다.** `object` 에 저장된 단축어의 `UUID`.
    ///
    /// ⚠️ `memoDataChanged` 와 다르다. 저쪽은 "무언가 바뀌었으니 다시 읽어라"이고,
    ///    이쪽은 "**이것**을 방금 만들었다"이다. 목록이 그 하나를 보여줄 자리로
    ///    옮겨 가려면 무엇이 저장됐는지 알아야 한다.
    static let memoSaved = Notification.Name("memoSaved")
    /// 키보드에서 "전체 접근 허용"이 필요한 동작을 시도했으나 꺼져 있음 → 안내 토스트.
    /// (클립보드 읽기·쓰기는 iOS가 전체 접근 없이는 막는다. 안내가 없으면 조용히 실패한다.)
    static let needsFullAccess = Notification.Name("needsFullAccess")
    /// 배운 캐럿 자리를 **처음** 적용했다. 키보드가 한 줄 안내를 띄운다.
    /// userInfo["memoId"] = UUID. 단축어당 한 번뿐이다.
    static let cursorMemoryApplied = Notification.Name("cursorMemoryApplied")
    /// 넣고 나서 매번 같은 자리를 고치는 것을 알아챘다. 키보드가 한 줄 제안을 띄운다.
    /// userInfo["memoId"] = UUID, userInfo["suggestion"] = `EditPattern.Suggestion.rawValue`.
    /// 단축어당 한 번뿐이다(`EditPattern.markAsked`).
    static let editPatternSuggestion = Notification.Name("editPatternSuggestion")
    static let openMainAppPaywall = Notification.Name("openMainAppPaywall")
    /// 빠른 메모(Inbox) 보관함이 변경됨(추가/삭제/승격) → 열려 있는 화면·배지 새로고침.
    static let quickNotesChanged = Notification.Name("quickNotesChanged")
    static let openMemoListWindow = Notification.Name("openMemoListWindow")
    /// 빠른 메모(Inbox) 보관함 화면을 연다(App Intent·Control Center·딥링크에서 트리거).
    static let openQuickNoteInbox = Notification.Name("openQuickNoteInbox")
    /// 빠른 메모 입력 시트를 연다(Control Center 컨트롤의 clipkeyboard://quicknote 딥링크).
    static let openQuickNoteAdd = Notification.Name("openQuickNoteAdd")
    static let reviewTriggerClipSaved = Notification.Name("reviewTriggerClipSaved")
    static let reviewTriggerStackCompleted = Notification.Name("reviewTriggerComboCompleted")
    /// 사용 기록 탭을 연다. 새 단장 안내가 "내가 아낀 시간 보기"로 데려갈 때 쓴다.
    ///
    /// ⚠️ 탭 선택은 `MainTabView` 안에만 있는 상태라, 시트를 띄우는 쪽에서 직접 못 바꾼다.
    ///    알림 한 줄이 두 화면을 잇는 가장 얇은 길이다.
    static let openUsageTab = Notification.Name("openUsageTab")
    /// 무대에서 쓴 글을 **보냈다.** 튜토리얼이 "눌러서 넣고 → 보내기"의 한 바퀴가
    /// 끝났는지를 이걸로 안다. (무대를 들고 있는 건 `InAppKeyboardStage` 라
    ///  걸음을 세는 `SnippetsTab` 이 직접 볼 수가 없다)
    static let stageMessageSent = Notification.Name("stageMessageSent")
    /// 콤보 키의 **오른쪽 → 를 눌러 다음 값으로 넘겼다.** userInfo 에 `memoId`.
    ///
    /// ⚠️ 콤보를 가르치는 데 이게 꼭 필요하다. 콤보 키는 왼쪽(값 넣기)과 오른쪽(다음 값)이
    ///    서로 다른 일을 하는데, 오른쪽은 **글이 하나도 안 들어간다** - 값만 바뀐다.
    ///    그래서 `.memoUsed` 로는 눌렀는지 알 길이 없어, 튜토리얼이 그 걸음에서 멈춰 있었다.
    static let stackValueAdvanced = Notification.Name("comboValueAdvanced")
    /// 키컬러를 바꿨다. 테마를 들고 있는 루트가 이걸 듣고 다시 그린다.
    ///
    /// ⚠️ 고른 값은 App Group UserDefaults 에 있고 `@AppStorage` 가 아닌 곳에서도
    ///    읽는다(`AppTheme.resolve`). 알림이 없으면 설정에서 색을 바꿔도 **그 화면만**
    ///    바뀌고 나머지는 다음 실행까지 예전 색으로 남는다.
    static let appAccentChanged = Notification.Name("appAccentChanged")
    /// "그거 아세요?"에서 읽고 나서 갈 곳을 골랐다. object 에 `DidYouKnow.Action`.
    ///
    /// ⚠️ 설정 안쪽(`DidYouKnowListView`)에서도 같은 화면이 뜨는데, 거기서는 목적지로
    ///    보내는 길을 직접 들고 있지 않다. 행선지를 아는 곳은 루트 하나뿐이라
    ///    알림으로 넘긴다.
    static let didYouKnowAction = Notification.Name("didYouKnowAction")
    /// 단축어 마트를 연다 - 페르소나에 맞춰 차려 둔 곳.
    static let openShortcutMart = Notification.Name("openShortcutMart")
    /// 한 번에 많은 단축어 정리하기(대량 가져오기)를 연다.
    static let openBulkImport = Notification.Name("openBulkImport")
    static let showClipboardHistory = Notification.Name("showClipboardHistory")
    static let showCloudBackup = Notification.Name("showCloudBackup")
    static let showMemoList = Notification.Name("showMemoList")
    static let showNewMemo = Notification.Name("showNewMemo")
    static let showPaywall = Notification.Name("showPaywall")
    static let showSettings = Notification.Name("showSettings")
    static let showTemplateInput = Notification.Name("showTemplateInput")
    static let templateInputComplete = Notification.Name("templateInputComplete")
}

// MARK: - 알림은 메인에서 쏜다

extension NotificationCenter {

    /// 알림을 **언제나 메인 스레드에서** 발행한다. 앱 안의 모든 발행은 이 문을 지난다.
    ///
    /// ⚠️ 왜 이게 필요한가: `NotificationCenter` 는 **쏜 스레드에서 그대로** 받는 쪽을 부른다.
    ///    받는 쪽이 대부분 화면이라는 게 문제다. `onReceive` 는 안에 `receive(on:)` 이 없어
    ///    알림이 배경에서 오면 **그 배경 스레드에서 클로저가 돈다.** 그 클로저는 거의 예외 없이
    ///    `@State` 를 고치거나 뷰모델을 다시 읽게 하므로, 결국 배경에서 발행이 일어난다.
    ///
    ///        Publishing changes from background threads is not allowed
    ///
    ///    이 경고의 파일·행은 **발행한 자리가 아니라 발행을 촉발한 자리**를 가리킨다.
    ///    그래서 `MemoStore.save` 안의 알림 한 줄이 범인으로 지목됐지만, 실제로 값을 바꾼 것은
    ///    그 알림을 받은 일곱 개의 화면이었다. 받는 쪽을 하나씩 고치는 길도 있으나
    ///    받는 곳은 계속 늘어난다. **쏘는 문을 하나로 좁히는 쪽이 끝이 있다.**
    ///
    /// ⚠️ 이미 메인이면 **그 자리에서** 쏜다. 눌러서 시트가 뜨는 것 같은 흐름의 순서를
    ///    지키기 위해서다. 미루는 것은 배경에서 쏠 때뿐이고, 그때 받는 일은 화면을
    ///    다시 읽는 것뿐이라 한 런루프의 지연이 보이지 않는다.
    ///
    ///    (예외: `MemoStore.postDataChanged` 는 메인이어도 미룬다. 저장 도중에 저장이
    ///     겹치는 재진입 때문이며, 이유는 그 함수 머리말에 적혀 있다.)
    ///
    /// 검사: `scripts/check_notification_main.sh`
    static func postOnMain(name: Notification.Name,
                           object: Any? = nil,
                           userInfo: [AnyHashable: Any]? = nil) {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
            }
        }
    }
}
