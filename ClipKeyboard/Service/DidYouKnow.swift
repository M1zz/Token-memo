//
//  DidYouKnow.swift
//  ClipKeyboard
//
//  **그거 아세요?** - 이 앱이 자기 자랑을 하는 유일한 자리.
//
//  왜 필요한가: 이 앱의 좋은 점은 대부분 **안 보이는 곳**에 있다. 서버가 없다는 것,
//  설정 어딘가에 있는 기능들, 길게 누르면 되는 동작들. 화면에 안 나오는 것은
//  아무리 좋아도 없는 것과 같고, 설정을 뒤져 볼 사람은 백 명 중 몇 명이다.
//
//  ⚠️ **한 번에 하나만 말한다.** 기능 목록을 펼쳐 보이면 하나도 안 남는다.
//     한 번에 한 가지, 며칠에 한 번.
//
//  ⚠️ **본 것은 다시 안 나온다.** 같은 것을 되풀이하면 그때부터는 광고로 읽힌다.
//     다 봤으면 그냥 멈춘다 - 처음으로 돌아가지 않는다.
//
//  ⚠️ **자랑이 아니라 쓸모여야 한다.** 각 항목은 읽고 나서 **할 수 있는 일**이
//     하나 생겨야 한다(설정을 켜거나, 길게 눌러 보거나, 안심하거나).
//     "우리 앱은 빠릅니다" 같은 것은 여기 넣지 않는다.
//

import Foundation

/// 한 번에 하나씩 알려 주는 이야기.
struct DidYouKnow: Identifiable, Equatable {
    /// 본 것을 기억하는 열쇠. **문구가 바뀌어도 이 값은 그대로 둔다** -
    /// 바꾸면 이미 본 사람에게 다시 뜬다.
    let id: String
    /// 한 줄 제목.
    let title: String
    /// 두세 줄 설명.
    let body: String
    /// SF Symbol.
    let symbol: String
    /// 읽고 나서 갈 수 있는 곳(있으면). 없으면 알기만 하면 되는 이야기다.
    var action: Action?

    enum Action: Equatable {
        /// 설정 화면으로.
        case openSettings
        /// 키보드 미리보기(무대)로.
        case openStage
        /// 백업 화면으로.
        case openBackup
        /// 단축어 목록으로 - 거기 + 안에 여러 개를 한 번에 담는 길이 있다.
        case openList
        /// 빠른 메모 보관함으로.
        case openQuickNoteInbox
        /// 단축어 마트로 - 페르소나에 맞춰 차려 둔 곳.
        case openShortcutMart
        /// 한 번에 많은 단축어 정리하기로.
        case openBulkImport

        var localizedLabel: String {
            switch self {
            case .openSettings:
                return NSLocalizedString("설정에서 보기", comment: "Did-you-know action: settings")
            case .openStage:
                return NSLocalizedString("키보드에서 해보기", comment: "Did-you-know action: stage")
            case .openBackup:
                return NSLocalizedString("백업 화면 열기", comment: "Did-you-know action: backup")
            case .openList:
                return NSLocalizedString("단축어 목록 열기", comment: "Did-you-know action: list")
            case .openQuickNoteInbox:
                return NSLocalizedString("보관함 열기", comment: "Did-you-know action: inbox")
            case .openShortcutMart:
                return NSLocalizedString("골라 담으러 가기", comment: "Did-you-know action: mart")
            case .openBulkImport:
                return NSLocalizedString("한 번에 옮기기", comment: "Did-you-know action: bulk import")
            }
        }
    }
}

// MARK: - 할 이야기들

extension DidYouKnow {

    /// 순서에 뜻이 있다. **가장 안심되는 것이 먼저다** - 이 앱에 개인정보를 적어도 되는지가
    /// 첫 며칠의 가장 큰 물음이고, 그 답을 못 들으면 나머지 기능은 쓸 일이 없다.
    ///
    /// ⚠️ 계산 프로퍼티다. 고른 페르소나에 따라 **한 항목의 내용이 달라진다**
    ///    (`personaPicks`). 고정 배열로 두면 노마드에게 학생용 갈래를 권하게 된다.
    static var all: [DidYouKnow] {
        var items = fixed
        // 안심시키는 첫 이야기 **바로 다음**에 둔다. 나를 위해 골라 뒀다는 말은
        // 일찍 들을수록 좋지만, 여기가 안전한 곳인지부터 답하는 것이 먼저다.
        items.insert(personaPicks, at: 1)
        return items
    }

