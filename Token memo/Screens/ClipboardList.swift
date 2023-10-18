//
//  ClipboardList.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/03.
//

import SwiftUI

struct ClipboardList: View {
    
    @State private var clipboardMemos:[Memo] = []
    @State private var loadedData:[Memo] = []
    
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var showActive: Bool = false
    
    var body: some View {
        ZStack {
            List {
                if clipboardMemos.isEmpty {
                    EmptyListView
                }
                ForEach($clipboardMemos) { $memo in
                    Button {
                        UIPasteboard.general.string = memo.value
                        clipboardMemos = loadedData
                        memo.isChecked = true
                        showToast(message: memo.value)
//                        do {
//                            var tempMemos = try MemoStore.shared.load(type: .clipboardMemo)
//                            tempMemos.append(Memo(title: UIPasteboard.general.string ?? "error", value: UIPasteboard.general.string ?? "error", lastEdited: memo.lastEdited))
//                            try MemoStore.shared.save(memos: tempMemos, type: .clipboardMemo)
                            
//                        } catch {
//                            fatalError(error.localizedDescription)
//                        }
                        
                    } label: {
                        Label(memo.title,
                              systemImage: memo.isChecked ? "checkmark.square.fill" : "doc.on.doc.fill")
                        .font(.system(size: fontSize))
                    }
                    .buttonStyle(.borderless)
                }
                .onDelete { index in
                    clipboardMemos.remove(atOffsets: index)
                    
//                    do {
//                        try MemoStore.shared.save(memos: clipboardMemos, type: .clipboardMemo)
//                        loadedData = clipboardMemos
//                    } catch {
//                        fatalError(error.localizedDescription)
//                    }
                }
            }
            .navigationTitle("Clipboard List")
            //.onAppear {
                // load
//                do {
//                    loadedData = try MemoStore.shared.load(type: .clipboardMemo)
//                    clipboardMemos = removeDuplicate(loadedData)
//                    print(loadedData)
//                } catch {
//                    fatalError(error.localizedDescription)
//                }
            //}
            
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
    }
    
    /// Empty list view
    private var EmptyListView: some View {
        VStack(spacing: 5) {
            Image(systemName: "eyes").font(.system(size: 45)).padding(10)
            Text(Constants.nothingToPaste)
                .font(.system(size: 22)).bold()
            Text("No clipboard, Copy the items you want to paste and add them to the clipboard.").opacity(0.7)
        }.multilineTextAlignment(.center).padding(30)
    }
    
    private func showToast(message: String) {
        toastMessage = "[\(message)] is copied."
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showToast = false
        }
    }
    
    private func removeDuplicate(_ array: [Memo]) -> [Memo] {
        var removedArray = [Memo]()
        var tempKeyArray = [String]()
        for item in array {
            if !tempKeyArray.contains(item.title) {
                tempKeyArray.append(item.title)
                removedArray.append(item)
            }
        }
        return removedArray
    }
}

struct ClipboardList_Previews: PreviewProvider {
    static var previews: some View {
        ClipboardList()
    }
}
