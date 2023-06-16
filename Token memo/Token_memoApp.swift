//
//  Token_memoApp.swift
//  Token memo
//
//  Created by hyunho lee on 2023/05/14.
//

import SwiftUI

@main
struct Token_memoApp: App {
    @ObservedObject var manager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            // basic UI
            // memo RC .. DU
            // persistance
            // toast
            // clipboard
            // half modal
            if manager.didShowOnboarding == false {
                ColorfulOnboardingView(pages: OnboardingPages) {
                    manager.didShowOnboarding = true
                }
            } else {
                TokenMemoList()
//                    .onOpenURL { url in
//                        if (url.scheme! == "tokenMemo" && url.host! == "test") {
//                            if let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true) {
//                                for query in components.queryItems! {
//                                    print(query.name)
//                                    print(query.value!)
//                                }
//                            }
//                        }
//                    }
            }
            
        }
    }
    
    /// Onboarding pages
    private var OnboardingPages: [ColorfulOnboardingView.PageDetails] {
        [
            .init(imageName: "step1", title: "Enable Keyboard", subtitle: "Go to Settings -> General -> Keyboard -> Keyboards then tap 'Add New Keyboard...' and select 'Token Memo'", color: Color(#colorLiteral(red: 0.4534527972, green: 0.5727163462, blue: 1, alpha: 1))),
            .init(imageName: "step2", title: "Allow full access", subtitle: "Allow Full Access to fully use the copy function!", color: Color(#colorLiteral(red: 0.4534527972, green: 0.7018411277, blue: 0.06370192308, alpha: 1))),
            .init(imageName: "step3", title: "Add your Text", subtitle: "In the Token Memo app, tap the '+' button to add your own text/phrase. To delete any added text, you can swipe left to delete.", color: Color(#colorLiteral(red: 0.9011964598, green: 0.5727163462, blue: 0, alpha: 1))),
            .init(imageName: "step4", title: "Use the Keyboard", subtitle: "In the messages app, email or any other app, you can tap the 'globe' icon to switch between keyboards. Enjoy!", color: Color(#colorLiteral(red: 0.9098039269, green: 0.4784313738, blue: 0.6431372762, alpha: 1)))
        ]
    }
}