    /// 이 페르소나에게 뭘 골라 뒀는지.
    ///
    /// ⚠️ 권하는 목록과 이 문장은 **같은 곳**(`SuggestionManager`)에서 나온다.
    ///    화면에 그 갈래가 안 보이는 사람에게 골라 뒀다고 말하면 거짓말이 된다.
    static var personaPicks: DidYouKnow {
        let persona = CategoryStore.shared.selectedPersona ?? .general
        let categories = SuggestionManager.recommendedCategories(for: persona)
        let titles = SuggestionManager.recommendedTitles(for: persona)

        let categoryList = categories.joined(separator: ", ")
        let sample = titles.prefix(2).joined(separator: ", ")

        return DidYouKnow(
            // ⚠️ 열쇠에 페르소나를 넣지 않는다. 넣으면 페르소나를 바꿀 때마다
            //    같은 이야기를 처음 보는 것으로 쳐서 또 뜬다.
            id: "persona-picks",
            title: String(format: NSLocalizedString("%@에게 맞는 것들을 골라 뒀어요",
                                                    comment: "DYK title: persona picks"),
                          persona.localizedTitle),
            body: String(format: NSLocalizedString("%1$@ 같은 갈래로 나눠 두었고, %2$@ 처럼 바로 쓸 수 있는 문구가 들어 있어요. 마음에 드는 것만 골라 담으면 됩니다.",
                                                   comment: "DYK body: persona picks"),
                         categoryList, sample),
            symbol: persona.icon,
            action: .openShortcutMart
        )
    }

