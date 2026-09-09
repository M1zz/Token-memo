//
//  CategorySnapshot.swift
//  ClipKeyboard
//
//  카테고리 설정을 **백업·동기화에 실을 수 있는 한 덩이**로 묶는다.
//
//  왜 필요한가: 메모 내용은 `memos.data` 파일에 들어가 백업·동기화를 타지만,
//  카테고리 목록·아이콘·숨김 설정은 **App Group UserDefaults 에만** 있었다.
//  그래서 새 기기에서 앱 백업으로 복원하면 메모는 다 살아나는데 카테고리 탭이
//  하나도 없고, 각 메모의 `category` 값만 쓸모없이 남아 있었다.
//
//  ⚠️ 여기 담기는 건 **설정**이지 사용자 콘텐츠가 아니다. 이름·아이콘·순서·숨김뿐이고
//     메모 내용은 들어가지 않는다.
//  ⚠️ 필드를 추가할 땐 전부 옵셔널/기본값으로 - 구버전이 만든 스냅샷을 신버전이,
//     신버전이 만든 걸 구버전이 읽어도 깨지지 않아야 한다(다운그레이드 대비).
//

import Foundation

struct CategorySnapshot: Codable, Equatable {

    /// 사용자 정의 카테고리 - **순서가 곧 탭 순서**라 배열로 둔다.
    var categories: [String] = []
    /// [카테고리명: SF Symbol 이름]
    var icons: [String: String] = [:]
    /// [카테고리명: 색 hex] - 사용자가 직접 고른 색만. 미지정 카테고리는 팔레트가 정한다.
    var colors: [String: String] = [:]
    /// 사용자가 숨긴 탭 이름.
    var hiddenTabs: [String] = []
    /// 켜 둔 기본 제공 카테고리(BuiltInCategory.rawValue).
    var enabledBuiltIns: [String] = []
    /// 카테고리 기능 자체를 켰는지.
    var featureEnabled: Bool = false
    /// 이 스냅샷을 만든 시각 - 동기화 충돌 시 최신 우선 판단에 쓴다.
    var updatedAt: Date = Date()

    var isEmpty: Bool {
        categories.isEmpty && icons.isEmpty && colors.isEmpty
            && hiddenTabs.isEmpty && enabledBuiltIns.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case categories, icons, colors, hiddenTabs, enabledBuiltIns, featureEnabled, updatedAt
    }

    init(categories: [String] = [], icons: [String: String] = [:], colors: [String: String] = [:],
         hiddenTabs: [String] = [], enabledBuiltIns: [String] = [],
         featureEnabled: Bool = false, updatedAt: Date = Date()) {
        self.categories = categories
        self.icons = icons
        self.colors = colors
        self.hiddenTabs = hiddenTabs
        self.enabledBuiltIns = enabledBuiltIns
        self.featureEnabled = featureEnabled
        self.updatedAt = updatedAt
    }

    /// 관용 디코더 - 누락 키를 전부 기본값으로 허용한다(하위·상위 호환).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
        self.icons = try c.decodeIfPresent([String: String].self, forKey: .icons) ?? [:]
        self.colors = try c.decodeIfPresent([String: String].self, forKey: .colors) ?? [:]
        self.hiddenTabs = try c.decodeIfPresent([String].self, forKey: .hiddenTabs) ?? []
        self.enabledBuiltIns = try c.decodeIfPresent([String].self, forKey: .enabledBuiltIns) ?? []
        self.featureEnabled = try c.decodeIfPresent(Bool.self, forKey: .featureEnabled) ?? false
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

// MARK: - App Group UserDefaults ↔ 스냅샷

enum CategorySnapshotStore {

    // ⚠️ 키 이름은 CategoryStore/CategoryIconSettings 와 **정확히 같아야 한다**.
    //    한 글자만 달라도 조용히 빈 값이 되어 "복원했는데 카테고리가 없다"가 반복된다.
    static let categoriesKey = "userDefinedCategories_v1"
    static let iconsKey = "userCategoryIcons_v1"
    static let colorsKey = "userCategoryColors_v1"
    static let hiddenTabsKey = "hiddenCategoryTabs_v1"
    static let enabledBuiltInsKey = "enabledBuiltInCategories_v1"
    static let featureEnabledKey = "category.feature.enabled.v1"

