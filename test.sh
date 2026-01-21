#!/bin/bash
# Test script to validate gpu-burn container functionality
# Works on both RHEL 9.4 and 10.1

set -e

IMAGE_NAME="gpu-burn:latest"
TEST_DURATION=10  # Short duration for validation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== GPU-Burn Container Validation ==="
echo ""

# Detect container runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo -e "${RED}Error: Neither Podman nor Docker found${NC}"
    exit 1
fi

echo "Container runtime: ${RUNTIME}"
echo ""

# Check if image exists
echo "Checking if ${IMAGE_NAME} exists..."
if ! ${RUNTIME} image exists ${IMAGE_NAME}; then
    echo -e "${RED}Error: Image ${IMAGE_NAME} not found${NC}"
    echo "Please run ./build.sh first"
    exit 1
fi
echo -e "${GREEN}✓ Image found${NC}"
echo ""

# Check RHEL version
echo "Detecting RHEL version..."
if [ -f /etc/redhat-release ]; then
    RHEL_VERSION=$(cat /etc/redhat-release)
    echo "System: ${RHEL_VERSION}"
else
    echo -e "${YELLOW}Warning: Cannot detect RHEL version${NC}"
fi
echo ""

# Check for NVIDIA GPUs
echo "Checking for NVIDIA GPUs..."
if ! command -v nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: nvidia-smi not found${NC}"
    echo "Please install NVIDIA drivers"
    exit 1
fi

GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
if [ ${GPU_COUNT} -eq 0 ]; then
    echo -e "${RED}Error: No NVIDIA GPUs detected${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found ${GPU_COUNT} NVIDIA GPU(s)${NC}"
nvidia-smi --query-gpu=index,name,memory.total --format=csv
echo ""

# Check NVIDIA Container Toolkit configuration
echo "Checking NVIDIA Container Toolkit..."
if [ "${RUNTIME}" = "podman" ]; then
    if [ -f /etc/cdi/nvidia.yaml ]; then
        echo -e "${GREEN}✓ CDI configuration found${NC}"
    else
        echo -e "${YELLOW}Warning: CDI configuration not found at /etc/cdi/nvidia.yaml${NC}"
        echo "You may need to run: sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
    fi
fi
echo ""

# Test basic GPU access from container
echo "Testing GPU access from container..."
if ${RUNTIME} run --rm --device=nvidia.com/gpu=all nvidia/cuda:12.6.0-base-ubi9 nvidia-smi > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Container can access GPUs${NC}"
else
    echo -e "${RED}Error: Container cannot access GPUs${NC}"
    echo "Please check NVIDIA Container Toolkit configuration"
    exit 1
fi
echo ""

# Test gpu-burn for short duration
echo "Running gpu-burn for ${TEST_DURATION} seconds..."
echo "This will stress test all GPUs briefly"
echo ""

if ${RUNTIME} run --rm --device=nvidia.com/gpu=all ${IMAGE_NAME} ${TEST_DURATION}; then
    echo ""
    echo -e "${GREEN}✓ GPU-burn test completed successfully${NC}"
else
    echo ""
    echo -e "${RED}✗ GPU-burn test failed${NC}"
    exit 1
fi
echo ""

# Summary
echo "=== Validation Summary ==="
echo -e "${GREEN}✓ Container runtime: ${RUNTIME}${NC}"
echo -e "${GREEN}✓ Image: ${IMAGE_NAME}${NC}"
echo -e "${GREEN}✓ GPUs detected: ${GPU_COUNT}${NC}"
echo -e "${GREEN}✓ GPU access: Working${NC}"
echo -e "${GREEN}✓ GPU-burn test: Passed${NC}"
echo ""
echo "The container is ready for production use!"
echo ""
echo "To run a full stress test (e.g., 300 seconds):"
echo "  ${RUNTIME} run --rm --device=nvidia.com/gpu=all ${IMAGE_NAME} 300"
