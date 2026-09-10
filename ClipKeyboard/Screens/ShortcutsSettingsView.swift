//
//  ShortcutsSettingsView.swift
//  ClipKeyboard
//
//  설정 > 단축어
//

import SwiftUI
import LeeoKit

/// 단축어 - 무엇을 저장하고 어떻게 정리하는가.
///
/// ⚠️ 예전에는 목록 화면 오른쪽 위 ⋯ 메뉴에 있던 것들이다. 바에 ⋯ 와 + 와
///    금고를 다 두려니 시스템이 넘친다고 보고 오버플로 ⋯ 를 하나 더 만들어서
///    ⋯ 가 둘로 보였고, 금고는 그 안에 접혀 사라졌다. 자주 안 여는 것들은
///    설정에 있는 편이 찾기도 쉽다.
struct ShortcutsSettingsView: View {

    @Environment(\.appTheme) private var theme
    @State private var showPlaceholderManagement = false
    /// `{날짜}` 모양. App Group 이라 키보드도 같은 값을 본다.
    @AppStorage(DefaultsKey.templateDateFormat, store: AppGroup.defaults)
    private var dateTokenFormatRaw: String = DateTokenFormat.automatic.rawValue
    /// `{시간}` 모양.
    @AppStorage(DefaultsKey.templateTimeFormat, store: AppGroup.defaults)
    private var timeTokenFormatRaw: String = TimeTokenFormat.automatic.rawValue

    var body: some View {
        List {
            usageSection
            organizeSection
        }
        .settingsCategoryChrome(title: NSLocalizedString("단축어", comment: "Settings section: shortcuts"))
        .sheet(isPresented: $showPlaceholderManagement) {
            PlaceholderManagementSheet(allMemos: (try? MemoStore.shared.load(type: .memo)) ?? [])
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 섹션

    /// 어떻게 쓸지 고르는 것들.
    private var usageSection: some View {
        Section {
            // 활용 사례는 페르소나로 고르는 화면이라 페르소나와 나란히 둔다.
            // ⚠️ 예전에는 이 행이 "단축어 관리"와 "도움말" 양쪽에 있었다(같은 UsageGuideView).
            //    같은 곳으로 가는 문이 둘이면 다른 화면인 줄 안다. 여기 하나만 남긴다.
            NavigationLink(destination: UsageGuideView()) {
                Label(NSLocalizedString("이렇게들 써요", comment: "Use cases / usage scenarios"),
                      systemImage: AppSymbol.lightbulb)
            }
            NavigationLink(destination: PersonaSettingsContainer()) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("페르소나", comment: "Persona setting row title"))
                        if let p = CategoryStore.shared.selectedPersona {
                            Text(p.localizedTitle)
                                .font(.body)
                                .foregroundColor(theme.textMuted)
                        }
                    }
                } icon: {
                    Image(systemName: AppSymbol.personCropCircleBadgeCheckmark)
                }
            }
        }
    }

    /// 만들어 둔 것을 들여다보고 정리하는 것들.
    ///
    /// ⚠️ 빈칸 관리 · 카테고리 관리 · 보관함은 **붙어 있어야 한다.** 보관함이 페르소나 옆에
    ///    있었더니 고르는 것들 사이에 담아 두는 것이 하나 끼어 있는 꼴이었다.
    private var organizeSection: some View {
        Section {
            Button {
                HapticManager.shared.light()
                showPlaceholderManagement = true
            } label: {
                Label(NSLocalizedString("빈칸 관리", comment: "Placeholder management title (by name)"),
                      systemImage: AppSymbol.listBullet)
                    .foregroundColor(theme.text)
            }
            dateFormatRow
            timeFormatRow
            // 카테고리 아이콘은 이 화면 안에서 이어서 고른다(예전에는 형제 행이었다).
            NavigationLink(destination: CategorySettings()) {
                Label(NSLocalizedString("카테고리 관리", comment: "Manage categories settings entry"),
                      systemImage: AppSymbol.folderBadgeGearshape)
            }
            NavigationLink(destination: QuickNoteInboxView()) {
                Label(NSLocalizedString("보관함", comment: "Quick note inbox entry"),
                      systemImage: AppSymbol.trayFull)
            }
        }
    }

    // MARK: - 날짜 · 시간 형식

    /// `{날짜}` · `{시간}` 을 어떤 모양으로 넣을지 고르러 가는 행.
    ///
    /// ⚠️ 행에는 **지금 값을 그 모양으로 직접 그려서** 보여준다. "MM/DD/YYYY" 같은
    ///    패턴 글자는 개발자만 읽는다. 08/31/2026 은 누구나 읽는다.
    ///
    /// 예전에는 여기가 `Picker` 였다. 사용자가 자기 모양을 만들 수 있게 되면서
    /// (더하고 지우는 자리가 필요해) 화면으로 옮겼다.
    private func tokenFormatRow<Format: TokenFormat>(
        _ type: Format.Type,
        raw: String,
        title: String,
        systemImage: String,
        chips: [TokenFormatField.Chip]
    ) -> some View {
        NavigationLink {
            TokenFormatSettingsView(title: title, chips: chips, of: Format.self)
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text(TokenFormatOption<Format>(raw: raw).sampleText())
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
            }
        }
    }

    private var dateFormatRow: some View {
        tokenFormatRow(DateTokenFormat.self,
                       raw: dateTokenFormatRaw,
                       title: NSLocalizedString("날짜 형식", comment: "Date format setting row title"),
                       systemImage: AppSymbol.calendar,
                       chips: TokenFormatField.dateChips)
    }

    /// 날짜 바로 아래에 둔다 - 같은 종류의 선택이다.
    private var timeFormatRow: some View {
        tokenFormatRow(TimeTokenFormat.self,
                       raw: timeTokenFormatRaw,
                       title: NSLocalizedString("시간 형식", comment: "Time format setting row title"),
                       systemImage: AppSymbol.clock,
                       chips: TokenFormatField.timeChips)
    }
}
