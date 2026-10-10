#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p dist
for arch in arm64 x86_64; do
  swift build --configuration release --triple "$arch-apple-macosx13.0" --scratch-path ".build/release-$arch"
  bin_dir=$(swift build --configuration release --triple "$arch-apple-macosx13.0" --scratch-path ".build/release-$arch" --show-bin-path)
  cp "$bin_dir/drink" "dist/drink-$arch"
done
lipo -create dist/drink-arm64 dist/drink-x86_64 -output dist/drink
codesign --force --sign - dist/drink
file dist/drink
tar -czf dist/drink-macos-universal.tar.gz -C dist drink
(cd dist && shasum -a 256 drink-macos-universal.tar.gz > SHA256SUMS)
printf '\nRelease ready: dist/drink-macos-universal.tar.gz\n'