    private static let fixed: [DidYouKnow] = [
        DidYouKnow(
            id: "no-server",
            title: NSLocalizedString("여기 적은 것은 어디로도 가지 않아요", comment: "DYK title: no server"),
            body: NSLocalizedString("이 앱에는 서버가 없어요. 계좌번호도 주민등록번호도 이 폰 안에만 있고, 저희조차 볼 수 없습니다. 털릴 서버가 없으니 털릴 방법도 없어요.", comment: "DYK body: no server"),
            symbol: "lock.iphone"
        ),
        DidYouKnow(
            id: "secure-memo",
            title: NSLocalizedString("남에게 보여주기 싫은 건 잠글 수 있어요", comment: "DYK title: secure memo"),
            body: NSLocalizedString("단축어를 보안으로 두면 Face ID 를 통과해야 열려요. 폰을 잠깐 빌려줘도 그것만은 안 보입니다.", comment: "DYK body: secure memo"),
            symbol: "faceid",
            action: .openSettings
        ),
        DidYouKnow(
            id: "long-press-copy",
            title: NSLocalizedString("길게 누르면 복사돼요", comment: "DYK title: long press"),
            body: NSLocalizedString("키보드에서 단축어를 길게 누르면 입력 대신 클립보드로 들어가요. 붙여넣을 곳이 따로 있을 때 쓰세요.", comment: "DYK body: long press"),
            symbol: "hand.tap",
            action: .openStage
        ),
        DidYouKnow(
            id: "auto-classify",
            title: NSLocalizedString("복사한 것이 알아서 갈래를 찾아가요", comment: "DYK title: auto classify"),
            body: NSLocalizedString("계좌번호를 복사하면 계좌로, 주소를 복사하면 주소로 스스로 분류돼요. 나중에 찾을 때 검색하지 않고 갈래만 고르면 됩니다.", comment: "DYK body: auto classify"),
            symbol: "square.grid.2x2"
        ),
        DidYouKnow(
            id: "checksum",
            title: NSLocalizedString("틀린 카드번호는 저장할 때 알려드려요", comment: "DYK title: checksum"),
            body: NSLocalizedString("카드번호·IBAN·사업자등록번호는 검사식이 있어요. 한 자리를 잘못 적었으면 저장하기 전에 짚어 드립니다.", comment: "DYK body: checksum"),
            symbol: "checkmark.seal"
        ),
        DidYouKnow(
            id: "cursor-token",
            title: NSLocalizedString("커서를 어디에 둘지 정할 수 있어요", comment: "DYK title: cursor token"),
            body: NSLocalizedString("단축어 안에 {커서} 를 적어 두면, 넣은 뒤 커서가 그 자리에 섭니다. 뒷말을 이어 쓸 때 손이 덜 갑니다.", comment: "DYK body: cursor token"),
            symbol: "text.cursor"
        ),
        DidYouKnow(
            id: "clipboard-token",
            title: NSLocalizedString("복사해 둔 것을 문장 안에 끼울 수 있어요", comment: "DYK title: clipboard token"),
            body: NSLocalizedString("{클립보드} 를 적어 두면 그 자리에 방금 복사한 것이 들어가요. \"운송장 번호는 {클립보드} 입니다\" 처럼요.", comment: "DYK body: clipboard token"),
            symbol: "doc.on.clipboard"
        ),
        DidYouKnow(
            id: "icloud-backup",
            title: NSLocalizedString("폰을 잃어버려도 단축어는 남아요", comment: "DYK title: backup"),
            body: NSLocalizedString("iCloud 백업이 켜져 있으면 새 폰에서 그대로 불러올 수 있어요. 백업은 본인 iCloud 계정에만 저장됩니다.", comment: "DYK body: backup"),
            symbol: "icloud",
            action: .openBackup
        ),
        DidYouKnow(
            id: "keyboard-look",
            title: NSLocalizedString("키보드 생김새를 바꿀 수 있어요", comment: "DYK title: keyboard look"),
            body: NSLocalizedString("키 개수·높이·글자 크기·색을 취향대로 바꿀 수 있어요. 한 화면에 여덟 개를 띄우는 사람도 있습니다.", comment: "DYK body: keyboard look"),
            symbol: "keyboard",
            action: .openSettings
        ),
        DidYouKnow(
            id: "bulk-import",
            title: NSLocalizedString("여태 딴 데 적어 두신 것, 한 번에 옮겨요", comment: "DYK title: bulk import"),
            body: NSLocalizedString("메모장에 모아 둔 걸 통째로 붙여넣으면 알아서 한 줄씩 나눠 담아요. 사진에서 읽어 올 수도 있고, 비밀번호처럼 보이는 값은 잠긴 단축어로 들어갑니다. 단축어 목록의 + 안에 있어요.", comment: "DYK body: bulk import"),
            symbol: "square.and.arrow.down.on.square",
            // ⚠️ 목록이 아니라 **그 화면으로 바로** 데려간다. 예전에는 목록까지만 보내서
            //    "+ 안 어딘가에 있다"는 말만 듣고 스스로 찾아야 했다. 찾는 일이 남으면
            //    알려 준 것이 아니다.
            action: .openBulkImport
        ),
        DidYouKnow(
            id: "photo-smear",
            title: NSLocalizedString("종이에 적힌 건 옮겨 적지 말고 문지르세요", comment: "DYK title: photo smear"),
            body: NSLocalizedString("단축어를 만들 때 스캔해서 글자 넣기로 사진을 찍고, 필요한 곳 위를 손가락으로 쓱 문지르면 그 글자만 값으로 들어와요. 통장 사진에서 계좌번호만, 명함에서 전화번호만 집어 올 수 있습니다.", comment: "DYK body: photo smear"),
            symbol: AppSymbol.textViewfinder,
            action: .openList
        ),
        DidYouKnow(
            id: "quick-note-control",
            title: NSLocalizedString("제어센터에서 바로 적어 둘 수 있어요", comment: "DYK title: quick note control"),
            body: NSLocalizedString("제어센터에 빠른 메모 버튼을 넣어 두면, 앱을 열지 않고 적어만 둘 수 있어요. 적어 둔 것은 보관함에 쌓이고, 나중에 쓸 만한 것만 단축어로 올리면 됩니다.", comment: "DYK body: quick note control"),
            symbol: "switch.2",
            action: .openQuickNoteInbox
        ),
        DidYouKnow(
            id: "siri-shortcuts",
            title: NSLocalizedString("단축어 앱에서도 부를 수 있어요", comment: "DYK title: siri shortcuts"),
            body: NSLocalizedString("iPhone 단축어 앱에 이 앱의 동작이 들어가 있어요. 빠른 메모 적기와 보관함 열기를 자동화에 끼우거나 Siri 로 부를 수 있습니다.", comment: "DYK body: siri shortcuts"),
            symbol: "app.connected.to.app.below.fill"
        ),
        DidYouKnow(
            id: "compact-placeholders",
            title: NSLocalizedString("빈칸이 여럿이어도 굴리지 않아요", comment: "DYK title: compact placeholders"),
            body: NSLocalizedString("빈칸이 여러 개인 단축어를 키보드에서 채울 때, 지금 채우는 칸만 펼치고 나머지는 한 줄로 접어 둬요. 하나를 고르면 다음 칸이 저절로 펼쳐집니다. 전부 펼쳐 보고 싶으면 설정에서 끌 수 있어요.", comment: "DYK body: compact placeholders"),
            symbol: AppSymbol.rectangleCompressVertical,
            action: .openSettings
        ),
        DidYouKnow(
            id: "return-key",
            title: NSLocalizedString("넣고 나서 그 자리에서 보낼 수 있어요", comment: "DYK title: return key"),
            body: NSLocalizedString("키보드 위줄에 보내기 키가 생겼어요. 단축어를 넣고 키보드를 바꾸러 나갈 일이 없습니다. 키 이름은 앱이 정해요, 메시지 앱에서는 보내기로 보입니다.", comment: "DYK body: return key"),
            symbol: AppSymbol.returnLeft,
            action: .openStage
        ),
        DidYouKnow(
            id: "secure-combo-pick",
            title: NSLocalizedString("잠근 단축어도 값을 골라서 넣어요", comment: "DYK title: secure combo pick"),
            body: NSLocalizedString("값이 여러 개인 단축어를 잠가 두었어도, 오른쪽 화살표로 원하는 값을 고른 다음 왼쪽을 눌러 인증하면 그 값만 들어갑니다.", comment: "DYK body: secure combo pick"),
            symbol: "lock.open",
            action: .openStage
        ),
        DidYouKnow(
            id: "share-sheet",
            title: NSLocalizedString("다른 앱에서 바로 저장할 수 있어요", comment: "DYK title: share sheet"),
            body: NSLocalizedString("어떤 앱에서든 글을 고르고 공유에서 ClipKeyboard 를 누르면 단축어가 됩니다. 앱을 열지 않아도 돼요.", comment: "DYK body: share sheet"),
            symbol: "square.and.arrow.up"
        )
    ]
}

