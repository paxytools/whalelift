#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 🐋 whalelift — Docker container image upgrader
#
# Safely upgrades a Docker container by:
#   - Pulling the latest version of its image
#   - Checking if the image has changed
#   - If changed: stops, removes, and re-creates the container
#     with the same env, ports, volumes, and restart policy
#
# Usage:
#   whalelift [--dry-run] <container_name>
#
# Install:
#   curl -sSL https://raw.githubusercontent.com/paxytools/whalelift/main/whalelift.sh \
#     | sudo tee /usr/local/bin/whalelift > /dev/null && sudo chmod +x /usr/local/bin/whalelift
#
# Project: https://github.com/paxytools/whalelift
# Version: 0.1.0
###############################################################################

VERSION="0.1.0"

# --- Handle flags ---
if [[ "${1:-}" == "--version" ]]; then
  echo "whalelift v$VERSION"
  exit 0
fi

if [[ "${1:-}" == "--help" ]]; then
  grep '^#' "$0" | cut -c 3-
  exit 0
fi

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi

# --- Validate input ---
if [[ $# -ne 1 ]]; then
  echo "Usage: whalelift [--dry-run] <container_name>"
  exit 1
fi

CONTAINER="$1"

# --- Check container exists ---
if ! docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "❌ Error: container '$CONTAINER' not found."
  exit 1
fi

# --- Identify image ---
IMAGE=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER")
echo "🔍 Container: $CONTAINER"
echo "📦 Image:     $IMAGE"

# --- Pull image ---
echo "⬇️  Pulling latest image..."
docker pull "$IMAGE" > /dev/null

# --- Compare image IDs ---
CURRENT_ID=$(docker inspect -f '{{.Image}}' "$CONTAINER")
LATEST_ID=$(docker inspect -f '{{.Id}}' "$IMAGE")

if [[ "$CURRENT_ID" == "$LATEST_ID" ]]; then
  echo "✅ Already up-to-date."
  exit 0
fi

echo "⚠️  New image detected. Preparing to upgrade..."

# --- Extract run config ---
ENV_FLAGS=$(docker inspect --format '{{range .Config.Env}}-e {{.}} {{end}}' "$CONTAINER")
PORT_FLAGS=$(docker inspect --format '{{range $p, $b := .HostConfig.PortBindings}}-p {{(index $b 0).HostPort}}:{{$p}} {{end}}' "$CONTAINER")
VOLUME_FLAGS=$(docker inspect --format '{{range .Mounts}}-v {{.Source}}:{{.Destination}} {{end}}' "$CONTAINER")
RESTART_POLICY=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$CONTAINER")
RESTART_FLAG=$([ "$RESTART_POLICY" != "no" ] && echo "--restart=$RESTART_POLICY" || echo "")

# --- Dry-run mode ---
if [[ "$DRY_RUN" == true ]]; then
  echo "🧾 Dry-run: would run this command:"
  echo "docker run -d --name $CONTAINER $RESTART_FLAG $ENV_FLAGS $PORT_FLAGS $VOLUME_FLAGS $IMAGE"
  exit 0
fi

# --- Upgrade process ---
echo "🛑 Stopping container..."
docker stop "$CONTAINER" > /dev/null

echo "🧹 Removing container..."
docker rm "$CONTAINER" > /dev/null

echo "🚀 Recreating container..."
docker run -d --name "$CONTAINER" $RESTART_FLAG $ENV_FLAGS $PORT_FLAGS $VOLUME_FLAGS "$IMAGE" > /dev/null

echo "✅ Upgrade complete: '$CONTAINER' is now running the latest image."
