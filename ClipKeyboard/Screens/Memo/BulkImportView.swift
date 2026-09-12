//
//  BulkImportView.swift
//  ClipKeyboard
//
//  타 메모장에서 와장창 옮길 때 - 텍스트 통째로 붙여넣거나 사진(OCR)에서 추출해
//  자동 분할·자동 라벨링으로 일괄 저장.
//
//  분할 규칙 (우선순위 내림차순):
//  1) `---` / `===` 구분선 (Markdown style)
//  2) 빈 줄 두 개 이상 (\n\n+)
//  3) 줄바꿈 한 줄 (한 줄당 한 메모)
//
//  블록 해석 규칙:
//  - 블록 첫 줄이 짧고 값 타입으로 분류되지 않으면 "서비스명(라벨)"로 승격
//    (예: "구글아이디\n12341234" → 제목 "구글아이디", 값 "12341234")
//  - 라벨 아래 값이 2개면 아이디/비밀번호로 분리 (이메일이 있으면 그쪽이 아이디)
//  - 긴 설명 문장이 섞인 블록은 쪼개지 않고 통째로 한 메모 유지
//  - 비밀번호·패스·PIN·인증서류 값은 보안 단축어(암호화)로 기본 설정
//
//  사진 가져오기:
//  - OCRService.recognizeBlocks - 줄 간격으로 문단을 복원해 블록 단위로 추가
//  - 카드 사진이면 카드번호/유효기간을 자동 추출해 정형 블록으로 대체
//

import SwiftUI

struct BulkImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    enum SplitMode: String, CaseIterable {
        case auto, separator, blankLine, oneLinePerMemo

