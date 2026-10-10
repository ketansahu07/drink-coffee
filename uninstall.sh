#!/bin/sh
drink_uninstall() (
  set -eu
  install_root=${DRINK_INSTALL_ROOT:-"$HOME/.local"}
  case "$install_root" in /*) ;; *) printf 'Invalid installation path.\n' >&2; exit 1;; esac
  data_dir=$install_root/share/drink-coffee
  link=$install_root/bin/drink
  if [ ! -f "$data_dir/.drink-coffee" ] || [ -L "$data_dir" ]; then
    printf 'No recognized drink-coffee installation found.\n'; exit 0
  fi
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$data_dir/drink" ]; then rm "$link"; fi
  rm -f "$data_dir/drink" "$data_dir/.drink-coffee"
  rmdir "$data_dir" 2>/dev/null || true
  printf 'drink-coffee removed. The shared ~/.local/bin PATH entry was retained.\n'
)
drink_uninstall "$@"
