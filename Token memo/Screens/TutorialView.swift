//
//  TutorialView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/05.
//

import SwiftUI

struct CopyTutorialView: View {
    var body: some View {
        TabView {
            Image("token-1")
                .resizable()
                .scaledToFit()
            Image("token-2")
                .resizable()
                .scaledToFit()
            Image("token-3")
                .resizable()
                .scaledToFit()
            Image("token-4")
                .resizable()
                .scaledToFit()
        }.tabViewStyle(.page(indexDisplayMode: .always))
    }
}

struct KeyboardTutorialView: View {
    var body: some View {
        TabView {
            Image("use-1")
                .resizable()
                .scaledToFit()
                
            Image("use-2")
                .resizable()
                .scaledToFit()
            Image("use-3")
                .resizable()
                .scaledToFit()
            Image("use-4")
                .resizable()
                .scaledToFit()
            Image("use-5")
                .resizable()
                .scaledToFit()
            Image("use-6")
                .resizable()
                .scaledToFit()
        }.tabViewStyle(.page(indexDisplayMode: .always))
    }
}

struct TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        CopyTutorialView()
    }
}
