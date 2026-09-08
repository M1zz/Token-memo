//
//  ClipKeyboardSpec.swift
//  ClipKeyboard
//
//  LeeoKit 계약(LeeoAppSpec) 준수 - 이 앱의 공통 기능 설정값 단일 소스.
//  피드백 시스템 구현은 전부 LeeoKit에 있고, 앱은 이 설정만 제공한다.
//
//  ⚠️ recordType/구독 ID는 CloudKit Dashboard·기존 사용자 기기와의 계약이다 - 변경 금지.
//  컨테이너는 공용 피드백 허브(FeedbackHub)로 전환됨 - appIdentifier로 앱을 구분한다.
//  (전환 전 자기 컨테이너 iCloud.com.Ysoup.TokenMemo에 쌓인 기존 피드백은 허브 인박스에 나타나지 않는다.)
//

import Foundation
import LeeoKit

enum ClipKeyboardSpec: LeeoAppSpec {
    static let appName = "ClipKeyboard"
    static let developerEmail = Constants.developerEmail

    /// ClipKeyboard.entitlements에 iCloud.com.Ysoup.FeedbackHub 컨테이너가 있어야 한다.
    /// 공용 피드백 허브(FeedbackHub)로 수집 - appIdentifier로 앱을 구분한다.
    /// (백업은 CloudKitBackupService가 iCloud.com.Ysoup.TokenMemo에서 계속 담당한다.)
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.Ysoup.TokenMemo"
    )

    /// App Store 숫자 ID - "리뷰 남기기" 딥링크와 앱 소개(LeeoFamilyCatalog)의 자기 식별에 쓴다.
    /// 이 값이 없으면 소개 화면이 자기 자신을 걸러내지 못한다.
    static let appStoreID: String? = Constants.appStoreID

    /// 법적·지원 링크 - LeeoKit 3.0 계약 필수 항목.
    /// ⚠️ 개인정보 처리방침 주소는 **App Store Connect 에 등록한 것과 같아야 한다**
    ///    (`Constants` 가 단일 출처이므로 여기서 다시 적지 않고 그 값을 쓴다).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: Constants.privacyPolicyURL)!,
        supportURL: URL(string: Constants.supportURL)!,
        termsURL: URL(string: Constants.termsOfUseURL)!,
        // 계정을 만들지 않는다 - 데이터는 사용자의 iCloud/기기에만 있다.
        createsAccounts: false,
        marketingURL: URL(string: Constants.supportURL)!
    )

    /// 수익모델 - 무료로 쓰다가 **한 번 사면 평생**(구독 아님).
    ///
    /// 이 한 줄에서 페이월 필요 여부·복원 의무·게이트 정책이 따라 나온다.
    /// `paywall` 을 따로 선언하지 않는 이유가 그것이다(선언하면 이 값과 어긋날 수 있고,
    /// 어긋나면 LeeoKit 프리플라이트가 `paywall.contradiction` 으로 잡는다).
    ///
    /// ⚠️ productID 는 App Store Connect·기존 사용자 영수증과의 계약이다 - 변경 금지.
    /// ⚠️ 반값 상품(`discountedProProductID`)도 **같이** 싣는다. 파는 물건은 둘이지만
    ///    주는 권한은 하나라, 어느 쪽을 샀든 Pro 로 인정돼야 한다(entitlementIDs 기본값이
    ///    productIDs 전체라 따로 적지 않아도 둘 다 권한으로 잡힌다).
    ///    반값 상품이 App Store Connect 에 아직 없으면 그 ID만 로드되지 않고 정가 상품은 그대로 뜬다.
    /// ⚠️ cacheSuiteName 을 앱 그룹으로 둬야 권한 캐시(leeo.paywall.owned/grandfathered)가
    ///    공유 그룹에 저장된다. (키보드 익스텐션이 읽는 Pro 키 `clipkeyboard_is_pro` 는
    ///    이와 별개로 StoreManager 가 store.hasPro 를 계속 미러링한다.)
    static let monetization = LeeoMonetization.freemium(
        LeeoPurchaseConfig(
            productIDs: [StoreManager.proProductID,
                         DiscountOfferManager.discountedProProductID,
                         SlotPack.productID],
            // ⚠️ **Pro 로 인정할 상품을 손으로 못박는다.** 기본값이 "파는 상품 전체"라,
            //    나중에 칸 추가 상품(`SlotPack.productID`)을 productIDs 에 한 줄 넣는 순간
            //    $3 결제가 평생 Pro 를 열어 버린다. 그 사고는 되돌릴 수도 없다
            //    (이미 권한을 받은 사람에게서 도로 뺏을 방법이 없다).
            entitlementIDs: [StoreManager.proProductID, DiscountOfferManager.discountedProProductID],
            gate: LeeoGatePolicy(
                freeLimits: ["shortcut": ProFeatureManager.freeMemoLimit],
                warnWhenRemaining: 3
            ),
            cacheSuiteName: AppGroup.identifier
        )
    )
}
