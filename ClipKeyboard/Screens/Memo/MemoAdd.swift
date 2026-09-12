//
//  MemoAdd.swift
//  ClipKeyboard
//
//  Created by hyunho lee on 2023/05/15.
//

import SwiftUI
#if os(iOS)
import UIKit
import LeeoKit
#endif

// MARK: - Image Wrapper
struct ImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MemoAdd: View {

    // MARK: - ViewModel

    @StateObject private var viewModel = MemoAddViewModel(
        saveMemoUseCase: SaveMemoUseCase(),
        memoRepository: MemoRepository()
    )

    // MARK: - Public Input Properties (backward compatibility)

    var memoId: UUID? // 수정할 메모의 ID
    var insertedKeyword: String = ""
    var insertedValue: String = ""
    var insertedCategory: String = "텍스트"
    var insertedIsTemplate: Bool = false
    var insertedIsSecure: Bool = false
    var insertedIsStack: Bool = false
    var insertedStackValues: [String] = []
    var insertedHint: String = ""
    var insertedIsFavorite: Bool = false
    /// "임시 저장 보기"에서 이어쓰기로 진입했을 때 그 드래프트 id - 저장/폐기 시 해당 드래프트를 정리한다.
    var resumeDraftId: UUID? = nil
    /// "템플릿으로 만들기"로 진입했을 때 true - 본문에 포커스를 줘 변수 삽입바를 바로 노출.
    var startInTemplateMode: Bool = false
    /// "템플릿으로 만들기"의 원본 단축어 id - 있으면 "기존 단축어 남기기" 토글이 노출되고,
    /// 끄면 저장할 때 원본이 함께 삭제된다(중복 방지).
    var templateSourceMemoId: UUID? = nil
    // MARK: - View-only State

    @State private var isFocused: Bool = false
    /// "쓸 때 채우는 칸" 서랍이 펴져 있는가. **기본은 닫힘**(`DefaultsKey.contentTokenBarExpanded`).
    @AppStorage(DefaultsKey.contentTokenBarExpanded) private var tokenBarExpanded: Bool = false
    @FocusState private var isTitleFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 저장해 둔 빈칸 값을 통째로 손보는 시트 - 빈칸을 다루는 이 자리에서 바로 연다.
    /// 여러 줄을 한꺼번에 붙여넣은 순간, 나눠 담을지 묻는다. 값은 줄 수.
    ///
    /// ⚠️ 한 화면에서 **한 번만** 묻는다. 붙여넣을 때마다 물으면 잔소리가 된다.
    @State private var splitOfferLineCount: Int?
    @State private var didOfferSplit = false
    @State private var showBulkImportFromPaste = false
    @State private var showPlaceholderManagement = false
    @State private var showNewTemplateSheet = false
    @State private var showResetConfirm = false
    /// 저장 화면에서 카테고리를 새로 만들 때 쓰는 이름 입력.
    @State private var showNewCategoryPrompt = false
    @State private var newCategoryName = ""

    // MARK: - 처음 만드는 사람 짚어 주기 (MemoAddCoach.swift)

    /// 지금 짚고 있는 칸. nil 이면 안내가 돌고 있지 않다.
    @State private var coachStep: MemoAddCoachStep?
    @AppStorage(DefaultsKey.startedFreshV444) private var startedFresh: Bool = false
    @AppStorage(DefaultsKey.tutorialMakeOwnDone) private var makeOwnDone: Bool = false
    @AppStorage(DefaultsKey.tutorialMakeOwnCoachSkipped) private var coachSkipped: Bool = false
    /// 기존 단축어를 골라 값으로 가져오는 시트.
    @State private var showStackImport: Bool = false

