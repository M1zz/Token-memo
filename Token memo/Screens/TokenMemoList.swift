//
//  TokenMemoList.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI

var isFirstVisit: Bool = true
var fontSize: CGFloat = 20

struct TokenMemoList: View {
    @State private var tokenMemos:[Memo] = []
    @State private var loadedData:[Memo] = []
    
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var showActive: Bool = false
    
    @State private var showShortcutSheet: Bool = false
    @State private var isFirstVisit: Bool = true
    
    @State private var keyword: String = ""
    @State private var value: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                
                List {
                    if tokenMemos.isEmpty {
                        NavigationLink {
                            MemoAdd()
                        } label: {
                            Text("No token, please add a new token.")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                    ForEach($tokenMemos) { $memo in
                        NavigationLink {
                            MemoDetail(memo: $memo)
                        } label: {
                            Button {
                                
                                UIPasteboard.general.string = memo.value // copy
                                tokenMemos = loadedData // init clicked data
                                
                                
                                memo.isChecked = true // click data
                                showToast(message: memo.value) // show toast
                                
                                
                                do {
                                    var loadedClipboardMemos = try MemoStore.shared.load(type: .clipboardMemo)
                                    loadedClipboardMemos.append(Memo(title: UIPasteboard.general.string ?? "error", value: UIPasteboard.general.string ?? "error"))
                                    
                                    var doNotHaveDuplication: Bool = false
                                    for item in loadedClipboardMemos {
                                        if UIPasteboard.general.string == item.value {
                                            doNotHaveDuplication = true
                                        }
                                    }
                                    
                                    if doNotHaveDuplication {
                                        try MemoStore.shared.save(memos: loadedClipboardMemos, type: .clipboardMemo)
                                    }
                                    
                                } catch {
                                    fatalError(error.localizedDescription)
                                }
                                
                            } label: {
                                Label(memo.title,
                                      systemImage: memo.isChecked ? "checkmark.square.fill" : "doc.on.doc.fill")
                                .font(.system(size: fontSize))
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    NavigationLink {
                                        MemoAdd(insertedKeyword: memo.title ,
                                                insertedValue: memo.value)
                                    } label: {
                                        Label("update", systemImage: "pencil")
                                    }
                                    .tint(.green)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .onDelete { index in
                        tokenMemos.remove(atOffsets: index)
                        
                        // update
                        do {
                            try MemoStore.shared.save(memos: tokenMemos, type: .tokenMemo)
                            loadedData = tokenMemos
                        } catch {
                            fatalError(error.localizedDescription)
                        }
                    }
                    
                    ZStack {
                        NavigationLink {
                            MemoAdd()
                        } label: {
                            Text("")
                        }
                        .opacity(0.0)
                        .buttonStyle(PlainButtonStyle())
                        
                        HStack {
                            Spacer()
                            Image(systemName: "plus.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.all, 8)
                    }
                }
               
                .listRowInsets(EdgeInsets(top: 15, leading: 0, bottom: 0, trailing: 0))
                
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        NavigationLink {
                            ClipboardList()
                        } label: {
                            Image(systemName: "rectangle.and.paperclip")
                        }
                        
                        
                        NavigationLink {
                            SettingView()
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        
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
            .navigationTitle("Token Store")
            .overlay(content: {
                VStack {
                    Spacer()
                    if !value.isEmpty {
                        ShortcutMemoView(keyword: $keyword,
                                         value: $value,
                                         tokenMemos: $tokenMemos,
                                         originalData: $loadedData,
                                         showShortcutSheet: $showShortcutSheet)
                        .offset(y: 0)
                        .shadow(radius: 15)
                        .opacity(showShortcutSheet ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).delay(0.3), value: showShortcutSheet)
                    }
                }
            })
            .onAppear {
                // load
                do {
                    tokenMemos = try MemoStore.shared.load(type: .tokenMemo)
                    loadedData = tokenMemos
                } catch {
                    fatalError(error.localizedDescription)
                }
                
                if !(UIPasteboard.general.string?.isEmpty ?? true),
                   isFirstVisit {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showShortcutSheet = true
                    }
                    
                    isFirstVisit = false
                    value = UIPasteboard.general.string ?? "error"
                }
                
                fontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat ?? 20.0
            }
        }
        
       
    }
    
    private func showToast(message: String) {
        toastMessage = "[\(message)] is copied."
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
