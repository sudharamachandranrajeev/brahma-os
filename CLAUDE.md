# Brahma OS — notes for Claude Code sessions

Builds the Brahma OS Desktop edition: an Arch Linux + CachyOS-kernel image made bootable and
atomically updatable by bootc (composefs backend, systemd-boot). The apps and `brahma_core`
live in the `brahma-life-suite` repository; this repo is only the OS image.

## Layout

- `bootc-builder/Containerfile` — compiles bootc at a pinned tag (`BOOTC_TAG`) into a tiny
  image (`/output`). Built without the `selinux` feature and without docs (Arch has no
  libselinux). `CARGO_BUILD_JOBS=2`, no debuginfo, thin LTO: 16 GB machines OOM otherwise.
- `image/Containerfile` — the OS image. Build context is the repo root.
- `scripts/build.sh` (rootless), `scripts/disk.sh` (sudo; disk file via loopback),
  `scripts/smoke.sh` (QEMU boot test, prints PASS).
- `.github/workflows/build.yml` — builder (cached per tag on ghcr.io), image build, chunkah
  rechunk, QEMU smoke test, push `testing`/`stable` + dated tags, cosign sign, syft SBOM attest.

## Gotchas already hit (do not re-learn)

- `podman save` defaults to Docker v2s2; composefs rejects it (bootc#1703). Always
  `--format oci-archive`.
- Rootless podman cannot sandbox pacman hooks: the image sets `DisableSandbox` during the build
  and removes it at the end.
- `RUN echo > /etc/hostname` is lost (podman bind-mounts it during RUN). Use `COPY`.
- bootc's auto-update timer never runs on composefs (bootc#2578): ship our own timer (P2).

## Rules

- Never write to a real disk except through the P2 `install-usb.sh`, which only accepts
  `/dev/disk/by-id/usb-*`. Never touch the dev laptop's internal disk.
- Pin versions: bootc tag, chunkah tag, GitHub Actions by commit SHA.
- No personal data, hostnames, IPs or secrets in commits; gitleaks before pushing.
- Licence: Apache-2.0, REUSE (`REUSE.toml`). Credit upstream work in `NOTICE`.
- Plan and phase gates: the Brahma OS working plan (kept outside the repo).
