//
//  TokenMemoListas.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI

struct TokenMemoListAs: View {
    @State var title: String = "asdf"
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    Text("1")
                } label: {
                    HStack {
                        Button {
                            title = "계좌번호"
                        } label: {
                            Image(systemName: "heart")
                        }
                        .buttonStyle(.borderless)
                        .background(.red)
                        Text(title)
                    }
                }

                
                //.buttonStyle(PlainButtonStyle())

                Text("부모님댁 주소")
                Text("통관번호")
            }
            .toolbar {ToolbarItemGroup(placement: .bottomBar ) {
                Spacer()
            }
                ToolbarItemGroup(placement: .bottomBar ) {
                    Button("1") {
                        
                    }
                }
            }
        }
        
        
    }
}

struct TokenMemoListAs_Previews: PreviewProvider {
    static var previews: some View {
        TokenMemoListAs()
    }
}
