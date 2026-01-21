# GPU-Burn Containerized Benchmark

A containerized version of gpu-burn for stress-testing NVIDIA GPUs, compatible with RHEL 9.4 and 10.1.

## Overview

This container packages the gpu-burn utility in a way that works consistently across RHEL 9.4 and 10.1 systems. It uses NVIDIA's official CUDA container images based on UBI9, ensuring broad compatibility while maintaining access to GPU acceleration.

## Prerequisites

### Required Software
- Podman or Docker
- NVIDIA GPU drivers installed on host
- NVIDIA Container Toolkit (nvidia-ctk)

### RHEL 10.1 Specific Setup

If you're on RHEL 10.1 and haven't configured NVIDIA container support:

```bash
# Install NVIDIA Container Toolkit
sudo dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/rhel9.0/libnvidia-container.repo
sudo dnf install -y nvidia-container-toolkit

# Configure Podman for NVIDIA CDI
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
sudo nvidia-ctk cdi list
```

### RHEL 9.4 Specific Setup

On RHEL 9.4:

```bash
# Install NVIDIA Container Toolkit
sudo dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/rhel9.0/libnvidia-container.repo
sudo dnf install -y nvidia-container-toolkit

# Configure for your container runtime
sudo nvidia-ctk runtime configure --runtime=podman
```

## Building the Container

```bash
cd gpu-burn-container
./build.sh
```

The build script will:
1. Detect your container runtime (Podman or Docker)
2. Build the multi-stage container image
3. Display usage instructions

## Usage

### Basic Usage

Run gpu-burn for 60 seconds (default):
```bash
podman run --rm --device=nvidia.com/gpu=all gpu-burn:latest
```

### Custom Duration

Run for 300 seconds (5 minutes):
```bash
podman run --rm --device=nvidia.com/gpu=all gpu-burn:latest 300
```

### Specific GPUs

Test only GPU 0 and GPU 1:
```bash
podman run --rm --device=nvidia.com/gpu=0,1 gpu-burn:latest
```

Test only GPU 0:
```bash
podman run --rm --device=nvidia.com/gpu=0 gpu-burn:latest
```

### Monitoring During Test

While gpu-burn runs in one terminal, monitor in another:
```bash
# Watch GPU utilization every second
nvidia-smi -l 1

# Or for more detailed stats
watch -n 1 nvidia-smi
```

### Integration with BCM Workflows

If you're using this with NVIDIA Base Command Manager:

```bash
# Test all GPUs on a compute node
ssh compute-node-01 'podman run --rm --device=nvidia.com/gpu=all gpu-burn:latest 180'

# Parallel testing across multiple nodes
for node in compute-{01..08}; do
    ssh $node 'podman run --rm --device=nvidia.com/gpu=all gpu-burn:latest 180' &
done
wait
```

## Understanding gpu-burn Output

Normal output should show:
```
GPU 0: NVIDIA H100 80GB HBM3 (UUID: GPU-xxx)
Burning GPU 0...
[Time stamps showing test progress]
```

### What to Look For

**Healthy GPU behavior:**
- Consistent temperature increase to thermal equilibrium
- Stable power draw near TDP
- No error messages
- Test completes successfully

**Problem indicators:**
- Error messages mentioning "compare" or "mismatch"
- Crashes or segfaults
- GPU falling off the bus (check dmesg)
- Thermal throttling (watch nvidia-smi temps)

## Troubleshooting

### Container Can't Access GPUs

**Symptom:** "No NVIDIA GPU found" or similar

**RHEL 10.1 Solution:**
```bash
# Regenerate CDI configuration
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

# Verify GPUs are visible
podman run --rm --device=nvidia.com/gpu=all nvidia/cuda:12.6.0-base-ubi9 nvidia-smi
```

**RHEL 9.4 Solution:**
```bash
# Reconfigure nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=podman

# Restart podman (if using system service)
systemctl restart podman
```

### CUDA Version Mismatch

**Symptom:** "CUDA driver version is insufficient"

The container uses CUDA 12.6. Your host driver must support this. Check with:
```bash
nvidia-smi
```

Look at "CUDA Version" in top-right. If it's < 12.6, either:
1. Update your NVIDIA drivers, or
2. Modify the Containerfile to use an older CUDA base image

### SELinux Issues

If you see permission denials:
```bash
# Check for SELinux denials
sudo ausearch -m avc -ts recent

# Temporary workaround (not recommended for production)
sudo setenforce 0

# Proper solution: adjust SELinux policy or use container_t context
```

### Build Failures

**Network issues during build:**
```bash
# Use proxy if needed
podman build --build-arg HTTP_PROXY=http://proxy:port -t gpu-burn:latest -f Containerfile .
```

**Git clone failures:**
```bash
# Pre-download gpu-burn source if corporate firewall blocks GitHub
git clone https://github.com/wilicc/gpu-burn.git
# Then modify Containerfile to use: COPY gpu-burn /build/gpu-burn
```

## Advanced: Modifying Test Parameters

The gpu-burn source allows compilation with different precision modes. To customize:

1. Edit the Containerfile builder stage:
```dockerfile
# In the builder stage, before make:
RUN cd gpu-burn && \
    sed -i 's/DOUBLE_PRECISION/SINGLE_PRECISION/' gpu_burn.cu && \
    make
```

2. Rebuild the container

## Performance Expectations

On H100 GPUs, you should see:
- Power draw: ~650-700W (depending on cooling/boost)
- Temperature: 70-85°C at steady state
- GPU utilization: 99-100%
- Memory utilization: High (depends on GPU memory size)

## Integration with Monitoring Systems

### Export metrics during test:
```bash
# Run gpu-burn while logging nvidia-smi stats
podman run --rm --device=nvidia.com/gpu=all gpu-burn:latest 300 &
nvidia-smi --query-gpu=timestamp,temperature.gpu,power.draw,utilization.gpu \
    --format=csv -l 1 > gpu-burn-metrics.csv
```

### Parse results:
```bash
# Find peak temperature
awk -F, 'NR>1 {print $2}' gpu-burn-metrics.csv | sort -n | tail -1

# Find average power draw
awk -F, 'NR>1 {sum+=$3; count++} END {print sum/count}' gpu-burn-metrics.csv
```

## Version Compatibility Matrix

| RHEL Version | CUDA Runtime | NVIDIA Driver | Container Runtime |
|--------------|--------------|---------------|-------------------|
| 9.4          | 12.6.0       | ≥ 535.x       | Podman/Docker     |
| 10.1         | 12.6.0       | ≥ 535.x       | Podman/Docker     |

## Files Included

- `Containerfile` - Multi-stage build definition
- `build.sh` - Build automation script
- `README.md` - This file

## References

- gpu-burn source: https://github.com/wilicc/gpu-burn
- NVIDIA Container Toolkit: https://github.com/NVIDIA/nvidia-container-toolkit
- CUDA containers: https://hub.docker.com/r/nvidia/cuda

## License

This wrapper follows the licensing of the underlying gpu-burn tool (original license in the git repository).
