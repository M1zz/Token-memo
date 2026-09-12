//
//  ComboEditSheet.swift
//  ClipKeyboard
//
//  콤보는 stackValues(이어지는 단계)를 가진 일반 Memo다. 콤보 메모를 탭하면
//  단계 값들이 즉시 클립보드에 복사되고, 어떤 값들이 (키보드에서 순서대로) 입력될지
//  보여주는 미리보기 하프모달(ComboPreviewSheet)이 뜬다. 편집은 롱프레스 → 수정.
//

import SwiftUI
import LeeoKit

// MARK: - Combo Preview Sheet (탭 시 즉시 복사 + 순차 입력될 값 미리보기)

struct StackPreviewSheet: View {
    let stackId: UUID
    let allMemos: [Memo]
    let onDismiss: () -> Void
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var loadedMemo: Memo?
    /// 방금 복사한 단계 인덱스 - 체크 표시 피드백용(1.5초 후 원복).
    @State private var copiedStepIndex: Int?

    var body: some View {
        Group {
            if let memo = loadedMemo {
                content(for: memo)
            } else {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5)
                    Text(NSLocalizedString("불러오는 중...", comment: "Loading"))
                        .font(.body)
                        .foregroundColor(theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.bg)
                .onAppear { loadMemo() }
            }
        }
        .onDisappear { onDismiss() }
    }

    /// 단계 값(자동 변수 치환). 커스텀 토큰({이름} 등)은 키보드 동작과 동일하게 그대로 둔다.
    /// 보안 콤보는 이 시트가 인증 후에 뜨므로 여기서 복호화해 보여준다.
    private func resolvedSteps(for memo: Memo) -> [String] {
        SecureMemoCrypto.decryptSteps(memo.stackValues).map { TemplateVariableProcessor.process($0) }
    }

    @ViewBuilder
    private func content(for memo: Memo) -> some View {
        let steps = resolvedSteps(for: memo)
        VStack(alignment: .leading, spacing: 0) {
            // 헤더 - 콤보 제목
            HStack(spacing: 8) {
                Image(systemName: AppSymbol.squareStack3dUpFill)
                    .foregroundColor(theme.accent)
                    .accessibilityHidden(true)
                Text(memo.title.templateAwareAttributed(theme: theme, font: .headline))
                    .font(.headline)
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 4)

            // 값 선택 안내 - 값을 눌러 하나를 복사한다.
            HStack(spacing: 6) {
                Image(systemName: AppSymbol.docOnDoc)
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("값을 눌러 복사하세요", comment: "Combo preview: tap a value to copy"))
                    .font(.footnote)
                    .foregroundColor(theme.textMuted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)

            // 순차 입력될 단계 값 목록
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                        stepRow(index: idx, step: step)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            // 키보드 안내
            HStack(spacing: 6) {
                Image(systemName: AppSymbol.keyboard)
                    .font(.caption)
                    .foregroundColor(theme.textFaint)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("키보드에서 이 순서로 입력돼요", comment: "Combo preview: typed in this order on the keyboard"))
                    .font(.caption)
                    .foregroundColor(theme.textFaint)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bg)
    }

    /// 단계 하나 - 번호 뱃지 + 값 + 복사 버튼.
    /// 앱에서는 순차 입력 대신 값 하나씩 복사해 쓰므로 각 단계에 복사 버튼을 단다.
    private func stepRow(index idx: Int, step: String) -> some View {
        // 행 전체가 탭 대상 - 값 하나를 골라 복사한다.
        Button {
            copyStep(step, at: idx)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text("\(idx + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(theme.accentFg)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(theme.accent))
                Text(step.isEmpty ? "-" : step)
                    .font(.body)
                    .foregroundColor(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: copiedStepIndex == idx ? AppSymbol.checkmarkCircleFill : AppSymbol.docOnDoc)
                    .font(.body)
                    .foregroundColor(copiedStepIndex == idx ? Color.checkGreen : theme.textMuted)
                    .frame(width: 30, height: 30)
                    .background(theme.surfaceAlt)
                    .clipShape(Circle())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(step.isEmpty)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            format: NSLocalizedString("%d단계: %@", comment: "Combo preview step: order and value"),
            idx + 1, step.isEmpty ? "-" : step))
        .accessibilityHint(NSLocalizedString("탭하면 이 값을 복사합니다", comment: "Combo step copy hint"))
    }

    private func copyStep(_ step: String, at idx: Int) {
        UIPasteboard.general.string = step
        HapticManager.shared.selection()
        withAnimation { copiedStepIndex = idx }

        // 콤보 값을 골라 쓴 것도 **쓴 것**이다. 여기서 안 세면 콤보만 사용 기록에서 빠져
        // 금고에도 안 쌓이고 영수증에도 안 오른다(지금까지 그랬다).
        // 어느 값을 골랐는지 함께 알린다 - 붙여넣기 연습이 "복사한 그것"과 맞는지 봐야 한다.
        try? MemoStore.shared.incrementClipCount(for: stackId, copiedText: step)

        // 복사했으면 시트는 물러난다. 체크 표시를 볼 만큼만 두고 닫는다
        // 바로 닫으면 어느 값을 복사했는지 확인할 새가 없다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            dismiss()
        }
    }

    private func loadMemo() {
        if let memo = allMemos.first(where: { $0.id == stackId }) {
            loadedMemo = memo
            return
        }
        let memos = (try? MemoStore.shared.load(type: .memo)) ?? []
        loadedMemo = memos.first(where: { $0.id == stackId })
    }
}

// MARK: - Combo Import Sheet (기존 단축어를 골라 값으로 가져오기)

/// 이미 만든 단축어들을 골라 그 값을 새 콤보의 값(단계)으로 복사한다.
/// 값 복사 방식 - 원본과 링크되지 않는다(원본을 고쳐도 콤보는 그대로).
struct StackImportSheet: View {
    /// 선택한 단축어들의 값(순서대로).
    let onPick: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var memos: [Memo] = []
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if memos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(theme.textFaint)
                        Text(NSLocalizedString("가져올 단축어가 없어요", comment: "No snippets to import"))
                            .font(.body)
                            .foregroundColor(theme.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(memos) { memo in
                            Button {
                                if selected.contains(memo.id) { selected.remove(memo.id) }
                                else { selected.insert(memo.id) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selected.contains(memo.id) ? Color.checkGreen : theme.textFaint)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(memo.title.templateAwareAttributed(theme: theme, font: .body))
                                            .font(.body)
                                            .foregroundColor(theme.text)
                                            .lineLimit(1)
                                        Text(memo.value.templateAwareAttributed(theme: theme, font: .caption))
                                            .font(.caption)
                                            .foregroundColor(theme.textMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("기존 단축어 가져오기", comment: "Import from existing snippets title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("취소", comment: "Cancel button")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("추가", comment: "Add")) {
                        // 선택 순서가 아니라 목록 순서로 값 복사.
                        let values = memos.filter { selected.contains($0.id) }.map { $0.value }
                        onPick(values)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear {
                let all = (try? MemoStore.shared.load(type: .memo)) ?? []
                // 텍스트 단축어만 - 보안(암호문)·이미지·콤보는 값 복사가 애매해 제외.
                memos = all.filter {
                    !$0.isSecure && $0.imageFileNames.isEmpty && !$0.isStack
                        && $0.contentType == .text && !$0.value.isEmpty
                }
            }
        }
    }
}
