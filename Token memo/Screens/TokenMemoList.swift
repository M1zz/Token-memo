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
    
    @State private var searchQueryString = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    if tokenMemos.isEmpty {
                        NavigationLink {
                            MemoAdd()
                        } label: {
                            EmptyListView
                        }
                    }
                    ForEach($tokenMemos) { $memo in
                        HStack {
                            Button {
                                UIPasteboard.general.string = memo.value // copy
                                tokenMemos = loadedData // init clicked data
                                memo.isChecked = true // click data
                                showToast(message: memo.value) // show toast
                                
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
                            .buttonStyle(PlainButtonStyle())
                            
                            
                            Spacer()
                            Button {
                                withAnimation(.easeInOut) {
                                    memo.isFavorite.toggle()
                                    tokenMemos = sortMemos(tokenMemos)
                                    
                                    // update
                                    do {
                                        try MemoStore.shared.save(memos: tokenMemos, type: .tokenMemo)
                                        loadedData = tokenMemos
                                    } catch {
                                        fatalError(error.localizedDescription)
                                    }
                                }
                                
                                
                            } label: {
                                Image(systemName: memo.isFavorite ? "heart.fill" : "heart")
                                    .symbolRenderingMode(.multicolor)
                            }
                            .frame(width: 40, height: 40)
                            .buttonStyle(BorderedButtonStyle())
                        }
                        .transition(.scale)
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
                        //                        NavigationLink {
                        //                            ClipboardList()
                        //                        } label: {
                        //                            Image(systemName: "rectangle.and.paperclip")
                        //                        }
                        
                        
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
            
            .onChange(of: searchQueryString, perform: { value in
                if searchQueryString.isEmpty {
                    tokenMemos = loadedData
                } else {
                    tokenMemos = tokenMemos.filter { $0.title.localizedStandardContains(searchQueryString)
                    }
                }
            })
            .navigationTitle("Clip Keyboard")
            .searchable(
                text: $searchQueryString,
                placement: .navigationBarDrawer,
                prompt: "검색"
            )
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
                    tokenMemos = sortMemos(try MemoStore.shared.load(type: .tokenMemo))
                    //tokenMemos.sort {$0.lastEdited > $1.lastEdited}
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
    
    private func sortMemos(_ memos: [Memo]) -> [Memo] {
        return memos.sorted { (memo1, memo2) -> Bool in
            if memo1.isFavorite != memo2.isFavorite {
                return memo1.isFavorite && !memo2.isFavorite
            } else {
                return memo1.lastEdited > memo2.lastEdited
            }
        }
    }
    
    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 5) {
            Image(systemName: "eyes").font(.system(size: 45)).padding(10)
            Text(Constants.nothingToPaste)
                .font(.system(size: 22)).bold()
            Text(Constants.emptyDescription).opacity(0.7)
        }.multilineTextAlignment(.center).padding(30)
    }
    
    private func showToast(message: String) {
        toastMessage = "[\(message)] 이 복사되었습니다."
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

extension Date {
    func toString(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
