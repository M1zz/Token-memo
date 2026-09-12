//
//  ProBenefitsView.swift
//  ClipKeyboard
//
//  설정 > Pro 활성화됨
//

import SwiftUI
import LeeoKit

/// **지금 누리고 있는 Pro** - 무엇이 열려 있고, 그걸 얼마나 쓰고 있는가.
///
/// ⚠️ 기능 목록만 늘어놓지 않는다. "무제한 단축어" 는 산 사람도 이미 안다. 알고 싶은 것은
///    **내가 그걸 실제로 얼마나 쓰고 있는가**다. 그래서 무료였다면 어디까지였는지 옆에
///    지금 내 숫자를 세우고, 넘어선 만큼을 따로 짚는다.
///
/// ⚠️ 단축어 개수는 저장을 막는 관문과 **같은 셈법**을 쓴다(`ProFeatureManager.ownMemoCount`).
///    심어 준 샘플까지 세면 무료로도 됐을 것을 Pro 덕으로 부풀리게 된다.
struct ProBenefitsView: View {

    @Environment(\.appTheme) private var theme
    @AppStorage(DefaultsKey.memoSyncEnabled, store: AppGroup.defaults)
    private var memoSyncEnabled: Bool = false
    @State private var usage = Usage()

    var body: some View {
        List {
            heroSection
            limitsSection
            unlockedSection
        }
        .settingsCategoryChrome(title: NSLocalizedString("내 Pro 혜택", comment: "Pro benefits screen title"))
        // 들어올 때 한 번 센다 - 그릴 때마다 저장 파일을 읽지 않도록.
        .onAppear { usage = Usage.load() }
    }

    // MARK: - 세는 것

    struct Usage {
        var memos = 0
        var templates = 0
        var combos = 0
        var images = 0
        var secure = 0
        var clipboard = 0
        var lastBackup: Date?
        var savedSeconds: Double = 0

        static func load() -> Usage {
            let all = (try? MemoStore.shared.load(type: .memo)) ?? []
            var u = Usage()
            u.memos = ProFeatureManager.ownMemoCount(all)
            u.templates = all.filter(\.isTemplate).count
            u.combos = all.filter(\.isStack).count
            u.images = all.filter { !$0.imageFileNames.isEmpty || !($0.imageFileName ?? "").isEmpty }.count
            u.secure = all.filter(\.isSecure).count
            u.clipboard = ((try? MemoStore.shared.loadSmartClipboardHistory()) ?? []).count
            u.lastBackup = UserDefaults.standard.object(forKey: DefaultsKey.lastBackupDate) as? Date
            u.savedSeconds = KeyboardUsageTracker.totalTimeSavedSeconds()
            return u
        }
    }

