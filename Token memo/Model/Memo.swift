//
//  Memo.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/15.
//

import Foundation

struct Memo: Identifiable, Codable {
    var id = UUID()
    let title: String
    let value: String
    var isChecked: Bool = false
    
    static var dummyData: [Memo] = [
        Memo(title: "계좌번호", value: "123412341234123412341234123412341234123412341234"),
        Memo(title: "부모님 댁 주소", value: "거기 어딘가"),
        Memo(title: "통관번호", value: "p12341234")
    ]
}
