//
//  ComboTutorialStepTests.swift
//  ClipKeyboardTests
//
//  콤보 장의 **다섯 걸음**을 붙잡아 둔다.
//
//  이 장이 다른 둘(단축어·템플릿)과 다른 이유는 하나다. 콤보는 한 번 눌러서는
//  아무것도 안 보인다 - 값 하나가 들어갈 뿐이라 보통 단축어와 똑같이 생겼다.
//  서로 다른 값이 **두 번** 들어가는 걸 자기 눈으로 봐야 그때 알아진다.
//
//  그래서 여기서 지키는 계약은 셋이다.
//   ① 순서가 무너지지 않는다(넣기 → 보내기 → **바꾸기** → 넣기 → 보내기 → 확인).
//   ② 물결은 **한 번에 한 곳**에만 있다. 키를 가리키는 걸음과 보내기를 가리키는
//      걸음이 겹치면 지금 누를 곳이 둘이 되어 안내가 아니라 수수께끼가 된다.
//   ③ 마지막에 짚는 걸음이 **있다.** 두 번 보내 놓고 그냥 지나가면 두 번 눌렀다는
//      것만 남는다.
//

import Testing
import Foundation
@testable import ClipKeyboard

@Suite("ComboTutorialStep: 콤보는 한 번 눌러서는 안 배워진다")
struct StackTutorialStepTests {

    @Test("순서가 못박혀 있다 - 가운데의 '값 바꾸기'가 이 장의 전부다")
    func orderIsFixed() {
        #expect(StackTutorialStep.allCases == [
            .insertFirst, .sendFirst, .advance, .insertSecond, .sendSecond, .confirm
        ])
    }

    @Test("걸음을 따라가면 확인에서 멈춘다 - 그 뒤는 없다")
    func walkEndsAtConfirm() {
        var step: StackTutorialStep? = .insertFirst
        var walked: [StackTutorialStep] = []
        while let current = step {
            walked.append(current)
            step = current.next
            #expect(walked.count <= StackTutorialStep.allCases.count,
                    "걸음이 스스로를 되돌아 무한히 돈다")
        }
        #expect(walked == StackTutorialStep.allCases)
        #expect(StackTutorialStep.confirm.next == nil,
                "확인이 마지막이라야 콤보 장이 끝나고 + 걸음으로 넘어간다")
    }

    @Test("넣는 걸음은 키의 **왼쪽**, 바꾸는 걸음은 **오른쪽**을 가리킨다")
    func pointsAtTheRightHalf() {
        #expect(StackTutorialStep.insertFirst.stackPart == .value)
        #expect(StackTutorialStep.insertSecond.stackPart == .value)
        #expect(StackTutorialStep.advance.stackPart == .next)
    }

    @Test("보내는 걸음과 확인 걸음은 키를 가리키지 않는다")
    func sendStepsLeaveTheKeyAlone() {
        #expect(StackTutorialStep.sendFirst.stackPart == nil)
        #expect(StackTutorialStep.sendSecond.stackPart == nil)
        #expect(StackTutorialStep.confirm.stackPart == nil)
    }

    /// ⚠️ 이 규칙이 깨지면 화면에서 **두 곳이 동시에 물결친다.**
    ///    키캡과 보내기 동그라미가 같이 일렁이면 지금 누를 곳을 알 수 없다.
    @Test("키를 가리키는 걸음과 보내기를 가리키는 걸음은 절대 겹치지 않는다")
    func neverPointsAtTwoPlacesAtOnce() {
        for step in StackTutorialStep.allCases {
            #expect(!(step.stackPart != nil && step.highlightsSend),
                    "\(step.rawValue) 이 키와 보내기를 동시에 가리킨다")
        }
    }

    @Test("보내라고 말하는 걸음은 딱 둘 - 값도 두 번 들어가야 다른 것이 보인다")
    func exactlyTwoSendSteps() {
        let sends = StackTutorialStep.allCases.filter(\.highlightsSend)
        #expect(sends == [.sendFirst, .sendSecond])
    }

    @Test("걸음마다 할 말이 다르다 - 같은 문구를 다섯 번 보면 안내가 아니라 소음이다")
    func everyStepSaysSomethingDifferent() {
        let lines = StackTutorialStep.allCases.map(\.coachLine)
        #expect(Set(lines).count == lines.count)
        #expect(lines.allSatisfy { !$0.isEmpty })
    }

    /// ⚠️ 저장해 둔 값으로 되살아나야 한다. 다섯 걸음짜리 장이라 그 중간에 앱을 끄는
    ///    일이 실제로 생기는데, 못 되살리면 가리키는 키는 그대로인데 걸음만 사라져
    ///    **눌러도 아무 일이 안 일어나는 화면**이 된다.
    @Test("rawValue 로 오갈 수 있다 - 앱을 껐다 켜도 그 걸음에서 이어진다")
    func survivesRoundTrip() {
        for step in StackTutorialStep.allCases {
            #expect(StackTutorialStep(rawValue: step.rawValue) == step)
        }
        #expect(StackTutorialStep(rawValue: "") == nil,
                "빈 값은 '콤보 장이 아니다'라는 뜻이라 nil 이라야 한다")
    }
}
