#!/usr/bin/env bash
# Pre-public-release scan. Exits non-zero on any hit. Run BEFORE asking about release,
# never as a substitute for asking. Usage: ./scripts/public_release_scan.sh <repo-path>
set -uo pipefail
REPO="${1:?usage: public_release_scan.sh <repo-path>}"
cd "$REPO" || exit 2
HITS=0

scan() {  # scan <label> <extended-regex>
  local out
  out=$(git grep -nIE "$2" -- . 2>/dev/null | grep -vE '^(scripts/public_release_scan.sh|PUBLIC_RELEASE_CHECKLIST.md):' | head -20) || true
  if [ -n "$out" ]; then
    echo "### $1"; echo "$out"; echo
    HITS=$((HITS + 1))
  fi
}

echo "=== scanning $REPO @ $(git rev-parse --short HEAD 2>/dev/null || echo 'no-git') ==="
scan "API keys"          '(sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z-]{10,})'
scan "GitHub tokens"     '(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{20,})'
scan "HuggingFace tokens" 'hf_[A-Za-z0-9]{30,}'
scan "private keys"      'BEGIN [A-Z ]*PRIVATE KEY'
scan "absolute home paths" '(/home/[a-z][a-z0-9_-]*/|/Users/[A-Za-z]|C:\\\\Users\\\\)'
scan "internal hosts/IPs" '([0-9]{1,3}\.){3}[0-9]{1,3}|npu-sim'

echo "### tracked files > 25MB"
BIG=$(git ls-files -z 2>/dev/null | xargs -0 -r du -k 2>/dev/null | awk '$1 > 25600 {printf "  %.1f MB  %s\n", $1/1024, $2}')
if [ -n "$BIG" ]; then echo "$BIG"; HITS=$((HITS + 1)); else echo "  none"; fi
echo

echo "### credential-shaped files"
CRED=$(git ls-files 2>/dev/null | grep -iE '(^|/)(\.env|credentials|.*\.pem|.*\.key|.*\.p12|id_rsa)$') || true
if [ -n "$CRED" ]; then echo "$CRED"; HITS=$((HITS + 1)); else echo "  none"; fi
echo

echo "### binaries / weights / archives"
BIN=$(git ls-files 2>/dev/null | grep -iE '\.(bin|safetensors|pt|pth|ckpt|onnx|so|a|o|zip|7z|tar|gz)$') || true
if [ -n "$BIN" ]; then echo "$BIN" | head -20; HITS=$((HITS + 1)); else echo "  none"; fi
echo

if [ "$HITS" -eq 0 ]; then
  echo "SCAN CLEAN — no automated blockers. Manual review in PUBLIC_RELEASE_CHECKLIST.md still required."
  exit 0
fi
echo "SCAN FOUND $HITS CATEGORIES OF ISSUES — do not make public until each is resolved or explicitly accepted."
exit 1
