//
//  MemoPreviewFormatter.swift
//  ClipKeyboard
//
//  Renders a one-line content preview for a Memo, with type-aware
//  formatting (URL domain, address truncation, token masking, etc.).
//

import Foundation

// `{변수}` 를 찾고·떼고·칩으로 그리는 일은 DesignSystem/TemplatePlaceholder.swift 한 곳에 있다.

enum MemoPreviewFormatter {

    static let maxPreviewLength = 40
    static let ellipsis = "…"

    /// Returns a one-line preview string for the memo's value.
    /// - Parameters:
    ///   - memo: The memo to format.
    ///   - resolvedType: The effective type (may come from category, autoDetectedType, or live classification).
    static func preview(for memo: Memo, resolvedType: ClipboardItemType?) -> String {
        if memo.isStack {
            return stackPreview(memo)
        }
        if memo.isTemplate {
            return templatePreview(memo)
        }
        if memo.contentType == .image {
            return imagePreview(count: memo.imageFileNames.count)
        }

        let trimmed = singleLine(memo.value)
        if trimmed.isEmpty {
            if memo.contentType == .mixed {
                return imagePreview(count: memo.imageFileNames.count)
            }
            return ""
        }

        if memo.isSecure, let type = resolvedType, isMaskableType(type) {
            return maskedPreview(value: trimmed, type: type)
        }

        switch resolvedType {
        case .url:
            return urlPreview(trimmed)
        case .email, .phone:
            return truncate(trimmed)
        case .address:
            return truncate(trimmed)
        default:
            return truncate(trimmed)
        }
    }

    // MARK: - Helpers

    /// Accessibility label that describes masked content in full, so VoiceOver
    /// users can hear the last visible digits with context.
    static func accessibilityPreview(for memo: Memo, resolvedType: ClipboardItemType?) -> String {
        // 읽어 주는 자리라 칩을 그릴 수 없다 - 여기서만 중괄호를 뗀다.
        let preview = self.preview(for: memo, resolvedType: resolvedType).strippingTemplateBraces
        guard memo.isSecure, let type = resolvedType, isMaskableType(type) else {
            return preview
        }
        let typeName = type.localizedName
        let format = NSLocalizedString(
            "Masked %@, ending %@",
            comment: "Accessibility: masked sensitive content with type and tail digits"
        )
        let tail = preview.filter { $0.isNumber || $0.isLetter }
        return String(format: format, typeName, tail)
    }


    // MARK: - Type-specific renderers

    private static func templatePreview(_ memo: Memo) -> String {
        // ⚠️ 여기서 중괄호를 떼지 않는다. 예전에는 떼서 돌려줬는데, 그러면 이 문자열을
        //    받아 그리는 쪽이 칩으로 칠할 실마리를 잃어서 **목록만 맹물 글씨**가 됐다.
        //    토큰은 그대로 두고, 그리는 자리에서 `templateAwareAttributed` 가 칩으로 바꾼다.
        //    평문이 필요한 곳(읽어 주기)은 `accessibilityPreview` 가 떼어 준다.
        let first = truncate(singleLine(memo.value), max: 28)
        let placeholders = TemplatePlaceholder.names(in: memo.value)
        guard !placeholders.isEmpty else { return first }
        let format = NSLocalizedString("%d variables", comment: "Template placeholder count suffix")
        let count = String(format: format, placeholders.count)
        return "\(first) · \(count)"
    }

    private static func stackPreview(_ memo: Memo) -> String {
        // 첫 번째 값을 앞세우고 개수는 꼬리로 - 템플릿 미리보기("첫 줄 · N variables")와 동일 스타일.
        guard let first = memo.stackValues.first else { return truncate(singleLine(memo.value)) }
        let format = NSLocalizedString("%d items", comment: "Combo item count preview")
        let count = String(format: format, memo.stackValues.count)
        // 보안 콤보 - 값(암호문 포함)을 노출하지 않고 개수만 보여준다.
        if memo.isSecure { return count }
        return "\(truncate(singleLine(first), max: 28)) · \(count)"
    }

    private static func imagePreview(count: Int) -> String {
        let n = max(count, 1)
        let format = NSLocalizedString("%d image(s)", comment: "Image count preview")
        return String(format: format, n)
    }

    private static func urlPreview(_ value: String) -> String {
        // Try parse with URL; fall back to a naive host extraction.
        if let url = URL(string: value), let host = url.host {
            let path = url.path
            let combined = path.isEmpty || path == "/" ? host : "\(host)\(path)"
            return truncate(combined)
        }
        // Strip scheme manually if URL init failed.
        var stripped = value
        for scheme in ["https://", "http://"] {
            if stripped.hasPrefix(scheme) {
                stripped = String(stripped.dropFirst(scheme.count))
                break
            }
        }
        return truncate(stripped)
    }

    private static func maskedPreview(value: String, type: ClipboardItemType) -> String {
        let digits = value.filter { $0.isNumber || $0.isLetter }
        guard !digits.isEmpty else { return String(repeating: "•", count: 4) }

        let tailLength: Int
        switch type {
        case .creditCard, .bankAccount:
            tailLength = 4
        case .passportNumber, .taxID, .insuranceNumber, .medicalRecord, .employeeID:
            tailLength = 3
        default:
            tailLength = 4
        }

        let tail = String(digits.suffix(tailLength))
        return "•••• \(tail)"
    }

    // MARK: - Utilities

    private static func isMaskableType(_ type: ClipboardItemType) -> Bool {
        switch type {
        case .creditCard, .bankAccount, .passportNumber, .taxID,
             .insuranceNumber, .medicalRecord, .employeeID:
            return true
        default:
            return false
        }
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 길면 자른다. **`{변수}` 한가운데서는 자르지 않는다** - 반쪽만 남으면 칩으로 칠할 수 없어
    /// 여는 중괄호 하나가 글자로 드러난다. 그런 경우 그 토큰 앞에서 끊는다.
    private static func truncate(_ text: String, max: Int = maxPreviewLength) -> String {
        guard text.count > max else { return text }
        var head = String(text[..<text.index(text.startIndex, offsetBy: max)])
        if let open = head.lastIndex(of: "{"), !head[open...].contains("}") {
            head = String(head[..<open])
        }
        return head + ellipsis
    }
}
