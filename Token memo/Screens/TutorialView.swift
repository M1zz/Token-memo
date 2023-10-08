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
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Button("Open Web Page") {
                
            }
            .onAppear(perform: {
                dismiss()

                if let url = URL(string: "https://leeo75.notion.site/ClipKeyboard-FAQ-62923111ec6847d493c7a36a083b9c05?pvs=4") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            })
        }
    }
//    var body: some View {
//        TabView {
//            Image("use-1")
//                .resizable()
//                .scaledToFit()
//                
//            Image("use-2")
//                .resizable()
//                .scaledToFit()
//            Image("use-3")
//                .resizable()
//                .scaledToFit()
//            Image("use-4")
//                .resizable()
//                .scaledToFit()
//            Image("use-5")
//                .resizable()
//                .scaledToFit()
//            Image("use-6")
//                .resizable()
//                .scaledToFit()
//        }.tabViewStyle(.page(indexDisplayMode: .always))
//    }
}

struct TutorialView_Previews: PreviewProvider {
    static var previews: some View {
        CopyTutorialView()
    }
}
