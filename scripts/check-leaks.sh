#!/bin/bash
#
# check-leaks.sh — scan the repo for personal data before commit / release.
#
# Two layers:
#   1. Local-only patterns from .leak-patterns (gitignored). Add your real
#      secrets there — never commit them. A starter template lives at
#      scripts/.leak-patterns.example.
#   2. Generic patterns (always on): Anthropic sessionKey-shaped strings,
#      and (in --strict mode) any UUID or email.
#
# Usage:
#     ./scripts/check-leaks.sh                # scan source tree
#     ./scripts/check-leaks.sh --strict       # also fail on generic UUID/email
#     ./scripts/check-leaks.sh --binary       # also scan ClaudeUsage.app
#
# Exits 0 on clean, 1 on any hit.

set -e
cd "$(dirname "$0")/.."

STRICT=0
BINARY=0
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --binary) BINARY=1 ;;
    esac
done

FAIL=0
SOURCE_PATTERNS=(--include='*.swift' --include='*.yml' --include='*.md' --include='*.sh' --include='*.py' --include='*.plist' --include='*.json' --include='*.txt')
EXCLUDES=(--exclude='check-leaks.sh' --exclude='.leak-patterns')

# Email regex: local part must start with a letter; domain must start with
# a letter; TLD is 2-4 alpha chars. This rejects Apple retina suffixes
# like "icon@2x.png" while still matching real addresses.
EMAIL_REGEX='[A-Za-z][A-Za-z0-9.+-]*@[A-Za-z][A-Za-z0-9.-]*\.[A-Za-z]{2,4}'
EMAIL_WHITELIST='example\.com|users\.noreply\.github\.com|@anthropic\.com|@apple\.com|placeholder'

UUID_REGEX='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
SESSIONKEY_REGEX='sk-ant-(sid|api)[0-9]+-[A-Za-z0-9_-]{10,}'

green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }

scan_source() {
    local label="$1"; shift
    local pattern="$1"
    local hits
    hits=$(grep -nrE "${SOURCE_PATTERNS[@]}" "${EXCLUDES[@]}" "$pattern" . 2>/dev/null || true)
    if [ -n "$hits" ]; then
        red "X [$label] $pattern"
        echo "$hits" | sed 's/^/    /'
        FAIL=1
    fi
}

scan_binary() {
    local label="$1"; shift
    local pattern="$1"
    local bin
    for bin in $(find . -name 'ClaudeUsage' -path '*/Contents/MacOS/*' 2>/dev/null); do
        if strings "$bin" 2>/dev/null | grep -qE "$pattern"; then
            red "X [$label] pattern '$pattern' found in BINARY: $bin"
            FAIL=1
        fi
    done
}

# --- Layer 1: local .leak-patterns ---
if [ -f .leak-patterns ]; then
    echo "-> Checking against .leak-patterns (local-only)..."
    while IFS= read -r raw; do
        line="${raw%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        scan_source "leak-patterns" "$line"
        [ "$BINARY" -eq 1 ] && scan_binary "leak-patterns" "$line"
    done < .leak-patterns
else
    yellow "i  No .leak-patterns file -- skipping personal-secrets scan."
    yellow "   (Create one from scripts/.leak-patterns.example to enable.)"
fi

# --- Layer 2: generic patterns ---
echo "-> Checking generic patterns..."

# 2a. Anthropic sessionKey shapes -- always fail.
scan_source "generic-sessionkey" "$SESSIONKEY_REGEX"
[ "$BINARY" -eq 1 ] && scan_binary "generic-sessionkey" "$SESSIONKEY_REGEX"

# 2b. Emails -- whitelist-filtered.
HITS=$(grep -nrE "${SOURCE_PATTERNS[@]}" "${EXCLUDES[@]}" "$EMAIL_REGEX" . 2>/dev/null \
    | grep -vE "$EMAIL_WHITELIST" || true)
if [ -n "$HITS" ]; then
    if [ "$STRICT" -eq 1 ]; then
        red "X [generic-email] suspect email-shaped string:"
        echo "$HITS" | sed 's/^/    /'
        FAIL=1
    else
        yellow "!  Possible email leak (warning -- use --strict to fail):"
        echo "$HITS" | sed 's/^/    /'
    fi
fi

# 2c. UUIDs in source -- warn always; fail in strict.
HITS=$(grep -nrE "${SOURCE_PATTERNS[@]}" "${EXCLUDES[@]}" "$UUID_REGEX" . 2>/dev/null || true)
if [ -n "$HITS" ]; then
    if [ "$STRICT" -eq 1 ]; then
        red "X [generic-uuid] UUID-shaped string in source:"
        echo "$HITS" | sed 's/^/    /'
        FAIL=1
    else
        yellow "!  UUID-shaped strings in source (could be placeholders):"
        echo "$HITS" | sed 's/^/    /'
    fi
fi

# Binary UUID scan -- if --binary and --strict.
if [ "$BINARY" -eq 1 ] && [ "$STRICT" -eq 1 ]; then
    scan_binary "generic-uuid" "$UUID_REGEX"
fi

echo
if [ "$FAIL" -eq 0 ]; then
    green "OK No leaks detected. Safe to push."
    exit 0
else
    red "FAIL Leak check failed. Fix the items above before committing."
    exit 1
fi
