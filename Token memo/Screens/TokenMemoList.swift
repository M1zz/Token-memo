//
//  TokenMemoList.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI

struct TokenMemoList: View {
    @State private var tokenMemos:[Memo] = []//Memo.dummyData
    @State var originalData:[Memo] = []
    
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var showActive: Bool = false
    
    @State private var showHalfSheet: Bool = false
    @State private var isFirstVisit: Bool = true
    
    @State private var keyword: String = ""
    @State private var value: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach($tokenMemos) { $memo in
                        NavigationLink {
                            MemoDetail(memo: $memo)
                        } label: {
                            Button {
                                UIPasteboard.general.string = memo.value
                                tokenMemos = originalData
                                memo.isChecked = true
                                showToast(message: memo.value)
                            } label: {
                                Label(memo.title,
                                      systemImage: memo.isChecked ? "checkmark.square.fill" : "doc.on.doc.fill")
                                .font(.largeTitle)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .onDelete { index in
                        tokenMemos.remove(atOffsets: index)
                        
                        do {
                            try MemoStore.shared.save(memos: tokenMemos)
                            originalData = tokenMemos
                        } catch {
                            fatalError(error.localizedDescription)
                        }
                    }
                }
                
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        NavigationLink {
                            MemoAdd()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    
                }
                
                VStack {
                    Spacer()
                    if showToast {
                        Group {
                            Text(toastMessage)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(.gray)
                                .cornerRadius(8)
                                .padding()
                                .foregroundColor(.white)
                        }
                        .onTapGesture {
                            showToast = false
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: showToast)
                .transition(.opacity)
            }
            .navigationTitle("Memo list")
            .sheet(isPresented: $showHalfSheet, content: {
                VStack {
                    TextField("Enter keyword", text: $keyword)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder())
                    TextEditor(text: $value)
                        .padding(10)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke()
                        }
                    
                    Button {
                        do {
                            var tempMemos = try MemoStore.shared.load()
                            tempMemos.append(Memo(title: keyword, value: value))
                            try MemoStore.shared.save(memos: tempMemos)
                            tokenMemos = tempMemos
                            originalData = tokenMemos
                        } catch {
                            fatalError(error.localizedDescription)
                        }

                        showHalfSheet.toggle()
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                }
                .padding()
                .presentationDetents([.medium])
            })
            .onAppear {
                // load
                do {
                    tokenMemos = try MemoStore.shared.load()
                    originalData = tokenMemos
                } catch {
                    fatalError(error.localizedDescription)
                }
                
                if !(UIPasteboard.general.string?.isEmpty ?? true),
                   isFirstVisit {
                    showHalfSheet = true
                    isFirstVisit = false
                    value = UIPasteboard.general.string ?? "error"
                }
            }
        }
        
       
    }
    
    private func showToast(message: String) {
        toastMessage = "[\(message)] is coppied."
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showToast = false
        }
    }
}

struct TokenMemoList_Previews: PreviewProvider {
    static var previews: some View {
        TokenMemoList()
    }
}
//square.and.pencil