    /// 무료에 한도가 있는 것 하나.
    private struct LimitRow: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let freeLimit: Int
        let used: Int
        /// 무료 한도를 넘어 쓰고 있는 만큼 - Pro 가 아니었다면 못 가졌을 것.
        var extra: Int { max(0, used - freeLimit) }
    }

    /// 무료 한도는 결제 화면 비교표(`PaywallView`)와 같은 값을 쓴다 - 두 화면이 다른 숫자를 말하면 안 된다.
    private var limitRows: [LimitRow] {
        [
            LimitRow(id: "memo",
                     title: NSLocalizedString("단축어 저장", comment: "Memo"),
                     symbol: AppSymbol.trayFull,
                     freeLimit: ProFeatureManager.freeMemoLimit, used: usage.memos),
            LimitRow(id: "template",
                     title: NSLocalizedString("템플릿", comment: "Template"),
                     symbol: AppSymbol.wandAndSparkles,
                     freeLimit: ProFeatureManager.freeTemplateLimit, used: usage.templates),
            LimitRow(id: "combo",
                     title: NSLocalizedString("콤보", comment: "Combo"),
                     symbol: AppSymbol.squareStack3dUpFill,
                     freeLimit: ProFeatureManager.freeStackLimit, used: usage.combos),
            LimitRow(id: "image",
                     title: NSLocalizedString("이미지 단축어", comment: "Image"),
                     symbol: AppSymbol.photo,
                     freeLimit: ProFeatureManager.freeImageMemoLimit, used: usage.images),
            LimitRow(id: "clipboard",
                     title: NSLocalizedString("클립보드 기록", comment: "Clipboard"),
                     symbol: AppSymbol.docOnClipboard,
                     freeLimit: ProFeatureManager.freeClipboardHistoryLimit, used: usage.clipboard),
        ]
    }

    private var totalExtra: Int { limitRows.reduce(0) { $0 + $1.extra } }

    // MARK: - 섹션

    /// 한 줄 요약. **넘어선 만큼**이 있으면 그 숫자부터 말한다.
    private var heroSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: AppSymbol.checkmarkSealFill)
                    .font(.system(size: 34))
                    .foregroundColor(.green)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("Pro 활성화됨", comment: "Pro activated"))
                        .font(.headline)
                        .foregroundColor(theme.text)
                    Text(totalExtra > 0
                         ? String(format: NSLocalizedString("무료 한도를 넘어 %d개를 더 쓰고 있어요",
                                                            comment: "Pro benefits summary: how many items go beyond the free limits"),
                                  totalExtra)
                         : NSLocalizedString("Pro 기능이 모두 열려 있어요",
                                             comment: "Pro benefits summary: nothing beyond the free limits yet"))
                        .font(.subheadline)
                        .foregroundColor(theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private var limitsSection: some View {
        Section {
            ForEach(limitRows) { row in
                limitRowView(row)
            }
        } header: {
            Text(NSLocalizedString("무료 한도와 비교", comment: "Pro benefits section: usage compared with the free limits"))
        }
    }

    private func limitRowView(_ row: LimitRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbol)
                .font(.body)
                .foregroundColor(theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .foregroundColor(theme.text)
                Text(String(format: NSLocalizedString("무료 %1$d개 · 지금 %2$d개",
                                                      comment: "Pro benefits row: the free limit, then how many the user has now"),
                            row.freeLimit, row.used))
                    .font(.caption)
                    .foregroundColor(theme.textMuted)
            }
            Spacer(minLength: 8)
            // 넘어선 만큼만 따로 짚는다. 한도 안이면 아무것도 붙이지 않는다 - 0 을 달면 손해 본 것처럼 읽힌다.
            if row.extra > 0 {
                Text(verbatim: "+\(row.extra)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(theme.accentFg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.accent))
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// 한도가 아니라 **켜지고 꺼지는** 것들. 쓰고 있는 모습을 값으로 보여 준다.
    private var unlockedSection: some View {
        Section {
            valueRow(NSLocalizedString("iCloud 백업", comment: "iCloud"),
                     symbol: AppSymbol.icloudAndArrowUp,
                     value: usage.lastBackup.map(relativeText) ?? NSLocalizedString("없음", comment: "PIN not set / none"))
            valueRow(NSLocalizedString("생체인증 잠금", comment: "Biometric"),
                     symbol: AppSymbol.lockShield,
                     value: String(format: NSLocalizedString("%d개", comment: "count unit"), usage.secure))
            valueRow(NSLocalizedString("기기 간 동기화 (베타)", comment: "Cross-device sync section header"),
                     symbol: AppSymbol.icloudAndArrowDown,
                     value: memoSyncEnabled
                        ? NSLocalizedString("켜짐", comment: "On")
                        : NSLocalizedString("꺼짐", comment: "Off"))
            valueRow(NSLocalizedString("아낀 시간", comment: "Usage stats section: time saved"),
                     symbol: AppSymbol.clock,
                     value: durationText(usage.savedSeconds))
        } header: {
            Text(NSLocalizedString("Pro로 열린 기능", comment: "Pro benefits section: features unlocked by Pro"))
        }
    }

    private func valueRow(_ title: String, symbol: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundColor(theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .foregroundColor(theme.text)
            Spacer(minLength: 8)
            Text(value)
                .foregroundColor(theme.textMuted)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 글로 옮기기

    /// "3일 전" 처럼. 앱 안에서 고른 언어를 따른다.
    private func relativeText(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = AppLanguage.locale
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    /// 사용 기록 화면과 같은 말로 센다(`%d시간 %d분` · `%d분`).
    private func durationText(_ seconds: Double) -> String {
        let minutes = max(0, Int(seconds / 60))
        if minutes >= 60 {
            return String(format: NSLocalizedString("%d시간 %d분", comment: "Duration: hours and minutes"),
                          minutes / 60, minutes % 60)
        }
        return String(format: NSLocalizedString("%d분", comment: "Duration: minutes only"), minutes)
    }
}
