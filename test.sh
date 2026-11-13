#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
node --test Tests/player.test.cjs
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ytm-min-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -module-cache-path "${TMPDIR:-/tmp}/ytm-min-module-cache" KeyboardShortcuts.swift Tests/KeyboardShortcutsTests.swift -o "$TEST_DIR/keyboard-tests"
"$TEST_DIR/keyboard-tests"
bash -n build.sh
