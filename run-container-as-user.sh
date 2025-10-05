#!/usr/bin/env bash
set -eo pipefail

echo "Won't work" >&2
exit 1

nix build -L .#nixosConfigurations.dev-x86_64-linux.config.system.build.toplevel -o result-container
toplevel="$(realpath ./result-container)"

# This is similar to Exec= for container@.service but without support for private network and some other
# options that won't work for non-root.
# -> Well, actually unprivileged operation must use private network or veth and it cannot be used with a directory. D'oh!
# -> Let's start it with root, for now.

export SYSTEMD_NSPAWN_UNIFIED_HIERARCHY=1

mkdir -p ./container-root

#FIXME If we ever switch to non-root, add ":idmap" for bind mounts.
sudo systemd-nspawn \
  -M borgnetzwerk-dev \
  -D ./container-root \
  --notify-ready=yes \
  --bind-ro=/nix:/nix \
  --private-users=pick \
  --kill-signal=SIGRTMIN+3 \
  $toplevel/init

