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
    var insertedKeyword: String = ""
    var insertedValue: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            TextField(Constants.insertKeyword, text: $keyword)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder())
            
            TextEditor(text: $value)
                .frame(height: 130)
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
                    Text(Constants.removeAll)
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
                        var loadedMemos:[Memo] = []
                        loadedMemos = try MemoStore.shared.load(type: .tokenMemo)
                        loadedMemos.append(Memo(title: keyword, value: value, lastEdited: Date()))
                        try MemoStore.shared.save(memos: loadedMemos, type: .tokenMemo)
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                } else {
                    showAlert = true
                }
            } label: {
                Text(Constants.save)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
        .alert(Constants.insertContents, isPresented: $showAlert) {
            
        }
        .alert("Completed!", isPresented: $showSucessAlert) {
            Button("Ok", role: .cancel) {
                dismiss()
            }
        }
        .onAppear {
            if !insertedKeyword.isEmpty {
                keyword = insertedKeyword
            }
            
            if !insertedValue.isEmpty {
                value = insertedValue
            }
        }
    }
}

struct MemoAdd_Previews: PreviewProvider {
    static var previews: some View {
        MemoAdd()
    }
}
