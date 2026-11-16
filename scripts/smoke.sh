#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Boot a disk file in QEMU and check it: SSH comes up, systemd is "running" with
# no failed units, bootc reports a booted image. Exit 0 = pass.
#   scripts/smoke.sh <disk.img> <ssh-private-key>
# Env: KEEP=1 leaves the VM running (ssh -i KEY -p 2222 root@127.0.0.1)
set -euo pipefail
IMG="$1"; KEY="$2"
WORK="$(dirname "$IMG")"

find_fw() { for f in "$@"; do [ -e "$f" ] && { echo "$f"; return; }; done; return 1; }
CODE="$(find_fw /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/OVMF/OVMF_CODE_4M.fd)"
VARS="$(find_fw /usr/share/edk2/x64/OVMF_VARS.4m.fd /usr/share/OVMF/OVMF_VARS_4M.fd)"
cp "$VARS" "$WORK/vars.fd"
ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm

qemu-system-x86_64 \
  -machine q35,accel=$ACCEL -cpu max -smp 2 -m 4G \
  -drive if=pflash,format=raw,readonly=on,file="$CODE" \
  -drive if=pflash,format=raw,file="$WORK/vars.fd" \
  -drive file="$IMG",format=raw,if=virtio \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0 \
  -display none -serial file:"$WORK/serial.log" -daemonize -pidfile "$WORK/qemu.pid"
[ "${KEEP:-}" = 1 ] || trap 'kill "$(cat "$WORK/qemu.pid")" 2>/dev/null || true' EXIT

SSH=(ssh -i "$KEY" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
     -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR root@127.0.0.1)
for i in $(seq 1 60); do "${SSH[@]}" true 2>/dev/null && break; sleep 5; done
"${SSH[@]}" true || { echo "FAIL: no SSH after 300s"; tail -30 "$WORK/serial.log"; exit 1; }

STATE="$("${SSH[@]}" 'systemctl is-system-running --wait' || true)"
FAILED="$("${SSH[@]}" 'systemctl --failed --no-legend --plain')"
"${SSH[@]}" 'uname -r; cat /etc/hostname; bootc status --format humanreadable | head -4'
echo "system state: $STATE"
[ -z "$FAILED" ] || { echo "FAIL: failed units:"; echo "$FAILED"; exit 1; }
[ "$STATE" = running ] || { echo "FAIL: system state $STATE"; exit 1; }
"${SSH[@]}" 'bootc status --format json' | grep -q '"booted"' || { echo "FAIL: bootc status"; exit 1; }
echo "PASS"