    var body: some View {
        addBody
        .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {}
        .alert(NSLocalizedString("입력 내용 초기화", comment: "Reset form confirm title"),
               isPresented: $showResetConfirm) {
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("초기화", comment: "Confirm reset"), role: .destructive) {
                viewModel.reset()
            }
        } message: {
            Text(NSLocalizedString("입력한 내용이 모두 지워집니다. 계속하시겠습니까?", comment: "Reset form confirm message"))
        }
        // 저장 화면에서 곧바로 카테고리를 만든다. 만드는 길이 없으면 카테고리를 하나도
        // 안 만든 사람에게는 위 줄이 "기본" 하나뿐인 고장난 칸으로 보인다.
        .alert(NSLocalizedString("새 카테고리", comment: "Create a new category from the add screen"),
               isPresented: $showNewCategoryPrompt) {
            TextField(NSLocalizedString("카테고리 이름", comment: "New category name field"), text: $newCategoryName)
            Button(NSLocalizedString("취소", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("카테고리 만들기", comment: "Create category button in the add screen")) {
                viewModel.createAndSelectUserCategory(newCategoryName)
            }
        }
        .overlay {
            if viewModel.showToast {
                VStack {
                    Spacer()
                    Text(viewModel.toastMessage)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(theme.radiusSm)
                        .padding(.bottom, 100)
                        .accessibilityHidden(true)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.showToast)
            }
        }
        .onChange(of: viewModel.showToast) { _, isShowing in
            #if os(iOS)
            if isShowing {
                UIAccessibility.post(notification: .announcement, argument: viewModel.toastMessage)
            }
            #endif
        }
        .sheet(isPresented: $viewModel.showEmojiPicker) {
            EmojiPicker { selectedEmoji in
                viewModel.value += selectedEmoji
            }
        }
        .paywall(isPresented: $viewModel.showPaywall, triggeredBy: viewModel.paywallTrigger)
        #if os(iOS)
        .sheet(isPresented: $viewModel.showDocumentScanner) {
            DocumentCameraView { result in
                if case .success(let images) = result {
                    viewModel.processOCRImages(images)
                }
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView { image in
                if let image = image {
                    viewModel.processOCRImages([image])
                }
            }
        }
        .sheet(isPresented: $viewModel.showOCRPicker) {
            OCRTextPickerSheet(candidates: viewModel.ocrCandidates) { lines in
                viewModel.applyOCRSelection(lines)
            }
        }
        .overlay {
            if viewModel.isProcessingOCR {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5).tint(.white)
                        Text(NSLocalizedString("텍스트 인식 중...", comment: "Recognizing text"))
                            .foregroundColor(.white).font(.headline)
                    }
                    .padding(32).background(theme.surface).cornerRadius(theme.radiusLg)
                }
            }
        }
        #endif
        .onAppear {
            viewModel.resumedDraftId = resumeDraftId
            viewModel.templateSourceMemoId = templateSourceMemoId
            viewModel.onAppear(
                memoId: memoId,
                insertedKeyword: insertedKeyword,
                insertedValue: insertedValue,
                insertedCategory: insertedCategory,
                insertedIsTemplate: insertedIsTemplate,
                insertedIsSecure: insertedIsSecure,
                insertedIsStack: insertedIsStack,
                insertedStackValues: insertedStackValues,
                insertedHint: insertedHint,
                insertedIsFavorite: insertedIsFavorite
            )
            // "템플릿으로 만들기" 진입 - 시트가 안착한 뒤 본문에 포커스를 줘
            // 변수 삽입바({이름}/{날짜}…)를 바로 띄운다.
            if startInTemplateMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            }
        }
        .onChange(of: viewModel.value) { oldValue, newValue in
            viewModel.onValueChanged()
            offerSplitIfPastedList(from: oldValue, to: newValue)
        }
        // 붙여넣은 것이 목록처럼 생겼다. **이미 그 일을 하고 있는 중**이라 지금이 묻기 좋은 때다.
        .alert(splitOfferTitle,
               isPresented: Binding(get: { splitOfferLineCount != nil },
                                    set: { if !$0 { splitOfferLineCount = nil } })) {
            Button(NSLocalizedString("나눠 담기", comment: "Accept splitting a pasted list into separate snippets")) {
                splitOfferLineCount = nil
                showBulkImportFromPaste = true
            }
            Button(NSLocalizedString("그대로 두기", comment: "Keep the pasted text as one snippet"),
                   role: .cancel) { splitOfferLineCount = nil }
        } message: {
            Text(NSLocalizedString("한 줄씩 나눠서 담으면 키보드에서 따로따로 꺼내 쓸 수 있어요.",
                                   comment: "Explanation for splitting a pasted list"))
        }
        .sheet(isPresented: $showBulkImportFromPaste) {
            // 붙여넣던 글을 그대로 들고 간다. 같은 것을 두 번 붙여넣게 하지 않는다.
            BulkImportView(initialText: viewModel.value)
        }
        .onDisappear {
            // 저장 없이 화면을 떠나면 사용자가 직접 입력한 내용을 자동 임시저장(드래프트)한다.
            // (정식 저장·기존 메모 편집·샘플 그대로 등은 VM 내부에서 걸러진다.)
            viewModel.saveDraftIfNeeded()
        }
        // ── 처음 만드는 사람 짚어 주기 (MemoAddCoach.swift) ──
        .onAppear { startCoachIfNeeded() }
        // 이름 칸에서 손을 뗐다 - 다 적었으면 다음 칸으로.
        .onChange(of: isTitleFocused) { _, focused in
            if !focused { advanceCoachIfFilled() }
        }
        // 내용 칸에서 손을 뗐다 - 같은 규칙.
        .onChange(of: isFocused) { _, focused in
            if !focused { advanceCoachIfFilled() }
        }
        // 사진을 붙이는 길로 값을 채운 사람은 칸을 떠나는 일이 없다 - 여기서 따로 본다.
        .onChange(of: viewModel.attachedImages.count) { _, _ in advanceCoachIfFilled() }
        .sheet(isPresented: $showPlaceholderManagement) {
            PlaceholderManagementSheet(allMemos: (try? MemoStore.shared.load(type: .memo)) ?? [])
        }
        .sheet(isPresented: $showNewTemplateSheet) {
            NavigationView {
                MemoAdd(insertedIsTemplate: true)
                    .navigationTitle(NSLocalizedString("새 템플릿", comment: "New template nav title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(NSLocalizedString("취소", comment: "Cancel")) {
                                showNewTemplateSheet = false
                            }
                        }
                    }
            }
        }
        .navigationTitle({
            if memoId != nil {
                if insertedIsTemplate { return NSLocalizedString("단축어 수정 타이틀_템플릿", comment: "Edit template navigation title") }
                if insertedIsStack { return NSLocalizedString("단축어 수정 타이틀_콤보", comment: "Edit combo navigation title") }
                return NSLocalizedString("단축어 수정", comment: "Edit memo navigation title")
            }
            if insertedIsTemplate { return NSLocalizedString("새 템플릿", comment: "New template navigation title") }
            if insertedIsStack { return NSLocalizedString("새 콤보", comment: "New combo navigation title") }
            return NSLocalizedString("새 단축어", comment: "New memo navigation title")
        }())
        .navigationBarTitleDisplayMode(.inline)
        .solidNavBar(theme.bg)
    }

    // MARK: - 처음 만드는 사람 짚어 주기

    /// 저장 버튼이 지금 눌리는가. **잠금 조건과 안내가 같은 값을 봐야** 한다
    /// (`validateMemoInput` 과 같은 기준: 글이든 그림이든 하나는 있어야).
    private var canSave: Bool {
        !(viewModel.value.isEmpty && viewModel.attachedImages.isEmpty)
    }

    /// 지금 이 화면에서 안내를 켤 자리인가.
    ///
    /// ⚠️ **튜토리얼의 마지막 걸음일 때만** 켠다(`SnippetsOnboardingStep.makeOwn`).
    ///    쓰던 사람이 단축어를 만들 때마다 띠가 뜨면 그건 안내가 아니라 방해다.
    ///
    /// ⚠️ 새로 만드는 화면에서만. 고치러 들어온 사람은 이미 만들어 본 사람이고,
    ///    무엇보다 이름·내용이 채워져 있어 첫 두 걸음이 그 자리에서 지나가 버린다.
    private var coachShouldRun: Bool {
        startedFresh && !makeOwnDone && !coachSkipped
            && memoId == nil
            && viewModel.keyword.isEmpty && viewModel.value.isEmpty
    }

    /// 화면이 자리를 잡은 뒤에 띠를 올린다. 열리자마자 같이 뜨면 무엇에 대한
    /// 안내인지 보기 전에 띠부터 보게 된다.
    private func startCoachIfNeeded() {
        guard coachShouldRun, coachStep == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard coachShouldRun, coachStep == nil else { return }
            withAnimation(.easeOut(duration: 0.28)) { coachStep = .name }
            print("🎓 [MemoAdd] 새 단축어 안내 시작")
        }
    }

    /// 한 걸음 나아간다. 마지막(저장)에서 부르면 안내가 끝난다.
    ///
    /// ⚠️ 저장 걸음은 **여기서 끝내지 않는다.** 저장은 사용자가 눌러야 일어나는 일이라
    ///    띠를 눌러 지나갈 수 있게 두되, 지나가도 `makeOwnDone` 은 건드리지 않는다.
    ///    자기 것이 생겼는지는 목록이 스스로 센다(`completeMakeOwnIfMadeSomething`).
    private func advanceCoach(from step: MemoAddCoachStep) {
        withAnimation(.easeOut(duration: 0.24)) { coachStep = step.next }
    }

    /// 안내가 필요 없다고 한 사람. 다시 걸리적거리지 않는다.
    private func skipCoach() {
        HapticManager.shared.light()
        coachSkipped = true
        withAnimation(.easeOut(duration: 0.24)) { coachStep = nil }
        print("🎓 [MemoAdd] 새 단축어 안내 끔")
    }

    /// 채워야 할 것을 채웠으면 **누르지 않아도** 다음으로 넘어간다.
    /// 다 한 칸을 계속 짚고 있으면 안내가 아니라 잔소리가 된다.
    ///
    /// ⚠️ 부르는 자리가 중요하다. 글자가 바뀔 때마다 부르면 **이름을 치는 도중에**
    ///    다음 걸음으로 달아난다. 칸에서 손을 뗐을 때(포커스가 빠질 때)와
    ///    사진을 붙였을 때만 묻는다.
    private func advanceCoachIfFilled() {
        guard let step = coachStep else { return }
        guard step.isFilled(title: viewModel.keyword,
                            value: viewModel.value,
                            hasImage: !viewModel.attachedImages.isEmpty) else { return }
        advanceCoach(from: step)
    }

    // MARK: - Body

    /// 새로 만들 때든 고칠 때든 **같은 화면**이다.
    ///
    /// 예전에는 새 단축어만 심플 모드로 열고 보안·템플릿·콤보·카테고리를
    /// "더 설정하기" 뒤에 접어 두었다. 접어 두면 있는 줄을 모르고, 쓰려면
    /// 한 번 더 눌러야 한다. 접는 것으로 아끼는 자리보다 못 찾는 값이 크다.
    private var addBody: some View {
        VStack(spacing: 0) {
            // ⚠️ 클립보드를 훔쳐보고 "이건 이메일 같은데요" 하던 제안 배너는 없앴다.
            //    화면이 뜰 때마다 클립보드를 읽어 갈래를 맞히는 일인데, 맞혀서 얻는 것이
            //    붙여넣기 한 번뿐이었다. 붙여넣기는 아래 값 채우는 줄에 그대로 있다.

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 28) {
                        // 📌 키보드에 표시할 이름 - 단축어의 정체성이므로 맨 위
                        titleInputSection
                            .memoAddCoachRipple(coachStep == .name, radius: theme.radiusMd)

                        // 📌 붙여넣을 내용
                        ContentInputSection(
                            value: $viewModel.value,
                            selectedCategory: viewModel.selectedCategory,
                            isFocused: $isFocused,
                            autoDetectedType: $viewModel.autoDetectedType,
                            autoDetectedConfidence: $viewModel.autoDetectedConfidence,
                            attachedImages: $viewModel.attachedImages,
                            onNext: { isFocused = false },   // 이름이 위로 가서 "다음" 필드 없음 - 입력 종료
                            onAddContent: {
                                HapticManager.shared.light()
                                viewModel.addContinuation()
                            },
                            forceTextKeyboard: startInTemplateMode,
                            // 이 칸은 둘로 나뉜다(값 가져오는 줄 · 실제 내용). 안내도 따로 짚는다.
                            coachStep: coachStep
                        )
                        .id("contentField")

                        // 검증 각인 - 체크섬이 있는 값이면 "맞았다"를 눈에 보이게.
                        // 확실할 때만 뜬다(형식이 모호하면 nil) - ChecksumVerifier 주석 참고.
                        if let verification = ChecksumVerifier.verify(viewModel.value) {
                            VerificationSealView(result: verification)
                        }

                        // 붙여넣을 내용이 여러 개면 바로 아래에서 추가 - 더하면 콤보
                        continuationsSection

                        // 📌 내용 힌트 (카드·키보드에서 살며시 보일 한 줄, 선택)
                        hintInputSection

                        // 📌 어느 칸에 넣을지 - **저장하기 전에** 고른다.
                        //    (예전에는 기본으로 저장된 뒤 손으로 옮겨야 했다)
                        categoryPickerSection

                        // 📌 추가 옵션 (보안)
                        additionalOptionsSection
                        // 변수가 있으면 자동으로 템플릿 도우미 노출
                        templateSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
                // 하단 버튼 영역 - 키보드 바로 위에 딱 붙는 영역
                .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()

                    // 본문 포커스 시 변수 삽입 버튼 표시 - {변수}를 넣으면 자동으로 템플릿이 됨
                    if isFocused {
                        variableTokenBar
                        Divider()
                    }

                    HStack(spacing: 12) {
                        Button {
                            let hasContent = !viewModel.value.isEmpty || !viewModel.keyword.isEmpty || !viewModel.attachedImages.isEmpty
                            if hasContent {
                                showResetConfirm = true
                            } else {
                                viewModel.reset()
                            }
                        } label: {
                            HStack {
                                Image(systemName: AppSymbol.arrowCounterclockwise)
                                    .accessibilityHidden(true)
                                Text(NSLocalizedString("초기화", comment: "Reset"))
                            }
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(theme.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.surfaceAlt)
                            .cornerRadius(theme.radiusMd)
                        }
                        .accessibilityHint(NSLocalizedString("입력한 내용과 이름을 지웁니다. 카테고리는 그대로 둡니다", comment: "Reset button hint v2"))

                        if isFocused {
                            // 내용 입력 중: 입력을 마치고 키보드를 내린다 (이름은 위에 있어 "다음"이 없음)
                            Button {
                                isFocused = false
                            } label: {
                                HStack {
                                    Text(NSLocalizedString("완료", comment: "Done"))
                                    Image(systemName: "keyboard.chevron.compact.down")
                                        .accessibilityHidden(true)
                                }
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.accentForeground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .cornerRadius(theme.radiusMd)
                            }
                        } else {
                            Button {
                                // 이름을 안 적었으면 내용 첫 줄로 짓는다. 이름 때문에
                                // 저장이 막히면 방금 적은 것을 못 넣고 되돌아간다.
                                if viewModel.keyword.isEmpty {
                                    viewModel.keyword = viewModel.autoGeneratedTitle()
                                }
                                viewModel.saveMemo { dismiss() }
                            } label: {
                                HStack {
                                    Image(systemName: AppSymbol.checkmark)
                                        .accessibilityHidden(true)
                                    Text(NSLocalizedString("저장", comment: "Save"))
                                }
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.accentForeground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .cornerRadius(theme.radiusMd)
                            }
                            // 글이든 그림이든 하나는 있어야 저장이 된다 - `validateMemoInput` 과 같은 기준.
                            .disabled(!canSave)
                            // ⚠️ **잠긴 버튼은 가리키지 않는다.** 누를 수 없는 것이 물결치면
                            //    그건 안내가 아니라 고장이다. 아직 못 누르는 사람에게는
                            //    아래 띠가 대신 무엇이 남았는지 말한다.
                            .memoAddCoachRipple(coachStep == .save && canSave,
                                                radius: theme.radiusMd, reach: 6)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    // 짚어 주는 띠는 도구 줄 **아래**에 눕는다 - 위로 오면 도구를 가린다.
                    if let step = coachStep {
                        MemoAddCoachBar(step: step,
                                        canSave: canSave,
                                        onNext: { advanceCoach(from: step) },
                                        onSkip: { skipCoach() })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .background(theme.surface)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                            proxy.scrollTo("contentField", anchor: .top)
                        }
                    }
                }
            }  // ScrollViewReader
        }
    }

    // MARK: - View Sections

    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("키보드에 표시할 이름", comment: "Memo title label: what user sees on the keyboard"))
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(theme.textMuted)

            TextField(NSLocalizedString("예: 회사 이메일, 송금 계좌", comment: "Memo title field placeholder"), text: $viewModel.keyword)
                .font(.title3)
                .fontWeight(.semibold)
                .focused($isTitleFocused)
                // 이름이 맨 위 필드 - 리턴 키로 아래 내용 입력칸으로 자연스럽게 이동.
                .submitLabel(.next)
                .onSubmit {
                    isTitleFocused = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isFocused = true }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(theme.surfaceAlt)
                .cornerRadius(theme.radiusMd)
                // VoiceOver가 placeholder 대신 필드의 의미("키보드에 표시할 이름")를 읽도록 명시.
                .accessibilityLabel(NSLocalizedString("키보드에 표시할 이름", comment: "Memo title label: what user sees on the keyboard"))
        }
    }

    /// 내용 힌트(선택) - 카드 힌트·키보드 스왑에서 자동 요약 대신 보여줄 한 줄을 직접 정한다.
    /// 힌트를 쓰면 "키보드에 표시할 이름과 같이 표시" 동기화 토글이 나타난다(기본 ON).
    private var hintInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("내용 힌트 (선택)", comment: "Custom content hint label"))
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(theme.textMuted)

            TextField(NSLocalizedString("카드에 살며시 보여줄 한 줄, 비우면 자동 요약", comment: "Custom hint field placeholder"),
                      text: $viewModel.hint)
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(theme.surfaceAlt)
                .cornerRadius(theme.radiusMd)
                .accessibilityLabel(NSLocalizedString("내용 힌트 (선택)", comment: "Custom content hint label"))

            if !viewModel.hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Toggle(isOn: $viewModel.hintShownOnKeyboard) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("키보드에 표시할 이름과 같이 표시", comment: "Hint keyboard sync toggle"))
                            .font(.body)
                        Text(NSLocalizedString("키보드에서 이름이 잠시 이 힌트로 바뀌었다 돌아와요.", comment: "Hint keyboard sync description"))
                            .font(.caption)
                            .foregroundColor(theme.textFaint)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.hint.isEmpty)
    }

    /// 어느 카테고리에 넣을지 고르는 줄.
    ///
    /// ⚠️ "추가 옵션" 안이 아니라 **본문 바로 아래**에 둔다. 여기에 온 피드백이
    ///    "기본 가서 다시 카테고리로 보내는 게 불편하다"였다. 접혀 있으면 못 찾고,
    ///    못 찾으면 예전처럼 저장한 뒤에 옮기게 된다.
    ///
    /// ⚠️ 카테고리 탭에서 + 로 들어왔으면 그 칸이 이미 골라져 있다. 그때는 이 줄이
    ///    "어디로 가는지 확인해 주는 자리"가 된다 - 손댈 일이 없어야 정상이다.
    private var categoryPickerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: AppSymbol.folderBadgeGearshape)
                .font(.body)
                .foregroundColor(theme.textMuted)
                .accessibilityHidden(true)

            Text(NSLocalizedString("카테고리", comment: "Category picker label in add screen"))
                .font(.body)
                .foregroundColor(theme.text)

            Spacer()

            Menu {
                Button {
                    HapticManager.shared.light()
                    viewModel.selectUserCategory("")
                } label: {
                    Label(NSLocalizedString("기본", comment: "Default category (no user category)"),
                          systemImage: viewModel.userCategory.isEmpty ? AppSymbol.checkmark : "")
                }
                ForEach(viewModel.availableUserCategories, id: \.self) { name in
                    Button {
                        HapticManager.shared.light()
                        viewModel.selectUserCategory(name)
                    } label: {
                        Label(name, systemImage: viewModel.userCategory == name ? AppSymbol.checkmark : "")
                    }
                }
                Divider()
                Button {
                    HapticManager.shared.light()
                    newCategoryName = ""
                    showNewCategoryPrompt = true
                } label: {
                    Label(NSLocalizedString("새 카테고리", comment: "Create a new category from the add screen"),
                          systemImage: AppSymbol.plus)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.userCategory.isEmpty
                         ? NSLocalizedString("기본", comment: "Default category (no user category)")
                         : viewModel.userCategory)
                        .font(.body)
                        .fontWeight(.medium)
                    Image(systemName: AppSymbol.chevronUpChevronDown)
                        .font(.caption2)
                }
                .foregroundColor(theme.accent)
            }
            .accessibilityLabel(NSLocalizedString("카테고리", comment: "Category picker label in add screen"))
            .accessibilityValue(viewModel.userCategory.isEmpty
                                ? NSLocalizedString("기본", comment: "Default category (no user category)")
                                : viewModel.userCategory)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.surfaceAlt)
        .cornerRadius(theme.radiusMd)
    }

    private var additionalOptionsSection: some View {
        VStack(spacing: 12) {
            ToggleOptionRow(
                activeIcon: "lock.fill",
                inactiveIcon: "lock",
                title: NSLocalizedString("보안 단축어", comment: "Secure memo toggle"),
                description: NSLocalizedString("Face ID로 보호", comment: "Face ID protection description"),
                activeColor: .orange,
                isOn: Binding(
                    get: { viewModel.isSecure },
                    set: { newValue in
                        if newValue && !ProFeatureManager.isBiometricLockAvailable {
                            viewModel.paywallTrigger = .biometricLock
                            viewModel.showPaywall = true
                        } else {
                            viewModel.isSecure = newValue
                        }
                    }
                )
            )

            // 키보드가 스스로 배운 캐럿 자리. **배운 게 있을 때만** 나타난다.
            // 아무것도 안 배웠을 때도 자리를 차지하면, 조용히 해 주려던 것이
            // 설정 항목 하나로 바뀐다.
            cursorMemoryRow

            // "템플릿으로 만들기"로 들어온 경우 - 원본 단축어를 남길지 선택.
            // 끄면 저장할 때 원본이 함께 삭제된다(비슷한 단축어 중복 방지).
            if templateSourceMemoId != nil {
                ToggleOptionRow(
                    activeIcon: "square.on.square",
                    inactiveIcon: "square.on.square.dashed",
                    title: NSLocalizedString("기존 단축어 남기기", comment: "Keep original snippet toggle"),
                    description: NSLocalizedString("끄면 저장할 때 원본 단축어가 삭제돼요", comment: "Keep original snippet toggle description"),
                    activeColor: .accentColor,
                    isOn: $viewModel.keepOriginalSource
                )
            }
        }
    }

    /// 알림 제목 - 줄 수를 그대로 말한다. "여러 개"보다 "12개"가 훨씬 잘 와닿는다.
    private var splitOfferTitle: String {
        String(format: NSLocalizedString("줄이 %d개네요. 하나씩 나눠 담을까요?",
                                         comment: "Ask whether to split a pasted multi-line text into separate snippets"),
               splitOfferLineCount ?? 0)
    }

    /// 한꺼번에 크게 늘어난 글이 목록처럼 생겼으면 묻는다.
    ///
    /// ⚠️ 손으로 친 것과 붙여넣은 것을 글자 수가 뛴 폭으로 가른다. 타이핑은 한 글자씩 는다.
    /// ⚠️ 이미 물었으면 다시 묻지 않고, 편집 중인 단축어에서는 아예 묻지 않는다
    ///    (있던 글을 나누자고 하는 건 다른 이야기다).
    private func offerSplitIfPastedList(from oldValue: String, to newValue: String) {
        guard !didOfferSplit, viewModel.editingMemo == nil else { return }
        guard newValue.count - oldValue.count >= 20 else { return }
        guard let lines = BulkImportNudge.splittableLineCount(in: newValue) else { return }
        didOfferSplit = true
        splitOfferLineCount = lines
    }

    /// 배운 캐럿 자리를 보여주고 끄는 자리. 배운 게 있을 때만 나타난다.
    @ViewBuilder
    private var cursorMemoryRow: some View {
        if let memo = viewModel.editingMemo, CursorMemory.hasSwitch(for: memo.id) {
            CursorMemoryToggleRow(memoId: memo.id)
        }
    }

    /// "내용 더 넣기" - 붙여넣을 내용을 이어 더하면 자동으로 콤보가 된다(본문=1단계, 아래 칸=2단계~).
    /// 내용 입력칸 바로 아래에 배치. 이미지가 첨부돼 있어도 값을 더 넣을 수 있다(이미지+여러 값 허용).
    private var continuationsSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                // ⚠️ 인덱스가 아니라 **단계 자체**를 돌린다. 인덱스로 돌면서 배열에 바인딩을 걸면
                //    한 칸을 지우는 순간 옛 인덱스로 바인딩을 한 번 더 읽어 앱이 죽는다
                //    (`ContinuationStep` 머리말 참고). 번호만 지금 자리에서 세어 보여 준다.
                ForEach($viewModel.continuations) { $step in
                    let number = (viewModel.continuations.firstIndex(of: step) ?? 0) + 2
                    HStack(spacing: 8) {
                        Text("\(number).")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(theme.textFaint)
                        TextField(NSLocalizedString("이어서 입력할 내용", comment: "Continuation field placeholder"),
                                  text: $step.text, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            // 본문 편집기와 동일 - 붙여넣을 원문이라 자동 대문자/수정 금지.
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button {
                            viewModel.removeContinuation(id: step.id)
                        } label: {
                            Image(systemName: AppSymbol.minusCircleFill)
                                .foregroundColor(theme.textFaint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(NSLocalizedString("이 단계 삭제", comment: "Delete continuation step"))
                    }
                }

                Button {
                    HapticManager.shared.light()
                    viewModel.addContinuation()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.plusCircle)
                            .font(.body)
                        Text(NSLocalizedString("내용 더 넣기", comment: "Add another content value button"))
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.surfaceAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMd)
                            .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                    .cornerRadius(theme.radiusMd)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("내용 더 넣기", comment: "Add another content value button"))
                .accessibilityHint(NSLocalizedString("내용을 더 추가하면 콤보 단축어가 됩니다", comment: "Add content button hint"))

                // 기존 단축어 값 가져오기 - 이미 만든 단축어들을 골라 그 값을 이 콤보에 복사한다.
                Button {
                    HapticManager.shared.light()
                    showStackImport = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up")
                        Text(NSLocalizedString("기존 단축어에서 가져오기", comment: "Import values from existing snippets"))
                    }
                    .font(.subheadline)
                    .foregroundColor(theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radiusMd)
                            .strokeBorder(theme.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if !viewModel.continuations.isEmpty {
                    Text(NSLocalizedString("내용을 이어 더하면 콤보가 돼요. 키보드에서 순서대로 입력됩니다.", comment: "Continuation/combo explanation"))
                        .font(.caption)
                        .foregroundColor(theme.textFaint)
                }
            }
            .sheet(isPresented: $showStackImport) {
                StackImportSheet { values in
                    viewModel.continuations.append(contentsOf: values.map(ContinuationStep.init(text:)))
                }
            }
    }

    @ViewBuilder
    private var templateSection: some View {
        if !viewModel.detectedPlaceholders.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.infoCircleFill)
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                        Text(NSLocalizedString("{ }로 감싼 부분은 쓸 때마다 새로 채우는 칸이에요", comment: "Template token explanation title"))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textMuted)
                    }
                    Text(NSLocalizedString("예) “입금액 {금액}원” → 단축어를 쓸 때 금액만 새로 넣어 재사용해요. 그냥 ‘금액’이라고 쓰면 글자 그대로 고정됩니다.", comment: "Template token vs plain text example"))
                        .font(.caption)
                        .foregroundColor(theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 이미 쓰는 빈칸 - 다른 단축어에서 쓰던 것을 그대로 가져다 쓴다.
                // ⚠️ 권하는 것보다 **먼저** 놓는다. 값이 따라오는 쪽이 먼저 눈에 들어와야
                //    같은 빈칸을 이름만 다르게 새로 만드는 일이 줄어든다.
                UsedPlaceholderBar { token in
                    viewModel.value += token
                }

                // 자주 쓰는 빈칸 - 아직 아무것도 안 만든 사람에게도 시작할 자리를 준다.
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("자주 쓰는 빈칸", comment: "Suggested placeholders label"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // 숫자 입력 타입 - 삽입 토큰도 로케일에 맞춤(영어는 {amount} 등).
                            quickInsertToken(NSLocalizedString("{금액}", comment: "Amount token variable"), isNumeric: true)
                            quickInsertToken(NSLocalizedString("{수량}", comment: "Quantity token variable"), isNumeric: true)
                            quickInsertToken(NSLocalizedString("{가격}", comment: "Price token variable"), isNumeric: true)
                            // 텍스트 선택 타입
                            quickInsertToken(NSLocalizedString("{이름}", comment: "Name token variable"), isNumeric: false)
                            quickInsertToken(NSLocalizedString("{메모}", comment: "Memo token variable"), isNumeric: false)
                            quickInsertToken(NSLocalizedString("{주소}", comment: "Address token variable"), isNumeric: false)
                        }
                    }

                    // 타입 범례
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: AppSymbol.number)
                                .font(.system(.caption2))
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("숫자 입력 (키보드에서 숫자패드 표시)", comment: "Numeric token legend"))
                                .font(.system(.caption2))
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: AppSymbol.listBullet)
                                .font(.system(.caption2))
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("선택지 (저장된 값 중 선택)", comment: "Selection token legend"))
                                .font(.system(.caption2))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()

            // 빈칸 값 설정
            if !viewModel.detectedPlaceholders.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: AppSymbol.listBulletRectangle)
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("빈칸 값 설정", comment: "Placeholder value settings"))
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer(minLength: 8)
                        // ⚠️ 여기가 **빈칸을 다루는 그 자리**다. 예전에는 저장해 둔 값을
                        //    손보려면 이 화면을 저장하고 나가서 설정까지 들어가야 했다.
                        //    쓰는 자리와 고치는 자리가 멀면 고치지 않고 그냥 쓴다.
                        Button {
                            HapticManager.shared.light()
                            showPlaceholderManagement = true
                        } label: {
                            Text(NSLocalizedString("전체 관리", comment: "Manage all placeholder values"))
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(viewModel.detectedPlaceholders, id: \.self) { placeholder in
                        PlaceholderValueEditor(
                            placeholder: placeholder,
                            values: Binding(
                                get: { viewModel.placeholderValues[placeholder] ?? [] },
                                set: { viewModel.placeholderValues[placeholder] = $0 }
                            )
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(theme.radiusMd)
            }
        }
    }

    // MARK: - Attached Template (v4.0.8)

    /// 사용자가 만든 템플릿 메모 목록. 본 메모(`isTemplate=false`)는 자연스레 제외됨.
    private var availableTemplates: [Memo] {
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        return memos.filter { $0.isTemplate }
    }

    // MARK: - 쓸 때 채우는 칸 (서랍)

    /// 키보드 위에 뜨는 템플릿 변수 옵션 바 - 본문(붙여넣을 내용) 입력 중에만 노출.
    /// 탭하면 커서 위치에 {변수}가 삽입되어 자동으로 템플릿이 된다.
    ///
    /// ⚠️ **닫힌 채로 시작한다.** 예전에는 내용 칸에 커서가 닿는 순간 파란 버튼 아홉 개가
    ///    통째로 올라왔다. 이 화면에 온 사람의 대부분은 그냥 글 한 줄을 적으러 온 것이라,
    ///    그 줄은 도움이 아니라 **"이걸 다 골라야 하나"** 라는 물음이 됐다.
    ///
    /// ⚠️ 그래도 **줄 자체는 남긴다.** 통째로 감추면 빈칸이라는 기능이 있다는 것을
    ///    아무도 모르게 된다(그 줄을 처음 넣은 이유가 그것이다). 접힌 손잡이 한 줄이
    ///    "여기 뭔가 더 있다"를 말하고, 펴는 것은 그 사람이 정한다.
    private var variableTokenBar: some View {
        VStack(spacing: 0) {
            tokenBarHandle
            if tokenBarExpanded {
                tokenBarRow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .clipped()   // 접힐 때 아래로 미끄러지는 줄이 손잡이 위로 삐져나오지 않게
    }

    /// 접었다 펴는 손잡이 한 줄.
    ///
    /// ⚠️ 여는 방법을 **글로 적는다.** 화살표만 두면 그게 무엇을 펴는 것인지 모른다.
    ///    닫혀 있을 때는 무엇이 들어 있는지도 한 줄로 일러 준다.
    private var tokenBarHandle: some View {
        Button {
            HapticManager.shared.light()
            withAnimation(.easeInOut(duration: 0.22)) { tokenBarExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: AppSymbol.curlybraces)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.accentColor)
                Text(NSLocalizedString("쓸 때 채우는 칸", comment: "Fill-in field label prefix for token bar"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.text)
                if !tokenBarExpanded {
                    Text(NSLocalizedString("이름·날짜처럼 쓸 때마다 달라지는 자리",
                                           comment: "Fill-in field drawer: collapsed subtitle"))
                        .font(.caption)
                        .foregroundColor(theme.textFaint)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                Image(systemName: tokenBarExpanded ? AppSymbol.chevronDown : AppSymbol.chevronUp)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("쓸 때 채우는 칸", comment: "Fill-in field label prefix for token bar"))
        .accessibilityHint(tokenBarExpanded
            ? NSLocalizedString("접으려면 두 번 탭하세요", comment: "Fill-in field drawer: collapse hint")
            : NSLocalizedString("펼치려면 두 번 탭하세요", comment: "Fill-in field drawer: expand hint"))
        .accessibilityAddTraits(.isButton)
    }

    // 템플릿 변수 버튼
    @ViewBuilder
    private var tokenBarRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 삽입되는 토큰도 로케일에 맞춘다 (영어는 {amount} 등). 프로세서가 양쪽 인식.
                templateButton(title: NSLocalizedString("금액", comment: "Amount token button"), variable: NSLocalizedString("{금액}", comment: "Amount token variable"))
                templateButton(title: NSLocalizedString("수량", comment: "Quantity token button"), variable: NSLocalizedString("{수량}", comment: "Quantity token variable"))
                templateButton(title: NSLocalizedString("이름", comment: "Name token button"), variable: NSLocalizedString("{이름}", comment: "Name token variable"))
                templateButton(title: NSLocalizedString("날짜", comment: "Date token button"), variable: NSLocalizedString("{날짜}", comment: "Date token variable"))
                templateButton(title: NSLocalizedString("시간", comment: "Time token button"), variable: NSLocalizedString("{시간}", comment: "Time token variable"))
                templateButton(title: NSLocalizedString("주소", comment: "Address token button"), variable: NSLocalizedString("{주소}", comment: "Address token variable"))
                templateButton(title: NSLocalizedString("전화", comment: "Phone token button"), variable: NSLocalizedString("{전화}", comment: "Phone token variable"))

                // 아래 둘은 "채우는 칸"이 아니라 동작 토큰이라 구분선을 둔다.
                // 여기에 없으면 사용자가 존재 자체를 모른다.
                Divider().frame(height: 16)
                templateButton(title: NSLocalizedString("복사한 것", comment: "Clipboard token button"),
                               variable: NSLocalizedString("{클립보드}", comment: "Clipboard token variable"))
                templateButton(title: NSLocalizedString("커서", comment: "Cursor token button"),
                               variable: NSLocalizedString("{커서}", comment: "Cursor token variable"))
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }

    private func templateButton(title: String, variable: String) -> some View {
        Button {
            viewModel.value += variable
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            Text(title)
                .font(.body.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .foregroundColor(Color.accentForeground)
                .cornerRadius(theme.radiusSm)
        }
        .accessibilityLabel(title)
        .accessibilityHint(NSLocalizedString("탭하면 커서 자리에 빈칸이 들어갑니다", comment: "Template variable button hint"))
    }

    private func quickInsertToken(_ token: String, isNumeric: Bool) -> some View {
        QuickInsertTokenButton(token: token, isNumeric: isNumeric) {
            viewModel.value += token
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }
    }
}

struct MemoAdd_Previews: PreviewProvider {
    static var previews: some View {
        MemoAdd()
    }
}
