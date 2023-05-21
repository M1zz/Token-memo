//
//  MemoAdd.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/15.
//

import SwiftUI

struct MemoAdd: View {
    
    @State private var keyword: String = ""
    @State private var value: String = ""
    @State private var showAlert: Bool = false
    @State private var showSucessAlert: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            TextField("키워드를 입력해주세요", text: $keyword)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder())
                
            TextEditor(text: $value)
                .frame(height: 300)
                .padding(10)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke()
                }
            HStack {
                Spacer()
                Button {
                    keyword = ""
                    value = ""
                } label: {
                    Text("Remove all")
                        .foregroundColor(.red)
                        .bold()
                }

            }
            Spacer()
            Button {
                
                if !keyword.isEmpty,
                   !value.isEmpty {
                    showSucessAlert = true
                    // success
                    // save
                    do {
                        var tempMemos:[Memo] = []
                        tempMemos = try MemoStore.shared.load()
                        tempMemos.append(Memo(title: keyword, value: value))
                        try MemoStore.shared.save(memos: tempMemos)
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                } else {
                    showAlert = true
                }
            } label: {
                Text("Save")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
        .alert("내용을 채워주세요", isPresented: $showAlert) {
            
        }
        .alert("작성을 완료했습니다", isPresented: $showSucessAlert) {
            Button("확인", role: .cancel) {
                dismiss()
            }
        }
    }
}

struct MemoAdd_Previews: PreviewProvider {
    static var previews: some View {
        MemoAdd()
    }
}
