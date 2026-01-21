#!/bin/bash
# Build script for gpu-burn container
# Compatible with RHEL 9.4 and 10.1

set -e

IMAGE_NAME="gpu-burn"
IMAGE_TAG="latest"

echo "Building gpu-burn container image..."
echo "This image will be compatible with RHEL 9.4 and 10.1"
echo ""

# Detect container runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
    echo "Using Podman as container runtime"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
    echo "Using Docker as container runtime"
else
    echo "Error: Neither Podman nor Docker found"
    exit 1
fi

# Build the container
echo "Building ${IMAGE_NAME}:${IMAGE_TAG}..."
${RUNTIME} build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Containerfile .

echo ""
echo "Build complete!"
echo ""
echo "To run gpu-burn for 60 seconds (default):"
echo "  ${RUNTIME} run --rm --device=nvidia.com/gpu=all ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "To run for a custom duration (e.g., 300 seconds):"
echo "  ${RUNTIME} run --rm --device=nvidia.com/gpu=all ${IMAGE_NAME}:${IMAGE_TAG} 300"
echo ""
echo "To run on specific GPUs (e.g., GPU 0 and 1):"
echo "  ${RUNTIME} run --rm --device=nvidia.com/gpu=0,1 ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "To see detailed GPU info during burn:"
echo "  # In another terminal while gpu-burn is running:"
echo "  nvidia-smi -l 1"
