//
//  MemoStore.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/16.
//

import Foundation

enum MemoType {
    case tokenMemo
    //case clipboardMemo
}

class MemoStore: ObservableObject {
    static let shared = MemoStore()
    
    @Published var memos: [Memo] = []
    
    private static func fileURL(type: MemoType) throws -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            return URL(string: "")
        }
        switch type {
        case .tokenMemo:
            return containerURL.appendingPathComponent("memos.data")
//        case .clipboardMemo:
//            return containerURL.appendingPathComponent("memos.clipboard.data")
        }
    }
    
    func save(memos: [Memo], type: MemoType) throws {
        var data: Data
        switch type {
        case .tokenMemo:
            data = try JSONEncoder().encode(memos)
//        case .clipboardMemo:
//            data = try JSONEncoder().encode(removeDuplicate(memos))
        }
        
        guard let outfile = try Self.fileURL(type: type) else { return }
        try data.write(to: outfile)
    }
    
    func load(type: MemoType) throws -> [Memo] {
        guard let fileURL = try Self.fileURL(type: type) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        var memos: [Memo] = []
        //print(String(data: data, encoding: .utf8))
        
        if let newMemos = try? JSONDecoder().decode([Memo].self, from: data) {
            memos = newMemos
        } else {
            if let oldMemos = try? JSONDecoder().decode([OldMemo].self, from: data) {
                oldMemos.forEach { oldMemo in
                    memos.append(Memo(from: oldMemo))
                }
                
                //memos = oldMemos
            }
        }
        
        return memos
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