// MARK: - 언제 말을 거는가

/// **아직 안 한 이야기 중 다음 것**을 고르고, 말을 걸어도 되는 때인지 판단한다.
///
/// ⚠️ 이 파일에서 가장 조심스러운 부분이다. 좋은 이야기라도 아무 때나 튀어나오면
///    그건 알림이 아니라 방해다. 세 가지를 지킨다.
///
///    ① **첫날에는 말하지 않는다.** 처음 온 사람은 온보딩을 지나는 중이고, 그 위에
///       또 하나가 얹히면 둘 다 안 읽힌다.
///    ② **며칠에 한 번.** 열 때마다 새 이야기를 하면 정보가 아니라 소음이 된다.
///    ③ **다 하면 멈춘다.** 처음으로 돌아가지 않는다. 되풀이되는 순간 광고가 된다.
enum DidYouKnowScheduler {

    /// 이야기와 이야기 사이(초). 사흘.
    static let interval: TimeInterval = 3 * 24 * 60 * 60
    /// 설치하고 이만큼은 아무 말도 하지 않는다. 하루.
    static let quietAfterInstall: TimeInterval = 24 * 60 * 60

    private static var defaults: UserDefaults { .standard }
    private static let seenKey = "didYouKnow.seen.v1"
    private static let lastShownKey = "didYouKnow.lastShownAt.v1"
    private static let optOutKey = "didYouKnow.optOut.v1"

    /// 이미 본 이야기들.
    static var seen: Set<String> {
        Set(defaults.stringArray(forKey: seenKey) ?? [])
    }

    /// "이제 그만 볼게요" 를 고른 사람.
    static var isOptedOut: Bool {
        get { defaults.bool(forKey: optOutKey) }
        set { defaults.set(newValue, forKey: optOutKey) }
    }

    static var lastShownAt: Date? {
        let t = defaults.double(forKey: lastShownKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// 아직 안 한 이야기 중 첫 번째. 다 했으면 nil.
    static var next: DidYouKnow? {
        let done = seen
        return DidYouKnow.all.first { !done.contains($0.id) }
    }

    /// 지금 말을 걸어도 되는가 - 되면 그 이야기를, 아니면 nil.
    ///
    /// - Parameters:
    ///   - onboardingFinished: 처음 오는 길을 다 지났는가. 지나기 전에는 말하지 않는다.
    ///   - installedAt: 설치 시각. 모르면 말하지 않는다(모르는 채로 첫날에 말을 걸 수 있다).
    static func candidate(onboardingFinished: Bool,
                          installedAt: Date?,
                          now: Date = Date()) -> DidYouKnow? {
        guard !isOptedOut, onboardingFinished else { return nil }
        guard let installedAt, now.timeIntervalSince(installedAt) >= quietAfterInstall else { return nil }
        if let last = lastShownAt, now.timeIntervalSince(last) < interval { return nil }
        return next
    }

    /// 보여 줬다고 적는다.
    static func markShown(_ item: DidYouKnow, at date: Date = Date()) {
        var done = seen
        done.insert(item.id)
        defaults.set(Array(done), forKey: seenKey)
        defaults.set(date.timeIntervalSince1970, forKey: lastShownKey)
    }

    /// 처음부터 다시 - 설정의 "다시 보기" 용.
    static func resetAll() {
        defaults.removeObject(forKey: seenKey)
        defaults.removeObject(forKey: lastShownKey)
        defaults.removeObject(forKey: optOutKey)
    }
}
