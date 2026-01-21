#!/bin/bash
# Convenience wrapper for common gpu-burn usage patterns

IMAGE_NAME="gpu-burn:latest"
RUNTIME=""

# Detect container runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo "Error: Neither Podman nor Docker found"
    exit 1
fi

# Function to show usage
show_usage() {
    cat << EOF
GPU-Burn Container Wrapper

Usage: $0 [OPTIONS] [DURATION]

OPTIONS:
    -a, --all           Test all GPUs (default)
    -g, --gpu GPU_IDS   Test specific GPU(s) (comma-separated, e.g., 0,1)
    -d, --duration SEC  Test duration in seconds (default: 60)
    -m, --monitor       Launch nvidia-smi monitoring in background
    -h, --help          Show this help message

EXAMPLES:
    # Test all GPUs for 60 seconds (default)
    $0

    # Test all GPUs for 5 minutes
    $0 -d 300

    # Test only GPU 0 and 1 for 2 minutes
    $0 -g 0,1 -d 120

    # Test with live monitoring
    $0 -d 180 -m

    # Quick 10-second validation
    $0 10

MONITORING:
    When running, you can monitor in another terminal:
        nvidia-smi -l 1
        watch -n 1 nvidia-smi
EOF
}

# Default values
GPU_SPEC="all"
DURATION=60
MONITOR=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            GPU_SPEC="all"
            shift
            ;;
        -g|--gpu)
            GPU_SPEC="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -m|--monitor)
            MONITOR=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        [0-9]*)
            # If just a number, treat it as duration
            DURATION="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Verify image exists
if ! ${RUNTIME} image exists ${IMAGE_NAME}; then
    echo "Error: Image ${IMAGE_NAME} not found"
    echo "Please run ./build.sh first"
    exit 1
fi

# Build device specification
DEVICE_SPEC="--device=nvidia.com/gpu=${GPU_SPEC}"

# Start monitoring if requested
MONITOR_PID=""
if [ "$MONITOR" = true ]; then
    echo "Starting GPU monitoring..."
    nvidia-smi -l 1 > gpu-monitor-$$.log 2>&1 &
    MONITOR_PID=$!
    echo "Monitoring GPU stats (PID: ${MONITOR_PID})"
    echo "Log file: gpu-monitor-$$.log"
    sleep 2
fi

# Display test configuration
echo "=== GPU-Burn Test Configuration ==="
echo "Runtime:  ${RUNTIME}"
echo "GPUs:     ${GPU_SPEC}"
echo "Duration: ${DURATION} seconds"
echo "Monitor:  ${MONITOR}"
echo ""
echo "Starting test..."
echo ""

# Run gpu-burn
START_TIME=$(date +%s)
if ${RUNTIME} run --rm ${DEVICE_SPEC} ${IMAGE_NAME} ${DURATION}; then
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    
    echo ""
    echo "=== Test Complete ==="
    echo "Elapsed time: ${ELAPSED} seconds"
    echo "Status: PASSED"
    
    if [ "$MONITOR" = true ] && [ -n "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null
        echo "Monitoring stopped. Log saved to: gpu-monitor-$$.log"
        echo ""
        echo "Peak GPU temperatures:"
        grep -oP '\d+C' gpu-monitor-$$.log | sed 's/C//' | sort -n | tail -1 | xargs -I {} echo "  {}°C"
    fi
    
    exit 0
else
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    
    echo ""
    echo "=== Test Failed ==="
    echo "Elapsed time: ${ELAPSED} seconds"
    echo "Status: FAILED"
    
    if [ "$MONITOR" = true ] && [ -n "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null
        echo "Monitoring stopped. Check: gpu-monitor-$$.log"
    fi
    
    exit 1
fi
