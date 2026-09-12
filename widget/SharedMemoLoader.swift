//
//  SharedMemoLoader.swift
//  widget
//
//  Loads favorite memos from the shared App Group container.
//

import Foundation

// MARK: - Widget용 경량 Memo 모델

/// 위젯에서 사용하는 경량 메모 구조체
/// 메인 앱의 Memo와 동일한 CodingKeys를 사용하여 디코딩 호환
struct WidgetMemo: Identifiable, Codable {
    var id: UUID
    var title: String
    var value: String
    var isFavorite: Bool
    var lastEdited: Date
    var category: String
    var isSecure: Bool

    // 위젯에서 불필요한 필드는 기본값으로 디코딩
    var isChecked: Bool = false
    var clipCount: Int = 0
    var isTemplate: Bool = false
    var templateVariables: [String] = []
    var placeholderValues: [String: [String]] = [:]
    var isStack: Bool = false
    var stackValues: [String] = []
    var currentComboIndex: Int = 0
    var imageFileName: String?
    var imageFileNames: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, title, value, isFavorite, lastEdited, category, isSecure
        case isChecked, clipCount, isTemplate, templateVariables, placeholderValues
        // ⚠️ **JSON 의 글자는 옛 이름 그대로다.** 앱이 스택으로 이름을 바꾼 뒤에도
        //    파일에는 `isCombo`·`comboValues` 로 적힌다(되돌아간 앱과 이 위젯을 위해).
        //    여기서 글자까지 바꾸면 위젯이 스택을 통째로 못 읽는다.
        case isStack = "isCombo"
        case stackValues = "comboValues"
        case currentComboIndex
        case imageFileName, imageFileNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        value = try container.decode(String.self, forKey: .value)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        lastEdited = try container.decodeIfPresent(Date.self, forKey: .lastEdited) ?? Date()
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "기본"
        isSecure = try container.decodeIfPresent(Bool.self, forKey: .isSecure) ?? false
        isChecked = try container.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        clipCount = try container.decodeIfPresent(Int.self, forKey: .clipCount) ?? 0
        isTemplate = try container.decodeIfPresent(Bool.self, forKey: .isTemplate) ?? false
        templateVariables = try container.decodeIfPresent([String].self, forKey: .templateVariables) ?? []
        placeholderValues = try container.decodeIfPresent([String: [String]].self, forKey: .placeholderValues) ?? [:]
        isStack = try container.decodeIfPresent(Bool.self, forKey: .isStack) ?? false
        stackValues = try container.decodeIfPresent([String].self, forKey: .stackValues) ?? []
        currentComboIndex = try container.decodeIfPresent(Int.self, forKey: .currentComboIndex) ?? 0
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        imageFileNames = try container.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
    }
}

// MARK: - Shared Memo Loader

struct SharedMemoLoader {

    /// App Group 컨테이너에서 전체 메모를 로드
    static func loadAllMemos() -> [WidgetMemo] {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            print("❌ [Widget] App Group 컨테이너를 찾을 수 없음")
            return []
        }

        let fileURL = containerURL.appendingPathComponent("memos.data")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ [Widget] memos.data 파일 없음")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let memos = try JSONDecoder().decode([WidgetMemo].self, from: data)
            print("✅ [Widget] 메모 \(memos.count)개 로드")
            return memos
        } catch {
            print("❌ [Widget] 메모 디코딩 실패: \(error)")
            return []
        }
    }

    /// 즐겨찾기 메모만 로드 (보안 메모 제외)
    static func loadFavoriteMemos() -> [WidgetMemo] {
        return loadAllMemos().filter { $0.isFavorite && !$0.isSecure }
    }

    /// 특정 ID의 메모 로드
    static func loadMemo(id: UUID) -> WidgetMemo? {
        return loadAllMemos().first { $0.id == id }
    }
}
