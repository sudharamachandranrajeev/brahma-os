#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build the Brahma OS image with podman (rootless works).
#   scripts/build.sh                 build bootc (only if missing), then the image
# Env: BOOTC_TAG (default v1.17.4), BOOTC_BUILDER (use a published builder image
#      instead of building one), IMAGE (default localhost/brahma-os:latest)
set -euo pipefail
cd "$(dirname "$0")/.."

BOOTC_TAG="${BOOTC_TAG:-v1.17.4}"
IMAGE="${IMAGE:-localhost/brahma-os:latest}"
BOOTC_BUILDER="${BOOTC_BUILDER:-localhost/brahma-os-bootc:${BOOTC_TAG}}"

if ! podman image exists "$BOOTC_BUILDER" && ! podman pull -q "$BOOTC_BUILDER" 2>/dev/null; then
  echo "Building bootc ${BOOTC_TAG} (slow: about 40 minutes the first time)..."
  podman build -f bootc-builder/Containerfile --build-arg BOOTC_TAG="$BOOTC_TAG" \
    -t "$BOOTC_BUILDER" bootc-builder
fi

podman build -f image/Containerfile --build-arg BOOTC_BUILDER="$BOOTC_BUILDER" -t "$IMAGE" .
echo "Built $IMAGE"
