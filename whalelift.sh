#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 🐋 whalelift — Docker container image upgrader
#
# Safely upgrades a Docker container by:
#   - Pulling the latest version of its image (or a specified tag)
#   - Checking if the image has changed
#   - If changed: stops, removes, and re-creates the container
#     with the same env, ports, volumes, and restart policy
#
# Usage:
#    whalelift [OPTIONS] <container_name>
#
# Options:
#    –dry-run   Preview changes without applying them
#    –print-run  Output the docker run command and exit
#    –tag   Use a specific image tag instead of latest
#
# Install:
#   curl -sSL https://raw.githubusercontent.com/paxytools/whalelift/main/whalelift.sh \
#     | sudo tee /usr/local/bin/whalelift > /dev/null && sudo chmod +x /usr/local/bin/whalelift
#
# Project: https://github.com/paxytools/whalelift
# Version: 0.3.0
###############################################################################

VERSION="0.3.0"

# --- Handle flags ---
DRY_RUN=false
PRINT_RUN=false
TAG=""
CONTAINER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      echo "whalelift v$VERSION"
      exit 0
      ;;
    --help)
      grep '^#' "$0" | cut -c 3-
      exit 0
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --print-run)
      PRINT_RUN=true
      shift
      ;;
    --tag)
      if [[ $# -lt 2 ]]; then
        echo "Error: --tag requires a value"
        exit 1
      fi
      TAG="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1"
      echo "Usage: whalelift [--dry-run] [--print-run] [--tag <tag>] <container_name>"
      exit 1
      ;;
    *)
      # Positional argument (container name)
      CONTAINER="$1"
      shift
      ;;
  esac
done

# --- Validate input ---
if [[ -z "$CONTAINER" ]]; then
  echo "Error: Container name is required"
  echo "Usage: whalelift [--dry-run] [--print-run] [--tag <tag>] <container_name>"
  exit 1
fi

# --- Check container exists ---
if ! docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "❌ Error: container '$CONTAINER' not found."
  exit 1
fi

# --- Identify image ---
ORIGINAL_IMAGE=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER")
IMAGE="$ORIGINAL_IMAGE"

# --- Apply tag if specified ---
if [[ -n "$TAG" ]]; then
  # Extract the base image name (remove existing tag if present)
  if [[ "$IMAGE" == *:* ]]; then
    BASE_IMAGE="${IMAGE%%:*}"
  else
    BASE_IMAGE="$IMAGE"
  fi
  # Create new image reference with specified tag
  IMAGE="${BASE_IMAGE}:${TAG}"
fi

echo "🔍 Container: $CONTAINER"
echo "📦 Current Image: $ORIGINAL_IMAGE"
if [[ "$IMAGE" != "$ORIGINAL_IMAGE" ]]; then
  echo "🏷️  Target Image:  $IMAGE"
fi

# --- Print-run mode ---
if [[ "$PRINT_RUN" == true ]]; then
  # --- Extract run config ---
  ENV_FLAGS=$(docker inspect --format '{{range .Config.Env}}-e {{.}} {{end}}' "$CONTAINER")
  PORT_FLAGS=$(docker inspect --format '{{range $p, $b := .HostConfig.PortBindings}}-p {{(index $b 0).HostPort}}:{{$p}} {{end}}' "$CONTAINER")
  VOLUME_FLAGS=$(docker inspect --format '{{range .Mounts}}-v {{.Source}}:{{.Destination}} {{end}}' "$CONTAINER")
  RESTART_POLICY=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$CONTAINER")
  RESTART_FLAG=$([ "$RESTART_POLICY" != "no" ] && echo "--restart=$RESTART_POLICY" || echo "")

  echo "🖨️  Print-run: equivalent docker run command:"
  echo "docker run -d --name $CONTAINER $RESTART_FLAG $ENV_FLAGS $PORT_FLAGS $VOLUME_FLAGS $IMAGE"
  exit 0
fi

# --- Pull image ---
echo "⬇️  Pulling image..."
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

  if [[ -n "$TAG" ]]; then
    echo "✅ Would upgrade '$CONTAINER' to image with tag '$TAG'."
  else
    echo "✅ Would upgrade '$CONTAINER' to the latest image."
  fi
  exit 0
fi

# --- Upgrade process ---
echo "🛑 Stopping container..."
docker stop "$CONTAINER" > /dev/null

echo "🧹 Removing container..."
docker rm "$CONTAINER" > /dev/null

echo "🚀 Recreating container..."
docker run -d --name "$CONTAINER" $RESTART_FLAG $ENV_FLAGS $PORT_FLAGS $VOLUME_FLAGS "$IMAGE" > /dev/null

if [[ -n "$TAG" ]]; then
  echo "✅ Upgrade complete: '$CONTAINER' is now running image with tag '$TAG'."
else
  echo "✅ Upgrade complete: '$CONTAINER' is now running the latest image."
fi
