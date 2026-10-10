#!/bin/sh
# The function is parsed in full before installation starts, including when piped to sh.
drink_install() (
  set -eu
  fail() { printf 'drink: %s\n' "$*" >&2; exit 1; }
  [ "$(uname -s)" = Darwin ] || fail 'This app requires macOS 13 or newer.'
  major=$(/usr/bin/sw_vers -productVersion | cut -d. -f1)
  [ "$major" -ge 13 ] || fail 'This app requires macOS 13 or newer.'
  repo=${DRINK_REPO:-ketansahu07/drink-coffee}
  case "$repo" in *[!A-Za-z0-9_./-]*|/*|*/|*/*/*|*..*) fail 'Invalid DRINK_REPO; use owner/repository.';; esac
  case "$repo" in */*) ;; *) fail 'DRINK_REPO must be owner/repository.';; esac
  asset=drink-macos-universal.tar.gz
  local_archive=
  modify_path=1
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --local) [ "$#" -ge 2 ] || fail '--local needs a release archive.'; local_archive=$2; shift 2;;
      --no-path) modify_path=0; shift;;
      --help) printf 'Usage: sh install.sh [--local release.tar.gz] [--no-path]\n'; exit 0;;
      *) fail "Unknown option: $1";;
    esac
  done
  install_root=${DRINK_INSTALL_ROOT:-"$HOME/.local"}
  case "$install_root" in /*) ;; *) fail 'DRINK_INSTALL_ROOT must be an absolute path.';; esac
  data_dir=$install_root/share/drink-coffee
  bin_dir=$install_root/bin
  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/drink-install.XXXXXX")
  trap 'rm -rf "$work_dir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  if [ -n "$local_archive" ]; then
    [ -f "$local_archive" ] || fail "Archive not found: $local_archive"
    cp "$local_archive" "$work_dir/$asset"
    cp "$(dirname "$local_archive")/SHA256SUMS" "$work_dir/SHA256SUMS"
  else
    version=${DRINK_VERSION:-}
    if [ -z "$version" ]; then
      release_url=$(curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        --output /dev/null --write-out '%{url_effective}' "https://github.com/$repo/releases/latest") || fail 'No release found yet. The repository owner needs to publish the first release.'
      version=${release_url##*/}
    fi
    case "$version" in ''|*[!A-Za-z0-9._-]*) fail 'Invalid release version.';; esac
    base="https://github.com/$repo/releases/download/$version"
    printf 'Downloading drink %s for macOS...\n' "$version"
    for filename in "$asset" SHA256SUMS; do
      curl --fail --silent --show-error --location --retry 3 --proto '=https' --tlsv1.2 \
        "$base/$filename" --output "$work_dir/$filename" || fail "Could not download $filename."
    done
  fi
  expected=$(awk -v name="$asset" '$2 == name {print $1}' "$work_dir/SHA256SUMS")
  case "$expected" in ''|*[!0-9a-f]*) fail 'Missing or invalid release checksum.';; esac
  [ "${#expected}" -eq 64 ] || fail 'Invalid release checksum length.'
  actual=$(shasum -a 256 "$work_dir/$asset" | awk '{print $1}')
  [ "$actual" = "$expected" ] || fail 'Checksum mismatch; nothing was installed. Please retry.'
  tar -xzf "$work_dir/$asset" -C "$work_dir" drink
  [ -f "$work_dir/drink" ] && [ ! -L "$work_dir/drink" ] || fail 'Release does not contain a regular drink executable.'
  chmod 755 "$work_dir/drink"
  "$work_dir/drink" --version || fail 'The downloaded app could not run on this Mac.'
  if [ -e "$bin_dir/drink" ] || [ -L "$bin_dir/drink" ]; then
    [ -L "$bin_dir/drink" ] && [ "$(readlink "$bin_dir/drink")" = "$data_dir/drink" ] || fail "A different command already exists at $bin_dir/drink. It was not replaced."
  fi
  if [ -e "$data_dir" ]; then
    [ ! -L "$data_dir" ] && [ -f "$data_dir/.drink-coffee" ] || fail "Unrecognized directory: $data_dir. It was not changed."
  fi
  mkdir -p "$data_dir" "$bin_dir"
  cp "$work_dir/drink" "$data_dir/drink.new"
  chmod 755 "$data_dir/drink.new"
  mv -f "$data_dir/drink.new" "$data_dir/drink"
  printf 'drink-coffee\n' > "$data_dir/.drink-coffee"
  if [ ! -L "$bin_dir/drink" ]; then ln -s "$data_dir/drink" "$bin_dir/drink"; fi
  # The standard install path is added once for future zsh/bash sessions.
  if [ "$modify_path" -eq 1 ] && [ "$install_root" = "$HOME/.local" ]; then
    case "${SHELL:-/bin/zsh}" in
      */zsh) profile=${ZDOTDIR:-"$HOME"}/.zshrc;;
      */bash) profile=$HOME/.bash_profile;;
      *) profile=;;
    esac
    if [ -n "$profile" ] && ! grep -Fq '# >>> drink-coffee PATH >>>' "$profile" 2>/dev/null; then
      printf '\n# >>> drink-coffee PATH >>>\nexport PATH="$HOME/.local/bin:$PATH"\n# <<< drink-coffee PATH <<<\n' >> "$profile"
    fi
  fi
  printf '\nInstalled: %s/drink\n' "$bin_dir"
  case ":$PATH:" in
    *":$bin_dir:"*) printf 'Try: drink coffee 30m\n';;
    *) printf 'For this terminal, run: export PATH="%s:$PATH"\nThen: drink coffee 30m\n' "$bin_dir";;
  esac
)
drink_install "$@"
