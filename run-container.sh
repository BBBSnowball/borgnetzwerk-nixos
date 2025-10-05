#!/usr/bin/env bash
set -eo pipefail

# name must be short enough
name=borg-dev

flake=".#dev-x86_64-linux"

extraArgs=(--log-format bar-with-logs)

case "$(nixos-container status $name 2>/dev/null)" in
  gone)
    ( set -x; nixos-container create $name --flake $flake "${extraArgs[@]}" )
    # We don't want private network or NAT/veth.
    sed -i '/^HOST_ADDRESS/ d; /^LOCAL_ADDRESS/ d; /^PRIVATE_NETWORK=/ s/=.*/=0/' /etc/containers/$name.conf
    nixos-container start $name
    ;;
  up)
    ( set -x; nixos-container update $name --flake $flake "${extraArgs[@]}" )
    ;;
  down)
    ( set -x; nixos-container update $name --flake $flake "${extraArgs[@]}" && nixos-container start $name )
    ;;
  *)
    echo "Unexpected state for container" >&2
    exit 1
    ;;
esac

