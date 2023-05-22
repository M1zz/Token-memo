//
//  MemoStore.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/16.
//

import Foundation

class MemoStore: ObservableObject {
    static let shared = MemoStore()
    
    @Published var memos: [Memo] = []
    
    private static func fileURL() throws -> URL? {
//        try FileManager.default.url(for: .documentDirectory,
//                                    in: .userDomainMask,
//                                    appropriateFor: nil,
//                                    create: false)
//        .appendingPathComponent("memos.data")
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Ysoup.TokenMemo") else {
            print("Unable to access shared container.")
            return URL(string: "")
        }
        return containerURL.appendingPathComponent("memos.data")
        
    }
    
    func save(memos: [Memo]) throws {
        let data = try JSONEncoder().encode(memos)
        guard let outfile = try Self.fileURL() else {
            return
        }
        try data.write(to: outfile)
    }
    
    func load() throws -> [Memo] {
        guard let fileURL = try Self.fileURL() else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        
        let memos = try JSONDecoder().decode([Memo].self, from: data)
        return memos
    }
}
