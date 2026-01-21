# Multi-stage build for gpu-burn compatible with RHEL 9.4 and 10.1
# Uses CUDA toolkit for compilation and NVIDIA runtime for execution

FROM nvidia/cuda:12.6.0-devel-ubi9 AS builder

# Install build dependencies
RUN dnf install -y \
    git \
    make \
    gcc \
    gcc-c++ \
    && dnf clean all

# Clone and build gpu-burn
WORKDIR /build
RUN git clone https://github.com/wilicc/gpu-burn.git && \
    cd gpu-burn && \
    make

# Runtime stage - minimal image with just what's needed to run
FROM nvidia/cuda:12.6.0-runtime-ubi9

# Copy compiled binary from builder
COPY --from=builder /build/gpu-burn/gpu_burn /usr/local/bin/gpu_burn

# Set working directory
WORKDIR /workspace

# Default command runs gpu-burn for 60 seconds
# Users can override with: podman run ... gpu_burn [duration]
ENTRYPOINT ["/usr/local/bin/gpu_burn"]
CMD ["60"]

# Labels for metadata
LABEL maintainer="Mark"
LABEL description="GPU burn-in test tool for NVIDIA GPUs - RHEL 9.4/10.1 compatible"
LABEL version="1.0"