    /// `Memo.category` 의 기본값이자 아이폰·맥이 주고받는 **저장 센티널**.
    /// 사용자 정의 카테고리 목록에는 절대 들어가지 않는다(들어가면 기본 탭과 겹친다).
    /// ⚠️ 번역 금지 - 화면에 뿌릴 때만 현지화한다.
    static let basicCategoryName = "기본"

    private static var defaults: UserDefaults? { AppGroup.defaults }

    /// 기기 간 **동기화용** 스냅샷 - 실제로 쓰이는 카테고리만 담는다.
    ///
    /// ⚠️ 왜 거르나: 첫 실행 온보딩에서 고른 페르소나에 따라 카테고리가 자동으로 심기는데,
    ///    **그 이름이 기기 언어별로 다르다**(회사 이메일 / Work Email / Email Kantor).
    ///    거르지 않고 합치면 폰 2대를 쓸 때 같은 뜻의 카테고리가 언어별로 중복되고,
    ///    서로 다른 페르소나를 골랐다면 양쪽 세트가 통째로 합쳐진다.
    ///
    /// 기준: **비샘플 메모가 하나라도 붙어 있는 카테고리**만 동기화한다.
    /// 사용자가 실제로 쓰기 시작한 것만 다른 기기로 넘어간다.
    /// (백업은 `current()` 로 전부 담는다 - 백업은 "이 기기 상태를 그대로 되살리기"라
    ///  아직 안 쓴 카테고리도 남아 있어야 한다.)
    static func syncable(memos: [Memo], sampleIDs: Set<UUID>) -> CategorySnapshot {
        var snapshot = current()
        let usedNames = Set(
            memos.filter { !sampleIDs.contains($0.id) }
                 .map(\.category)
                 .filter { !$0.isEmpty && $0 != basicCategoryName }
        )
        snapshot.categories = snapshot.categories.filter { usedNames.contains($0) }

        // ⛔️ 여기서 `memo.category` 에 있는 이름을 목록에 **더하지 않는다.**
        //
        //    한때 그렇게 했다. "목록에는 없는데 단축어는 이미 그 카테고리에 들어 있는" 경우를
        //    받아 주려던 것이었는데, 카테고리가 걷잡을 수 없이 불어났다. 고리는 이렇다.
        //
        //      올릴 때는 payload 를 **교체**하고, 받을 때는 `.merge` 로 **더하기만** 한다.
        //      그래서 memo.category 문자열이 한 번 목록에 들어가면 다시는 빠지지 않는다.
        //      기기를 오갈 때마다 쌓이기만 하는 래칫이 된다.
        //
        //    들어오는 이름이 사용자가 만든 카테고리라는 보장도 없다. 지운 카테고리를 아직
        //    달고 있는 단축어, 다른 언어로 심긴 페르소나 이름, 가져오기로 들어온 임의의
        //    문자열이 전부 **사용자가 만든 카테고리**로 승격됐다. 한 기기에서도 동기화가
        //    한 바퀴 돌면 그대로 불어난다.
        //
        //    ⚠️ 카테고리는 **사용자가 만들 때만** 늘어난다. 앱이 알아서 늘리지 않는다.
        //       목록이 빈약한 기기가 공용 레코드를 덮어쓰는 문제는 이 자리가 아니라
        //       올리는 자리에서 풀어야 한다(MemoSyncEngine.makeCategoryRecord).

        snapshot.icons = snapshot.icons.filter { usedNames.contains($0.key) }
        snapshot.colors = snapshot.colors.filter { usedNames.contains($0.key) }
        // ⚠️ 즐겨찾기 숨김은 카테고리 이름이 아니라 센티널이라 `usedNames` 에 절대 걸리지 않는다.
        //    그냥 거르면 "즐겨찾기 탭을 숨김" 설정이 기기 간에 영영 넘어가지 않는다.
        snapshot.hiddenTabs = snapshot.hiddenTabs.filter {
            $0 == CategoryBucketRule.favoritesTabKey || usedNames.contains($0)
        }
        return snapshot
    }

