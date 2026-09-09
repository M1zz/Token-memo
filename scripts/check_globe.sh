#!/bin/sh
# 지구본(다음 키보드) 키가 다시 `advanceToNextInputMode()` 로 돌아갔는지 본다.
#
# 왜 이 검사가 있나:
# `advanceToNextInputMode()` 는 이름만 보면 "다음 키보드로 간다"로 읽히지만,
# **글자 키보드만** 순서대로 돈다. 이모지 키보드는 그 회전에 끼지 않는다.
# 그래서 이 API 를 지구본에 붙이면, 다른 키보드를 함께 쓰는 사람은 지구본을
# 몇 번을 눌러도 이모지에 닿지 못한다. 5.1.0 에서 실제로 신고가 들어왔고,
# 그때까지 세 판(5.0.7 · 5.0.8 · 5.0.9) 동안 살아 있었다.
#
# 사람 눈으로 못 막는 이유가 따로 있다. 키보드가 우리 것 하나뿐이면 돌 곳이 없어
# 아무 일도 안 일어나고, **시뮬레이터에는 타사 키보드를 깔 수 없다.**
# 재현 조건 자체를 개발 중에 만들 수 없는 자리라 기계가 지켜야 한다.
#
# 규칙: 지구본은 `handleInputModeList(from:with:)` 로만 붙인다.
#       (`TypingInputProxy.attachInputModeSwitch(to:)` 가 그 통로다)
#
# 검사 대상: 익스텐션에서 `advanceToNextInputMode` 를 **부르는** 자리.
#       프로토콜 선언·빈 구현·주석은 지나간다.
#
# 예외를 두려면 그 줄(또는 바로 윗줄)에 이유를 붙인다:
#
#           // globe-ok: 지구본이 아니라 <무엇>에서 부른다
#           proxy.advanceToNextInputMode()
#
# 기록: docs/postmortem/KEYBOARD_GLOBE_EMOJI_5_1_0.md
#
# 사용법: sh scripts/check_globe.sh
set -e
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# 부르는 자리만 고른다. 뒤에 `(` 가 붙고, 선언(`func`)이 아닌 것.
RAW="$(grep -rn --include='*.swift' 'advanceToNextInputMode(' \
         ClipKeyboardExtension ClipKeyboard 2>/dev/null \
       | grep -vE '^[^:]+:[0-9]+: *(//|///|\*)' \
       | grep -vE 'func +advanceToNextInputMode' || true)"

HITS=""
for hit in $(echo "$RAW" | tr ' ' '\001'); do
  line="$(echo "$hit" | tr '\001' ' ')"
  [ -n "$line" ] || continue
  file="$(echo "$line" | cut -d: -f1)"
  num="$(echo "$line" | cut -d: -f2)"
  prev=$((num - 1))
  [ "$prev" -lt 1 ] && prev=1
  if sed -n "${prev},${num}p" "$file" 2>/dev/null | grep -q 'globe-ok'; then
    continue
  fi
  HITS="$HITS
$line"
done

HITS="$(echo "$HITS" | sed '/^$/d')"

if [ -n "$HITS" ]; then
  echo "❌ 지구본이 advanceToNextInputMode() 로 돌아갔습니다:"
  echo "$HITS" | sed 's/^/   /'
  echo ""
  echo "   그 API 는 글자 키보드만 돕니다. 이모지 키보드는 건너뜁니다."
  echo "   지구본은 이렇게 붙입니다 (탭=다음, 길게=이모지 포함 목록):"
  echo "     proxy.attachInputModeSwitch(to: button)   // UIButton 에 .allTouchEvents 로"
  echo "   키보드 화면에서는 globeKey(proxy:) 를 쓰면 됩니다."
  echo "   이유: docs/postmortem/KEYBOARD_GLOBE_EMOJI_5_1_0.md"
  exit 1
fi

echo "✅ 지구본은 handleInputModeList 한 길뿐"
