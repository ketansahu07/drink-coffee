#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
archive=${1:-dist/drink-macos-universal.tar.gz}
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/drink-install-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
prefix=$test_dir/install\ folder
DRINK_INSTALL_ROOT="$prefix" sh install.sh --local "$archive" --no-path > "$test_dir/install.log"
[ -L "$prefix/bin/drink" ]
"$prefix/bin/drink" --version | grep -q '^drink '
"$prefix/bin/drink" coffee 1s --demo --no-animation > "$test_dir/demo.log"
DRINK_INSTALL_ROOT="$prefix" sh install.sh --local "$archive" --no-path > "$test_dir/update.log"
before=$(shasum -a 256 "$prefix/share/drink-coffee/drink")
mkdir "$test_dir/corrupt"
cp "$archive" "$test_dir/corrupt/drink-macos-universal.tar.gz"
cp "$(dirname "$archive")/SHA256SUMS" "$test_dir/corrupt/SHA256SUMS"
printf 'tampered' >> "$test_dir/corrupt/drink-macos-universal.tar.gz"
if DRINK_INSTALL_ROOT="$prefix" sh install.sh --local "$test_dir/corrupt/drink-macos-universal.tar.gz" --no-path > "$test_dir/corrupt.log" 2>&1; then
  printf 'FAIL: accepted a corrupted archive\n' >&2; exit 1
fi
after=$(shasum -a 256 "$prefix/share/drink-coffee/drink")
[ "$before" = "$after" ]
grep -q 'Checksum mismatch' "$test_dir/corrupt.log"
mkdir -p "$test_dir/collision/bin"
printf 'existing command\n' > "$test_dir/collision/bin/drink"
if DRINK_INSTALL_ROOT="$test_dir/collision" sh install.sh --local "$archive" --no-path > "$test_dir/collision.log" 2>&1; then
  printf 'FAIL: replaced an unrelated command\n' >&2; exit 1
fi
grep -q '^existing command$' "$test_dir/collision/bin/drink"
DRINK_INSTALL_ROOT="$prefix" sh uninstall.sh > "$test_dir/uninstall.log"
[ ! -e "$prefix/bin/drink" ] && [ ! -L "$prefix/bin/drink" ]
[ ! -e "$prefix/share/drink-coffee/drink" ]
printf 'Installer checks passed: install, run, update, corrupted archive, collision, uninstall.\n'
