#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Turn the image into a bootable disk FILE (for virtual machines). Needs root,
# because bootc writes through a loop device. Real disks: see install-usb.sh (P2).
#   sudo scripts/disk.sh [out.img] [ssh-public-key]
# Env: IMAGE (default localhost/brahma-os:latest), SIZE (default 20G)
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

IMAGE="${IMAGE:-localhost/brahma-os:latest}"
OUT="${1:-build/brahma-os.img}"
KEY="${2:-}"
SIZE="${SIZE:-20G}"
mkdir -p "$(dirname "$OUT")"

# A rootless build lives in the invoking user's storage: copy it to root's.
# Keep OCI format: composefs rejects Docker v2s2 images (bootc-dev/bootc#1703).
if ! podman image exists "$IMAGE"; then
  OWNER="${SUDO_USER:?image not in root storage and SUDO_USER unset}"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  chown "$OWNER" "$TMP"
  sudo -u "$OWNER" podman save --format oci-archive -o "$TMP/image.tar" "$IMAGE"
  podman load -i "$TMP/image.tar"
fi

rm -f "$OUT"
fallocate -l "$SIZE" "$OUT"
ABS_DIR="$(cd "$(dirname "$OUT")" && pwd)"
KEYARGS=()
if [ -n "$KEY" ]; then
  cp "$KEY" "$ABS_DIR/.authorized_keys"
  KEYARGS=(--root-ssh-authorized-keys /data/.authorized_keys)
fi

podman run --rm --privileged --pid=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  -v "$ABS_DIR:/data" \
  --security-opt label=disable \
  "$IMAGE" \
  bootc install to-disk --composefs-backend --via-loopback "/data/$(basename "$OUT")" \
    --filesystem ext4 --wipe --bootloader systemd "${KEYARGS[@]}"

rm -f "$ABS_DIR/.authorized_keys"
[ -n "${SUDO_USER:-}" ] && chown "$SUDO_USER": "$OUT"
echo "Done: $OUT"
