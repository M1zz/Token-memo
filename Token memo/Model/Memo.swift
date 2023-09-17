//
//  Memo.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/15.
//

import Foundation

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

struct OldMemo: Identifiable, Codable {
    var id = UUID()
    let title: String
    let value: String
    var isChecked: Bool = false
}

struct Memo: Identifiable, Codable {
    var id = UUID()
    var title: String
    var value: String
    var isChecked: Bool = false
    var lastEdited: Date = Date()
    var isFavorite: Bool = false
    var clipCount: Int = 0
    
    init(id: UUID = UUID(), title: String, value: String, isChecked: Bool = false, lastEdited: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.value = value
        self.isChecked = isChecked
        self.lastEdited = lastEdited
        self.isFavorite = isFavorite
    }
    
    init(from oldMemo: OldMemo) {
        self.id = oldMemo.id
        self.title = oldMemo.title
        self.value = oldMemo.value
        self.isChecked = oldMemo.isChecked
        self.lastEdited = Date() // 새로운 버전에서 추가된 속성 초기화
        self.isFavorite = false
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case value
        case isChecked
        case lastEdited = "lastEdited"
        case isFavorite = "isFavorite"
    }
    
    static var dummyData: [Memo] = [
        Memo(title: "계좌번호",
             value: "123412341234123412341234123412341234123412341234",
             lastEdited: dateFormatter.date(from: "2023-08-31 10:00:00")!),
        Memo(title: "부모님 댁 주소",
             value: "거기 어딘가",
             lastEdited: dateFormatter.date(from: "2023-08-31 10:00:00")!),
        Memo(title: "통관번호",
             value: "p12341234",
             lastEdited: dateFormatter.date(from: "2023-08-31 10:00:00")!)
    ]
}