    /// 올릴 스냅샷을 **원격에 이미 있는 것 위에 얹는다.**
    ///
    /// 왜: 올리는 쪽은 payload 를 통째로 **교체**한다. 그래서 목록이 빈약한 기기가 한 번
    /// 올리면 공용 레코드가 그만큼 깎인다. 받는 쪽은 `.merge` 라 더하기만 하므로 **원본
    /// 기기는 멀쩡해 보이고**, 새로 붙는 기기만 빈약한 목록을 받아 고착된다.
    /// 실제로 맥에서 단축어 37개가 카테고리 12개를 쓰는데 탭은 2개만 서던 사고가 이것이었다.
    ///
    /// ⚠️ 여기서 **카테고리를 새로 만들지 않는다.** 원격에 이미 있는 것을 지우지 않을 뿐이다.
    ///    한때 `syncable` 이 `memo.category` 문자열을 목록으로 승격시켜 카테고리가 걷잡을 수
    ///    없이 불어난 적이 있다. 늘리는 것은 사용자뿐이다.
    ///
    /// ⚠️ `hiddenTabs` 는 합치지 **않는다.** 그건 "사용자가 치운 것" 목록이라, 합치면
    ///    한 기기에서 숨긴 탭을 다른 기기에서 영영 못 되살린다. 더하기만 하는 목록에
    ///    "숨김"을 넣으면 한 방향으로만 굳는다.
    static func union(local: CategorySnapshot, remote: CategorySnapshot) -> CategorySnapshot {
        var merged = local

        var seen = Set(local.categories)
        for name in remote.categories where seen.insert(name).inserted {
            merged.categories.append(name)
        }

        // 아이콘·색은 이 기기 것이 이긴다. 원격에만 있는 것은 그대로 데려온다.
        merged.icons = remote.icons.merging(local.icons) { _, mine in mine }
        merged.colors = remote.colors.merging(local.colors) { _, mine in mine }

        // ⚠️ `enabledBuiltIns` 도 합치지 **않는다.** 숨김과 같은 성격이라 - 켠 것만 넘어가고
        //    끈 것은 안 넘어가면 기본 제공 탭이 기기를 오갈수록 늘기만 한다.
        //    (`merged` 가 `local` 에서 시작하므로 이 기기 값이 그대로 올라간다)

        merged.featureEnabled = local.featureEnabled || remote.featureEnabled
        return merged
    }

    /// 현재 기기의 카테고리 설정을 읽어 스냅샷으로 만든다. (백업용 - 전부 담는다)
    static func current() -> CategorySnapshot {
        guard let d = defaults else { return CategorySnapshot() }
        return CategorySnapshot(
            categories: d.stringArray(forKey: categoriesKey) ?? [],
            icons: (d.dictionary(forKey: iconsKey) as? [String: String]) ?? [:],
            colors: (d.dictionary(forKey: colorsKey) as? [String: String]) ?? [:],
            hiddenTabs: d.stringArray(forKey: hiddenTabsKey) ?? [],
            enabledBuiltIns: d.stringArray(forKey: enabledBuiltInsKey) ?? [],
            featureEnabled: d.bool(forKey: featureEnabledKey)
        )
    }

