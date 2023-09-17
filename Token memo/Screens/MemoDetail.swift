//
//  MemoDetail.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/18.
//

import SwiftUI

struct MemoDetail: View {
    
    @Binding var memo: Memo
    
    var body: some View {
        VStack {
            HStack {
                Text("Title : ")
                Text(memo.title)
                Spacer()
            }
            Divider()
            HStack {
                Text("Value : ")
                Text(memo.value)
                Spacer()
            }
            Spacer()
        }
        .padding()
    }
}

struct MemoDetail_Previews: PreviewProvider {
    static var previews: some View {
        MemoDetail(memo: .constant(Memo(title: "계좌번호",
                                        value: "1111",
                                        lastEdited: dateFormatter.date(from: "2023-08-31 10:00:00")!)))
    }
}
