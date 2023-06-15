//
//  ColorfulOnboardingView.swift
//  Token memo
//
//  Created by hyunho lee on 2023/06/15.
//

import SwiftUI

import SwiftUI

/// Shows a full color background for each onboarding view
struct ColorfulOnboardingView: View {
    
    @State var pages = [PageDetails]()
    @State private var pageIndex: Int = 0
    private let bottomSectionHeight: CGFloat = 100
    var exitAction: () -> Void
    
    // MARK: - Main rendering function
    var body: some View {
        ZStack {
            ScrollView {
                TabView(selection: $pageIndex.animation(.easeIn)) {
                    ForEach(0..<pages.count, id: \.self, content: { index in
                        CreatePage(details: pages[index])
                    })
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: UIScreen.main.bounds.height)
            }.edgesIgnoringSafeArea(.all).onAppear {
                UIScrollView.appearance().bounces = false
            }
            BottomSectionView
        }
    }
    
    // MARK: - Configuration
    struct PageDetails {
        let imageName: String
        let title: String
        let subtitle: String
        let color: Color
    }
    
    /// Create a page with details
    private func CreatePage(details: PageDetails) -> some View {
        let imageSize = UIScreen.main.bounds.width-80
        return ZStack {
            details.color
            VStack {
                Spacer() /// Image section
                if UIImage(named: details.imageName) != nil {
                    Image(uiImage: UIImage(named: details.imageName)!)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: imageSize, alignment: .center)
                } else {
                    Color.clear.frame(height: imageSize)
                }
                Spacer() /// Text section
                VStack(spacing: 20) {
                    Text(details.title).font(.system(size: 35, weight: .semibold, design: .rounded))
                    Text(details.subtitle).font(.system(size: 18))
                }
                Spacer()
                Color.clear.frame(height: bottomSectionHeight+50)
            }.padding().multilineTextAlignment(.center)
        }.frame(width: UIScreen.main.bounds.width).foregroundColor(.white)
    }
    
    /// Page dots and CTA buttons view
    private var BottomSectionView: some View {
        let pageDotSize: CGFloat = 10
        return VStack {
            Spacer()
            VStack {
                /// Page dots section
                HStack {
                    ForEach(0..<pages.count, id: \.self, content: { id in
                        ZStack {
                            if pageIndex == id {
                                RoundedRectangle(cornerRadius: 20).frame(width: pageDotSize * 3)
                            } else {
                                Circle().frame(width: pageDotSize)
                            }
                        }.frame(height: pageDotSize)
                    })
                }.foregroundColor(.white)
                Spacer()
                /// Next button
                HStack {
                    Spacer()
                    Button(action: {
                        UIImpactFeedbackGenerator().impactOccurred()
                        if pageIndex < pages.count - 1 {
                            withAnimation { pageIndex = pageIndex + 1 }
                        } else {
                            exitAction()
                        }
                    }, label: {
                        if pageIndex == pages.count - 1 {
                            Text("Get Started").foregroundColor(pages[pageIndex].color)
                                .padding().padding([.leading, .trailing]).background(
                                RoundedRectangle(cornerRadius: 40)
                            )
                        } else {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                    }).frame(height: 40).font(.system(size: 20, weight: .semibold))
                    if pageIndex == pages.count - 1 {
                        Spacer()
                    }
                }.padding()
            }.foregroundColor(.white).frame(height: bottomSectionHeight).padding(.bottom)
        }
    }
}

// MARK: - Preview UI
struct ColorfulOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        let pages = [
        ColorfulOnboardingView.PageDetails.init(imageName: "step1", title: "Enable Keyboard", subtitle: "Go to Settings -> General -> Keyboard -> Keyboards then tap 'Add New Keyboard...' and select 'Token Memo'", color: Color(#colorLiteral(red: 0.4534527972, green: 0.5727163462, blue: 1, alpha: 1))),
            ColorfulOnboardingView.PageDetails.init(imageName: "step2", title: "Add your Text", subtitle: "In the Token Memo app, tap the '+' button to add your own text/phrase. To delete any added text, you can swipe left to delete.", color: Color(#colorLiteral(red: 0.9011964598, green: 0.5727163462, blue: 0, alpha: 1))),
            ColorfulOnboardingView.PageDetails.init(imageName: "step3", title: "Use the Keyboard", subtitle: "In the messages app, email or any other app, you can tap the 'globe' icon to switch between keyboards. Enjoy!", color: Color(#colorLiteral(red: 0.4534527972, green: 0.7018411277, blue: 0.06370192308, alpha: 1)))
        ]
        return ColorfulOnboardingView(pages: pages, exitAction: { })
    }
}
