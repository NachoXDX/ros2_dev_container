#!/usr/bin/env bash
# Host device nodes keep their host GIDs (e.g. /dev/dri/renderD* -> host 'render'),
# which rarely match the image's groups. Join whichever groups own them.
set -euo pipefail

user="$(id -un)"
for dev in /dev/dri/* /dev/video* /dev/media* /dev/ttyUSB* /dev/ttyACM* /dev/input/* /dev/bus/usb/*/*; do
    [ -c "$dev" ] || continue
    gid="$(stat -c %g "$dev")"
    [ "$gid" = 0 ] && continue
    name="$(getent group "$gid" | cut -d: -f1 || true)"
    if [ -z "$name" ]; then
        name="host-gid-$gid"
        sudo groupadd -g "$gid" "$name"
    fi
    id -nG "$user" | tr ' ' '\n' | grep -qx "$name" || sudo usermod -aG "$name" "$user"
done
