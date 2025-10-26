#!/bin/bash
set -e

# WordPress Docker Image Build Script
# Builds the production WordPress image with all extensions and optimizations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default configuration
IMAGE_NAME="${IMAGE_NAME:-zwordpress}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY="${REGISTRY:-}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
PUSH="${PUSH:-false}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --platform)
            PLATFORMS="$2"
            shift 2
            ;;
        --push)
            PUSH="true"
            shift
            ;;
        --local)
            PLATFORMS="linux/amd64"
            PUSH="false"
            shift
            ;;
        --help)
            cat <<EOF
WordPress Docker Image Build Script

Usage: $0 [OPTIONS]

Options:
    --name NAME         Image name (default: zwordpress)
    --tag TAG           Image tag (default: latest)
    --registry URL      Container registry URL (e.g., ghcr.io/username)
    --platform PLATFORMS Build platforms (default: linux/amd64,linux/arm64)
    --push              Push to registry after build
    --local             Build for local platform only (no push)
    --help              Show this help message

Examples:
    # Local build
    $0 --local

    # Build and push to Docker Hub
    $0 --name yourusername/zwordpress --tag 1.0.0 --push

    # Build and push to GHCR
    $0 --registry ghcr.io/username --name zwordpress --tag latest --push

Environment Variables:
    IMAGE_NAME          Default image name
    IMAGE_TAG           Default image tag
    REGISTRY            Default registry URL
    PLATFORMS           Default build platforms
    PUSH                Push to registry (true/false)

EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Construct full image name
if [ -n "$REGISTRY" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
fi

log_info "Building WordPress Docker Image"
log_info "================================"
log_info "Image: $FULL_IMAGE_NAME"
log_info "Platforms: $PLATFORMS"
log_info "Push: $PUSH"
echo ""

# Check if required files exist
log_info "Checking required files..."
REQUIRED_FILES=("Dockerfile" "php.ini" "docker-entrypoint.sh" ".dockerignore")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "Required file not found: $file"
        exit 1
    fi
done
log_info "All required files present"
echo ""

# Make entrypoint executable
chmod +x docker-entrypoint.sh

# Check if buildx is available for multi-platform builds
if [[ "$PLATFORMS" == *","* ]]; then
    log_info "Multi-platform build requested, checking for buildx..."
    if ! docker buildx version &> /dev/null; then
        log_error "Docker buildx is required for multi-platform builds"
        log_error "Install buildx or use --local for single platform build"
        exit 1
    fi

    # Create/use buildx builder
    BUILDER_NAME="zwordpress-builder"
    if ! docker buildx inspect "$BUILDER_NAME" &> /dev/null; then
        log_info "Creating buildx builder: $BUILDER_NAME"
        docker buildx create --name "$BUILDER_NAME" --use
    else
        log_info "Using existing buildx builder: $BUILDER_NAME"
        docker buildx use "$BUILDER_NAME"
    fi

    # Bootstrap builder
    docker buildx inspect --bootstrap
fi

# Build the image
log_info "Building image..."
echo ""

BUILD_ARGS=(
    "--platform" "$PLATFORMS"
    "-t" "$FULL_IMAGE_NAME"
    "--build-arg" "BUILDKIT_INLINE_CACHE=1"
)

if [ "$PUSH" = "true" ]; then
    BUILD_ARGS+=("--push")
    log_warn "Image will be pushed to registry after build"
else
    BUILD_ARGS+=("--load")
fi

if docker buildx build "${BUILD_ARGS[@]}" .; then
    echo ""
    log_info "Build successful!"
    log_info "Image: $FULL_IMAGE_NAME"

    if [ "$PUSH" = "true" ]; then
        log_info "Image has been pushed to registry"
    else
        log_info "Image is available locally"
        echo ""
        log_info "Test the image with:"
        echo "  docker run --rm -p 8080:80 $FULL_IMAGE_NAME"
    fi
else
    echo ""
    log_error "Build failed!"
    exit 1
fi

echo ""
log_info "Done!"