        var label: String {
            switch self {
            case .auto: return NSLocalizedString("Auto", comment: "Bulk import: auto split mode")
            case .separator: return NSLocalizedString("--- separator", comment: "Bulk import: marker split mode")
            case .blankLine: return NSLocalizedString("Blank line", comment: "Bulk import: blank line split")
            case .oneLinePerMemo: return NSLocalizedString("One per line", comment: "Bulk import: line split")
            }
        }
    }

    struct Draft: Identifiable {
        let id = UUID()
        var title: String
        /// 값 목록 - 1개면 일반 단축어, 2개 이상이면 콤보로 저장된다.
        var values: [String]
        var include: Bool = true
        var isSecure: Bool = false

        var isStack: Bool { values.count > 1 }
        /// 단일 값 접근용 (일반 단축어 행 표시·저장)
        var value: String { values.first ?? "" }
    }

    /// 정리된 항목을 무엇으로 보여줄까 - 들어갈 자리(키보드)냐, 다듬는 자리(목록)냐.
    enum PreviewMode: String, CaseIterable {
        /// **기본값.** 저장하면 키보드가 어떻게 되는지 그 모습 그대로 보여주고, 눌러서 고른다.
        case keyboard
        /// 제목 고치기·보안 토글·콤보 묶기 - 키 모양으로는 할 수 없는 손질.
        case list

        var label: String {
            switch self {
            case .keyboard: return NSLocalizedString("키보드", comment: "Bulk import preview mode: keyboard")
            case .list: return NSLocalizedString("목록", comment: "Bulk import preview mode: list")
            }
        }
    }

    @State private var pasteText: String
    /// 붙여넣던 글을 그대로 들고 열렸는가. 그러면 임시저장 복원으로 덮지 않는다.
    private let seeded: Bool

    /// - Parameter initialText: 새 단축어 화면에서 붙여넣던 글. 그대로 들고 열린다.
    ///   사용자가 같은 것을 두 번 붙여넣게 하지 않으려는 것이다.
    init(initialText: String = "") {
        _pasteText = State(initialValue: initialText)
        self.seeded = !initialText.isEmpty
    }
    @State private var previewMode: PreviewMode = .keyboard
    /// 묶기 모드 - 키에 체크가 나오고, 고른 것들을 콤보 하나로 합친다.
    @State private var isBundling = false
    @State private var bundleSelection: Set<UUID> = []
    @State private var splitMode: SplitMode = .auto
    @State private var drafts: [Draft] = []
    @State private var savedCount: Int?
    @State private var showSaveError = false
    // 임시저장(이어서 작성) - 저장 없이 닫으면 스냅샷을 남기고, 다음에 열 때 복원한다.
    @State private var showRestoredNotice = false
    @State private var suppressRegenerate = false
    // OCR
    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @State private var isRecognizing = false
    @State private var showOCREmptyAlert = false

    var body: some View {
        NavigationStack {
            Form {
                if savedCount == nil {
                    if showRestoredNotice {
                        restoredNoticeSection
                    }
                    pasteSection
                    ocrSection
                    if !drafts.isEmpty {
                        previewSection
                    }
                } else {
                    successSection
                }
            }
            // 글을 들고 열렸으면 임시저장으로 덮지 않는다. 방금 붙여넣던 것이 이긴다.
            .onAppear { if !seeded { restoreSnapshotIfAvailable() } }
            .onDisappear { persistSnapshotIfNeeded() }
            .navigationTitle(NSLocalizedString("Bulk import", comment: "Bulk import screen title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .solidNavBar(theme.bg)
            .alert(
                NSLocalizedString("가져오기 실패", comment: "Bulk import failed alert title"),
                isPresented: $showSaveError
            ) {
                Button(NSLocalizedString("확인", comment: "Confirm")) {}
            } message: {
                Text(NSLocalizedString("단축어를 가져오지 못했습니다. 잠시 후 다시 시도해주세요.", comment: "Bulk import failed alert message"))
            }
            .alert(
                NSLocalizedString("텍스트를 찾지 못했습니다", comment: "OCR empty alert title"),
                isPresented: $showOCREmptyAlert
            ) {
                Button(NSLocalizedString("확인", comment: "Confirm")) {}
            } message: {
                Text(NSLocalizedString("사진에서 인식된 텍스트가 없습니다. 글자가 선명한 사진으로 다시 시도해주세요.", comment: "OCR empty alert message"))
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePickerView { image in runOCR(on: image) }
            }
            .sheet(isPresented: $showCameraPicker) {
                ImagePickerView(sourceType: .camera) { image in runOCR(on: image) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if savedCount == nil {
                        Button(saveButtonLabel) {
                            saveAll()
                        }
                        .disabled(selectedCount == 0)
                        .fontWeight(.semibold)
                    } else {
                        Button(NSLocalizedString("Done", comment: "Done")) { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - 임시저장 (이어서 작성)

    /// 저장 없이 닫힌 작성 내용의 스냅샷 - 붙여넣은 원문 + 정리한 항목들(제목·묶음·보안 포함).
    private struct Snapshot: Codable {
        struct Item: Codable {
            var title: String
            var values: [String]
            var include: Bool
            var isSecure: Bool
        }
        var pasteText: String
        var items: [Item]
    }

    private static let snapshotKey = "bulkImportDraftSnapshot_v1"

    /// 저장하지 않고 닫히면 작성 내용을 보존한다. 저장 완료·빈 화면이면 스냅샷을 지운다.
    private func persistSnapshotIfNeeded() {
        guard savedCount == nil else {
            UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
            return
        }
        let trimmed = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !drafts.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
            return
        }
        let snapshot = Snapshot(
            pasteText: pasteText,
            items: drafts.map { .init(title: $0.title, values: $0.values, include: $0.include, isSecure: $0.isSecure) }
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
            print("📝 [BulkImportView] 작성 중 내용 임시저장 (항목 \(drafts.count)개)")
        }
    }

    /// 새로 열렸을 때 남아있는 스냅샷이 있으면 그대로 복원 (제목 수정·콤보 묶음·보안 상태 포함).
    private func restoreSnapshotIfAvailable() {
        guard pasteText.isEmpty, drafts.isEmpty,
              let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        suppressRegenerate = true   // pasteText 복원이 onChange→regenerate로 항목을 덮어쓰지 않게
        pasteText = snapshot.pasteText
        drafts = snapshot.items.map {
            Draft(title: $0.title, values: $0.values, include: $0.include, isSecure: $0.isSecure)
        }
        showRestoredNotice = true
        print("🔄 [BulkImportView] 임시저장 복원 (항목 \(drafts.count)개)")
    }

    private func discardSnapshot() {
        UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
        pasteText = ""
        drafts = []
        showRestoredNotice = false
    }

    private var restoredNoticeSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.accentColor)
                Text(NSLocalizedString("작성하던 내용을 불러왔어요", comment: "Bulk import: draft restored notice"))
                    .font(.body)
                Spacer()
                Button(NSLocalizedString("새로 시작", comment: "Bulk import: start fresh (discard restored draft)")) {
                    discardSnapshot()
                }
                .font(.body)
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - Sections

    private var pasteSection: some View {
        Section {
            TextEditor(text: $pasteText)
                .frame(minHeight: 140)
                .font(.body)
                .onChange(of: pasteText) { _, _ in regenerate() }
            HStack(spacing: 8) {
                // PasteButton - 시스템이 붙여넣기를 대신 처리하므로 **허용 프롬프트가 뜨지 않는다.**
                // `UIPasteboard.general.string`을 직접 읽으면 iOS 16+에서 매번 "붙여넣기 허용?"이
                // 뜨는데, 사용자가 스스로 누른 버튼에서까지 묻는 건 불필요한 마찰이다.
                PasteButton(payloadType: String.self) { strings in
                    guard let first = strings.first else { return }
                    pasteText = first
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                Spacer()
                Picker("", selection: $splitMode) {
                    ForEach(SplitMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: splitMode) { _, _ in regenerate() }
            }
        } header: {
            Text(NSLocalizedString("Paste your notes", comment: "Bulk import: paste header"))
        } footer: {
            Text(NSLocalizedString("App will split the text and let you review each memo before saving.",
                                   comment: "Bulk import: paste footer"))
        }
    }

    private var ocrSection: some View {
        Section {
            if isRecognizing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(NSLocalizedString("텍스트 인식 중…", comment: "Bulk import: OCR in progress"))
                        .foregroundColor(.secondary)
                }
            } else {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(NSLocalizedString("사진에서 텍스트 추출", comment: "Bulk import: OCR from photo library"),
                          systemImage: "text.viewfinder")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCameraPicker = true
                    } label: {
                        Label(NSLocalizedString("카메라로 촬영해 추출", comment: "Bulk import: OCR from camera"),
                              systemImage: "camera.viewfinder")
                    }
                }
            }
        } header: {
            Text(NSLocalizedString("사진에서 가져오기", comment: "Bulk import: OCR section header"))
        } footer: {
            Text(NSLocalizedString("메모 스크린샷이나 카드 사진의 텍스트를 인식해 위 입력창에 추가합니다. 카드 사진은 카드번호와 유효기간을 자동으로 찾아냅니다.",
                                   comment: "Bulk import: OCR section footer"))
        }
    }

    private var previewSection: some View {
        Section {
            // 보기 전환 - 어느 쪽이든 고르는 대상(`drafts`)은 하나다.
            Picker("", selection: $previewMode) {
                ForEach(PreviewMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if previewMode == .keyboard {
                // 키보드 배경을 행 끝까지 칠하려면 기본 여백·배경을 걷어내야 한다.
                BulkImportKeyPreview(drafts: $drafts,
                                     isBundling: isBundling,
                                     bundleSelection: $bundleSelection)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                if isBundling {
                    bundleActionRow
                }
            } else {
                ForEach($drafts) { $draft in
                    draftRow(draft: $draft)
                }
                .onMove { from, to in
                    drafts.move(fromOffsets: from, toOffset: to)
                }
            }
        } header: {
            HStack {
                Text(String(format: NSLocalizedString("%d memos detected", comment: "Bulk import preview header"), drafts.count))
                Spacer()
                // 순서 바꾸기(드래그 핸들) 토글 - 콤보로 묶기 전에 항목을 이웃하게 배치.
                // 키 모양에서는 끌어 옮길 손잡이가 없어 목록에서만 내놓는다.
                if previewMode == .list {
                    EditButton()
                        .font(.body)
                }
                // 묶기 모드 - 키 모양에서만. 목록에는 길게 눌러 묶는 길이 이미 있다.
                if previewMode == .keyboard {
                    Button(isBundling
                           ? NSLocalizedString("완료", comment: "Done bundling")
                           : NSLocalizedString("묶기", comment: "Bulk import: enter combo bundling mode")) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isBundling.toggle()
                            bundleSelection = []
                        }
                    }
                    .font(.body)
                }
                // 묶기 중에는 넣고빼기를 건드리지 않는다 - 지금 체크는 '묶을 것'이지 '넣을 것'이 아니다.
                if isBundling {
                    EmptyView()
                } else if drafts.contains(where: { !$0.include }) {
                    Button(NSLocalizedString("Select all", comment: "Bulk import: select all")) {
                        for i in drafts.indices { drafts[i].include = true }
                    }
                    .font(.body)
                } else {
                    Button(NSLocalizedString("Deselect all", comment: "Bulk import: deselect all")) {
                        for i in drafts.indices { drafts[i].include = false }
                    }
                    .font(.body)
                }
            }
        } footer: {
            if previewMode == .keyboard, isBundling {
                Text(NSLocalizedString("함께 쓰는 값들을 골라 하나로 묶으면 키 하나가 돼요. 주황색 숫자는 그 키가 몇 단계인지예요.",
                                       comment: "Bulk import: bundling mode footer"))
            } else if previewMode == .keyboard {
                Text(NSLocalizedString("저장하면 키보드가 이 모습이 돼요. 키를 눌러 뺄 것을 빼고, 제목·자물쇠는 목록에서 손보세요.",
                                       comment: "Bulk import: keyboard preview footer"))
            } else {
                Text(NSLocalizedString("자물쇠가 켜진 항목은 보안 단축어로 암호화되어 저장됩니다. 항목을 길게 누르면 위 항목과 콤보로 묶거나 풀 수 있어요.",
                                       comment: "Bulk import: secure + combo merge footer"))
            }
        }
    }

    // MARK: - 묶기 모드 (컬렉션에서 체크해서 콤보 만들기)

    /// 고른 것으로 무엇을 할 수 있는지 알려주고 실행하는 줄.
    /// 아무것도 안 골랐을 땐 무엇을 해야 하는지만 말한다 - 빈 바가 떠 있으면 고장으로 보인다.
    @ViewBuilder
    private var bundleActionRow: some View {
        let picked = drafts.filter { bundleSelection.contains($0.id) }

        HStack(spacing: 12) {
            if picked.isEmpty {
                Text(NSLocalizedString("함께 쓸 것들을 눌러 고르세요", comment: "Bulk import: bundling empty hint"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text(String(format: NSLocalizedString("%d개 선택", comment: "Bulk import: bundling selected count"), picked.count))
                    .font(.subheadline.weight(.medium))
            }

            Spacer()

            // 콤보 하나만 골랐으면 푸는 것이 자연스러운 다음 행동이다.
            if picked.count == 1, picked[0].isStack {
                Button(NSLocalizedString("콤보 풀기", comment: "Bulk import: split combo back into items")) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        splitStack(picked[0].id)
                        bundleSelection = []
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if picked.count >= 2 {
                Button(NSLocalizedString("콤보로 묶기", comment: "Bulk import: bundle selected into one combo")) {
                    withAnimation(.easeInOut(duration: 0.2)) { mergeSelected() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func mergeSelected() {
        let result = Self.merging(drafts, selection: bundleSelection)
        drafts = result.drafts
        bundleSelection = result.mergedID.map { [$0] } ?? []
    }

    /// 고른 것들을 **하나의 콤보**로 합친 결과를 돌려준다 (화면과 무관한 순수 규칙).
    ///
    /// ⚠️ 이웃이 아니어도 묶인다. 예전에는 바로 위 항목과만 합칠 수 있어서, 떨어져 있는
    ///    아이디와 비밀번호를 묶으려면 먼저 순서를 바꿔 붙여 놓아야 했다.
    ///
    /// 규칙 세 가지 - 전부 조용히 깨질 수 있어 테스트로 고정한다:
    ///  · 합친 자리와 단계 차례는 **화면에 놓인 순서**를 따른다(고른 순서가 아니다).
    ///    눈에 보이는 차례가 곧 콤보의 차례여야 결과를 예상할 수 있다.
    ///  · 하나라도 보안이면 합친 콤보도 보안 - 지키던 것을 합치다가 풀어버리면 안 된다.
    ///  · 넣기로 한 것이 하나라도 있으면 결과도 넣는다.
    static func merging(_ drafts: [Draft], selection: Set<UUID>) -> (drafts: [Draft], mergedID: UUID?) {
        let indices = drafts.indices.filter { selection.contains(drafts[$0].id) }
        guard indices.count >= 2, let anchor = indices.first else { return (drafts, nil) }

        var result = drafts
        result[anchor].values = indices.flatMap { drafts[$0].values }
        result[anchor].isSecure = indices.contains { drafts[$0].isSecure }
        result[anchor].include = indices.contains { drafts[$0].include }

        for index in indices.dropFirst().reversed() {
            result.remove(at: index)
        }
        return (result, result[anchor].id)
    }

    // MARK: - 콤보 묶기/풀기

    /// 이 항목을 바로 위 항목에 합쳐 콤보로 만든다 (값들이 위 항목의 단계로 이어 붙음).
    /// 어느 한쪽이라도 보안이면 합친 콤보도 보안으로 유지한다.
    private func mergeWithPrevious(_ id: UUID) {
        guard let idx = drafts.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        drafts[idx - 1].values.append(contentsOf: drafts[idx].values)
        drafts[idx - 1].isSecure = drafts[idx - 1].isSecure || drafts[idx].isSecure
        drafts.remove(at: idx)
    }

    /// 콤보 항목을 단계별 개별 항목으로 다시 풀어낸다 (보안 상태는 각 항목에 승계).
    private func splitStack(_ id: UUID) {
        guard let idx = drafts.firstIndex(where: { $0.id == id }), drafts[idx].isStack else { return }
        let src = drafts[idx]
        let parts = src.values.enumerated().map { i, v in
            Draft(title: i == 0 ? src.title : "\(src.title) \(i + 1)",
                  values: [v], include: src.include, isSecure: src.isSecure)
        }
        drafts.replaceSubrange(idx...idx, with: parts)
    }

    private func draftRow(draft: Binding<Draft>) -> some View {
        let d = draft.wrappedValue
        return HStack(alignment: .top, spacing: 10) {
            Button {
                draft.wrappedValue.include.toggle()
            } label: {
                Image(systemName: d.include ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(d.include ? Color.checkGreen : .secondary)
                    .font(.system(.title3))
            }
            .buttonStyle(.plain)
            // ⚠️ 색만으로 켬/끔을 말하지 않는다. 읽어 줄 때도 상태가 들려야 한다.
            .accessibilityLabel(NSLocalizedString("가져오기", comment: "Include this item"))
            .accessibilityValue(d.include
                                ? NSLocalizedString("선택됨", comment: "Selected")
                                : NSLocalizedString("선택 안 됨", comment: "Not selected"))
            .accessibilityAddTraits(d.include ? [.isSelected] : [])

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    TextField(NSLocalizedString("Title", comment: "Title field"), text: draft.title)
                        .font(.body.weight(.semibold))
                    if d.isStack {
                        Text(NSLocalizedString("Combo", comment: "Tag: combo"))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                if d.isStack {
                    // 콤보 - 단계 값을 번호와 함께 표시 (보안이면 마스킹)
                    ForEach(Array(d.values.enumerated()), id: \.offset) { i, v in
                        Text("\(i + 1). \(d.isSecure ? String(repeating: "•", count: min(max(v.count, 4), 12)) : v)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(d.isSecure
                         ? String(repeating: "•", count: min(max(d.value.count, 4), 12))
                         : d.value)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .opacity(d.include ? 1.0 : 0.4)

            Spacer(minLength: 0)

            // 보안 토글 - 켜면 암호화 저장 + 값 마스킹 (콤보는 단계 값까지 암호화)
            Button {
                draft.wrappedValue.isSecure.toggle()
            } label: {
                Image(systemName: d.isSecure ? "lock.fill" : "lock.open")
                    .font(.body)
                    .foregroundColor(d.isSecure ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(d.isSecure
                                ? NSLocalizedString("보안 단축어 해제", comment: "Bulk import: turn off secure")
                                : NSLocalizedString("보안 단축어로 설정", comment: "Action: make memo secure"))
        }
        .padding(.vertical, 4)
        // 길게 눌러 오거나이즈 - 위 항목과 콤보로 묶기 / 콤보 풀기
        .contextMenu {
            if drafts.first?.id != d.id {
                Button {
                    mergeWithPrevious(d.id)
                } label: {
                    Label(NSLocalizedString("위 항목과 콤보로 묶기", comment: "Bulk import: merge with previous item into combo"),
                          systemImage: "link")
                }
            }
            if d.isStack {
                Button {
                    splitStack(d.id)
                } label: {
                    Label(NSLocalizedString("콤보 풀기", comment: "Bulk import: split combo back into items"),
                          systemImage: "link.badge.plus")
                }
            }
        }
    }

    private var successSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: AppSymbol.checkmarkCircleFill)
                    .font(.system(size: 44))
                    .foregroundColor(Color.checkGreen)
                Text(String(format: NSLocalizedString("Imported %d memos", comment: "Bulk import success"), savedCount ?? 0))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Split Logic

    private var selectedCount: Int { drafts.filter(\.include).count }

    private var saveButtonLabel: String {
        if selectedCount == 0 { return NSLocalizedString("Save", comment: "Save") }
        return String(format: NSLocalizedString("Save %d", comment: "Save with count"), selectedCount)
    }

    private func regenerate() {
        // 임시저장 복원 직후의 pasteText 변경은 무시 - 복원된 항목(묶음·제목 수정)을 보존.
        if suppressRegenerate {
            suppressRegenerate = false
            return
        }
        let trimmed = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { drafts = []; return }
        let chunks = split(trimmed, mode: resolveMode(for: trimmed))
        drafts = chunks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .flatMap { makeDrafts(for: $0) }
    }

    private func resolveMode(for text: String) -> SplitMode {
        if splitMode != .auto { return splitMode }
        if text.range(of: #"^\s*(---|===)\s*$"#, options: [.regularExpression, .anchored]) != nil ||
            text.contains("\n---\n") || text.contains("\n===\n") {
            return .separator
        }
        if text.contains("\n\n") { return .blankLine }
        return .oneLinePerMemo
    }

    private func split(_ text: String, mode: SplitMode) -> [String] {
        switch mode {
        case .auto, .separator:
            // 구분선 (--- / ===) 우선, 그 다음 빈 줄
            let stage1 = splitByRegex(text, pattern: #"\n[-=]{3,}\n"#)
            return stage1.flatMap { splitByRegex($0, pattern: #"\n\s*\n"#) }
        case .blankLine:
            return splitByRegex(text, pattern: #"\n\s*\n"#)
        case .oneLinePerMemo:
            return text.components(separatedBy: "\n")
        }
    }

    /// 정규식 기반 분할 (NSRegularExpression - iOS 13+ 호환).
    private func splitByRegex(_ text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return [text] }
        var pieces: [String] = []
        var cursor = text.startIndex
        for m in matches {
            guard let r = Range(m.range, in: text) else { continue }
            pieces.append(String(text[cursor..<r.lowerBound]))
            cursor = r.upperBound
        }
        pieces.append(String(text[cursor...]))
        return pieces
    }

    // MARK: - Block Parsing (라벨/아이디/비밀번호 인식)

    /// 블록 하나를 1개 이상의 드래프트로 해석.
    private func makeDrafts(for chunk: String) -> [Draft] {
        let lines = chunk.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        if lines.count == 1 {
            let line = lines[0]
            return [Draft(title: makeTitle(for: line), values: [line])]
        }

        // 첫 줄이 서비스명(라벨)인지 - 짧고, 값 타입으로 분류되지 않는 텍스트.
        let first = lines[0]
        let firstIsLabel = isLabelLine(first)
        let values = firstIsLabel ? Array(lines.dropFirst()) : lines
        let base = firstIsLabel ? first : ""

        // 긴 설명 문장이 섞인 블록은 쪼개지 않는다 - 맥락이 사라진다.
        let hasProse = values.contains { $0.count > 32 && $0.contains(" ") }
        if hasProse || values.isEmpty {
            let value = values.isEmpty ? chunk : values.joined(separator: "\n")
            return [Draft(title: firstIsLabel ? first : makeTitle(for: chunk),
                          values: [value],
                          isSecure: secureByLabel(base))]
        }

        if values.count == 1 {
            return [Draft(title: base.isEmpty ? makeTitle(for: values[0]) : base,
                          values: [values[0]],
                          isSecure: secureByLabel(base))]
        }

        return labeledDrafts(base: base, values: values)
    }

    /// 값 여러 개 블록 → 아이디/비밀번호(2개) 또는 타입 라벨(3개 이상)로 항목 분리.
    private func labeledDrafts(base: String, values: [String]) -> [Draft] {
        let idLabel = NSLocalizedString("아이디", comment: "Bulk import: inferred label for login id")
        let pwLabel = NSLocalizedString("비밀번호", comment: "Bulk import: inferred label for password")

        if values.count == 2 {
            // 이메일이 있으면 그쪽이 아이디, 아니면 순서대로 [아이디, 비밀번호]
            let idIndex = values.firstIndex(where: isEmailLike) ?? 0
            let idValue = values[idIndex]
            let pwValue = values[1 - idIndex]
            // "구글아이디"처럼 라벨이 이미 '아이디'로 끝나면 접미어를 겹쳐 붙이지 않는다.
            let idTitle = (!base.isEmpty && base.hasSuffix(idLabel)) ? base : joinedTitle(base, idLabel)
            return [
                Draft(title: idTitle, values: [idValue]),
                Draft(title: joinedTitle(base, pwLabel), values: [pwValue], isSecure: true)
            ]
        }

        return values.enumerated().map { index, value in
            let detected = ClipboardClassificationService.shared.classify(content: value)
            let label = detected.confidence >= 0.7
                ? detected.type.localizedName
                : String(format: NSLocalizedString("값 %d", comment: "Bulk import: generic value label with number"), index + 1)
            let secure = detected.confidence < 0.7 && looksLikeSecret(value)
            return Draft(title: joinedTitle(base, label), values: [value], isSecure: secure)
        }
    }

    /// 라벨 줄 판정 - 짧고(25자 이하) 값 타입으로 분류되지 않으면 서비스명으로 본다.
    private func isLabelLine(_ text: String) -> Bool {
        guard text.count <= 25 else { return false }
        return ClipboardClassificationService.shared.classify(content: text).confidence < 0.7
    }

    private func isEmailLike(_ text: String) -> Bool {
        text.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }

    /// 라벨에 비밀번호류 키워드가 있으면 보안 기본 ON.
    private func secureByLabel(_ label: String) -> Bool {
        let lowered = label.lowercased()
        return ["비밀번호", "비번", "패스", "pass", "pw", "pin", "인증서", "password"]
            .contains { lowered.contains($0) }
    }

    /// 비밀번호처럼 보이는 값 - 공백 없는 4~32자 + 숫자 포함.
    private func looksLikeSecret(_ value: String) -> Bool {
        value.count >= 4 && value.count <= 32
            && !value.contains(" ")
            && value.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private func joinedTitle(_ base: String, _ label: String) -> String {
        base.isEmpty ? label : "\(base) \(label)"
    }

    private func makeTitle(for value: String) -> String {
        // 1) 자동 타입 감지
        let result = ClipboardClassificationService.shared.classify(content: value)
        if result.confidence >= 0.7 {
            return result.type.localizedName
        }
        // 2) 첫 줄 (40자 cap)
        let firstLine = value.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? value
        if firstLine.count <= 40 { return firstLine }
        return String(firstLine.prefix(37)) + "…"
    }

    // MARK: - OCR

    private func runOCR(on image: UIImage?) {
        guard let image else { return }
        isRecognizing = true
        OCRService.shared.recognizeBlocks(from: image) { blocks in
            isRecognizing = false
            appendOCRBlocks(blocks)
        }
    }

    /// OCR 블록을 입력창에 추가. 카드번호가 감지되면 노이즈(은행명·영문 이름 등) 대신
    /// 카드번호/유효기간 정형 블록으로 대체한다.
    private func appendOCRBlocks(_ blocks: [[String]]) {
        guard !blocks.isEmpty else {
            showOCREmptyAlert = true
            return
        }

        var resultBlocks = blocks
        let card = OCRService.shared.parseCardInfo(from: blocks.flatMap { $0 })
        if let number = card["카드번호"] {
            resultBlocks = [[NSLocalizedString("카드번호", comment: "Bulk import: card number label"), number]]
            if let expiry = card["유효기간"] {
                resultBlocks.append([NSLocalizedString("유효기간", comment: "Bulk import: card expiry label"), expiry])
            }
        }

        let text = resultBlocks
            .map { $0.joined(separator: "\n") }
            .joined(separator: "\n\n")
        pasteText = pasteText.isEmpty ? text : pasteText + "\n\n" + text
    }

    // MARK: - Save

    private func saveAll() {
        let toSave = drafts.filter { $0.include && !$0.value.isEmpty }
        guard !toSave.isEmpty else { return }

        do {
            var existing = (try? MemoStore.shared.load(type: .memo)) ?? []
            for d in toSave {
                let title = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalTitle = title.isEmpty
                    ? d.value.prefix(20).trimmingCharacters(in: .whitespacesAndNewlines)
                    : title

                // 묶인 항목은 콤보로 저장 (value는 비우고 comboValues에 단계 나열 - 샘플과 동일 패턴).
                // 보안 콤보는 단계 값을 각각 암호화 - 하나라도 실패하면 일반 콤보로 폴백.
                if d.isStack {
                    var steps = d.values
                    var isSecure = d.isSecure
                    if isSecure {
                        let encrypted = SecureMemoCrypto.encryptSteps(steps)
                        if encrypted.allSatisfy({ SecureMemoCrypto.isEncrypted($0) }) {
                            steps = encrypted
                        } else {
                            isSecure = false
                        }
                    }
                    existing.append(Memo(
                        title: finalTitle,
                        value: "",
                        isSecure: isSecure,
                        stackValues: steps
                    ))
                    continue
                }

                let detected = ClipboardClassificationService.shared.classify(content: d.value)
                let category = detected.confidence >= 0.7 ? detected.type.rawValue : "기본"
                // 보안 항목은 암호화해서 저장 - 키를 못 만들면 일반 단축어로 폴백.
                var value = d.value
                var isSecure = d.isSecure
                if isSecure {
                    if let encrypted = SecureMemoCrypto.encrypt(value) {
                        value = encrypted
                    } else {
                        isSecure = false
                    }
                }
                let memo = Memo(
                    title: finalTitle,
                    value: value,
                    category: category,
                    isSecure: isSecure
                )
                existing.append(memo)
            }
            try MemoStore.shared.save(memos: existing, type: .memo)
            AnalyticsService.logBulkImported(count: toSave.count)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            savedCount = toSave.count
            UserDefaults.standard.removeObject(forKey: Self.snapshotKey)   // 저장 완료 - 임시저장 정리
        } catch {
            print("❌ [BulkImportView.saveAll] 일괄 가져오기 저장 실패: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showSaveError = true
        }
    }
}

#Preview {
    BulkImportView()
}
