#!/bin/sh
# git 훅 설치 - 새 머신/클론에서 1회 실행: sh scripts/install-hooks.sh
# (.git/hooks 는 버전관리가 안 되므로 이 스크립트로 재설치한다)
set -e
ROOT="$(git rev-parse --show-toplevel)"
HOOK="$ROOT/.git/hooks/pre-commit"

cat > "$HOOK" <<'SH'
#!/bin/sh
# 영어 슬롯에 한국어가 들어가면 커밋 차단 (scripts/check_localization.py)
# 우회가 필요하면: git commit --no-verify
ROOT="$(git rev-parse --show-toplevel)"
python3 "$ROOT/scripts/check_localization.py" || {
  echo ""
  echo "❌ 커밋 차단: 영어 사용자에게 한국어가 노출되는 항목이 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

# CloudKit 컨테이너를 메인 스레드에서 만들 수 있는 코드가 들어오면 커밋 차단.
# 그 한 줄이 런치를 붙잡으면 앱은 워치독에 죽는다 (4.4.6 사고).
sh "$ROOT/scripts/check_main_thread_cloudkit.sh" || {
  echo ""
  echo "❌ 커밋 차단: CloudKit 컨테이너를 관문 밖에서 만들고 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

# 클립보드를 메인 스레드에서 읽는 코드가 들어오면 커밋 차단.
# 유니버설 클립보드가 켜져 있으면 그 한 줄이 초 단위로 기다린다 (5.0.1 멈춤).
sh "$ROOT/scripts/check_main_thread_pasteboard.sh" || {
  echo ""
  echo "❌ 커밋 차단: 클립보드를 메인에서 읽고 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}
# 알림을 메인 밖에서 쏠 수 있는 코드가 들어오면 커밋 차단.
# 배경에서 쏜 알림은 배경에서 화면을 고치게 만든다 (5.0.6 배경 발행 경고).
sh "$ROOT/scripts/check_notification_main.sh" || {
  echo ""
  echo "❌ 커밋 차단: 알림을 메인 밖에서 쏘고 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

# 지구본이 advanceToNextInputMode() 로 돌아가면 커밋 차단.
# 그 API 는 이모지 키보드를 건너뛴다. 시뮬레이터에 타사 키보드를 깔 수 없어
# 사람 눈으로는 못 잡는 자리다 (5.1.0 이모지 신고).
sh "$ROOT/scripts/check_globe.sh" || {
  echo ""
  echo "❌ 커밋 차단: 지구본이 이모지 키보드를 건너뜁니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

# 켜 놓은 언어 중 하나라도 덜 채워졌거나 자리표시자가 깨졌으면 커밋 차단.
# 40개 언어를 사람이 눈으로 못 보므로 이 검사가 유일한 품질 보증이다 (i18n 파이프라인).
python3 "$ROOT/scripts/i18n.py" check || {
  echo ""
  echo "❌ 커밋 차단: 다국어 검사에 걸렸습니다."
  echo "   (번역 채우기: python3 scripts/i18n.py translate <lang> && python3 scripts/i18n.py build)"
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

# 긴 줄표(U+2014 / U+2013)가 들어오면 커밋 차단 - 저장소 전 범위 규칙(CLAUDE.md).
sh "$ROOT/scripts/check_dashes.sh" --staged || {
  echo ""
  echo "❌ 커밋 차단: 긴 줄표가 들어 있습니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
}

SH

chmod +x "$HOOK"
echo "✅ pre-commit 훅 설치 완료: $HOOK"

# ── commit-msg: 커밋 메시지에도 같은 규칙 ──
# CLAUDE.md 의 금지 범위에 커밋 메시지가 포함돼 있는데, 예전에는 검사가 없었다.
MSGHOOK="$ROOT/.git/hooks/commit-msg"
cat > "$MSGHOOK" <<'SH2'
#!/bin/sh
# 커밋 메시지에 긴 줄표(U+2014 / U+2013)가 있으면 차단.
EM="$(printf '\342\200\224')"
EN="$(printf '\342\200\223')"
if grep -q "[$EM$EN]" "$1"; then
  echo "❌ 커밋 차단: 커밋 메시지에 긴 줄표가 있습니다."
  grep -n "[$EM$EN]" "$1"
  echo "   쉼표(,) 마침표(.) 가운뎃점(·) 콜론(:) 또는 괄호로 바꿉니다."
  echo "   (긴급 우회: git commit --no-verify)"
  exit 1
fi
SH2
chmod +x "$MSGHOOK"
echo "✅ commit-msg 훅 설치: $MSGHOOK"