    /// 스냅샷을 기기에 적용한다.
    ///
    /// ⚠️ **비어 있는 스냅샷으로 기존 설정을 지우지 않는다.** 복원 데이터에 카테고리가
    ///    없다고 해서 이미 잘 쓰고 있던 카테고리를 날리면 그게 더 큰 사고다.
    ///
    /// - `.replace` (백업 복원): **그 시점 상태로 되돌린다.** 목록·아이콘·색·숨김·기본 제공까지
    ///   스냅샷이 결정한다. 백업에 숨긴 탭이 없었으면 지금도 없어야 한다. 합집합으로 두면
    ///   "되돌렸는데 지운 카테고리가 되살아나 있다"가 되어 복원이 아니게 된다.
    /// - `.merge` (동기화 기본값): **더하기만 한다.** 이 기기에만 있는 것을 다른 기기가
    ///   지우면 안 되기 때문이다.
    static func apply(_ snapshot: CategorySnapshot, strategy: MergeStrategy = .merge) {
        guard let d = defaults, !snapshot.isEmpty else { return }

        switch strategy {
        case .replace:
            d.set(snapshot.categories, forKey: categoriesKey)
            d.set(snapshot.icons, forKey: iconsKey)
            d.set(snapshot.colors, forKey: colorsKey)
            d.set(snapshot.hiddenTabs, forKey: hiddenTabsKey)
            d.set(snapshot.enabledBuiltIns, forKey: enabledBuiltInsKey)

        case .merge, .sync:
            var merged = d.stringArray(forKey: categoriesKey) ?? []
            for name in snapshot.categories where !merged.contains(name) {
                merged.append(name)
            }
            d.set(merged, forKey: categoriesKey)

            // 아이콘·색은 합집합 - 한쪽에만 있는 설정이 사라지지 않게.
            var icons = (d.dictionary(forKey: iconsKey) as? [String: String]) ?? [:]
            for (name, symbol) in snapshot.icons where icons[name] == nil { icons[name] = symbol }
            if !icons.isEmpty { d.set(icons, forKey: iconsKey) }

            var colors = (d.dictionary(forKey: colorsKey) as? [String: String]) ?? [:]
            for (name, hex) in snapshot.colors where colors[name] == nil { colors[name] = hex }
            if !colors.isEmpty { d.set(colors, forKey: colorsKey) }

            if strategy == .sync {
                // 숨김·기본 제공은 **재고가 아니라 상태**다 - "지금 이 사람이 원하는 화면 구성".
                // 그래서 받는 쪽도 그대로 비춘다(거울). 합집합으로 두면 켠 것·숨긴 것만
                // 넘어가고 **끈 것·되살린 것은 영영 안 넘어가서**, 기기를 오갈수록 설정이
                // 쌓이기만 하는 래칫이 된다(아이폰에서 탭을 꺼도 맥에는 계속 남았다).
                // 올리는 쪽이 이미 이 두 필드를 합치지 않으므로(CategorySnapshotStore.union),
                // 원격 레코드는 "마지막에 동기화한 기기의 구성"이고 모두가 그리로 수렴한다.
                d.set(snapshot.hiddenTabs, forKey: hiddenTabsKey)
                d.set(snapshot.enabledBuiltIns, forKey: enabledBuiltInsKey)
            } else {
                // 가져오기(.merge)는 "합친다"는 뜻이라 이 기기 설정을 파일이 지우면 안 된다.
                if !snapshot.hiddenTabs.isEmpty {
                    let hidden = Set(d.stringArray(forKey: hiddenTabsKey) ?? []).union(snapshot.hiddenTabs)
                    d.set(Array(hidden), forKey: hiddenTabsKey)
                }
                if !snapshot.enabledBuiltIns.isEmpty {
                    let builtIns = Set(d.stringArray(forKey: enabledBuiltInsKey) ?? []).union(snapshot.enabledBuiltIns)
                    d.set(Array(builtIns), forKey: enabledBuiltInsKey)
                }
            }
        }

        // 카테고리가 하나라도 생기면 기능은 켜 준다 - 복원했는데 기능이 꺼져 있어
        // 탭이 안 보이면 사용자는 "복원 실패"로 받아들인다.
        if snapshot.featureEnabled || !snapshot.categories.isEmpty {
            d.set(true, forKey: featureEnabledKey)
        }

        AppLog.info(.store, "🗂 [CategorySnapshot.apply] 카테고리 \(snapshot.categories.count)개 · 아이콘 \(snapshot.icons.count) · 색 \(snapshot.colors.count) 적용(\(strategy))")
    }

    enum MergeStrategy: CustomStringConvertible {
        case replace, merge, sync
        var description: String {
            switch self {
            case .replace: return "replace"
            case .merge:   return "merge"
            case .sync:    return "sync"
            }
        }
    }

    // MARK: - 메모에서 역산 (구버전 백업 구제)

    /// 카테고리 메타가 없는 **옛 백업**을 복원했을 때, 메모들의 `category` 값에서
    /// 카테고리 목록을 되살린다.
    ///
    /// ⚠️ 이름만 복구된다 - 아이콘·숨김·순서는 원래 스냅샷에만 있으므로 알 수 없다.
    ///    그래도 탭이 통째로 사라지는 것보다는 낫다.
    /// - Returns: 새로 추가된 카테고리 이름들.
    @discardableResult
    static func rebuildFromMemos(_ memos: [Memo]) -> [String] {
        guard let d = defaults else { return [] }

        let existing = d.stringArray(forKey: categoriesKey) ?? []
        // "기본"은 시스템 기본값이라 사용자 정의 목록에 넣지 않는다.
        let derived = memos
            .map(\.category)
            .filter { !$0.isEmpty && $0 != basicCategoryName }
        // 등장 순서를 유지하면서 중복 제거 - 사용자가 많이 쓴 순서에 가깝다.
        var seen = Set(existing)
        var added: [String] = []
        for name in derived where !seen.contains(name) {
            seen.insert(name)
            added.append(name)
        }
        guard !added.isEmpty else { return [] }

        d.set(existing + added, forKey: categoriesKey)
        d.set(true, forKey: featureEnabledKey)
        AppLog.info(.store, "🗂 [CategorySnapshot.rebuildFromMemos] 메모에서 카테고리 \(added.count)개 복구")
        return added
    }
}
