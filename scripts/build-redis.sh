#!/bin/bash
# Build Redis for macOS
#
# Usage: ./scripts/build-redis.sh <version> [arch]
# Example: ./scripts/build-redis.sh 7.4.1 arm64

set -euo pipefail

VERSION="${1:-7.4.1}"
ARCH="${2:-$(uname -m)}"
BUILD_DIR="build/redis-${VERSION}"
OUTPUT_DIR="dist"

echo "🔨 Building Redis ${VERSION} for ${ARCH}..."

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

# Download source
TARBALL="redis-${VERSION}.tar.gz"
if [ ! -f "cache/${TARBALL}" ]; then
    mkdir -p cache
    echo "⬇️  Downloading Redis ${VERSION}..."
    curl -fSL "https://download.redis.io/releases/${TARBALL}" -o "cache/${TARBALL}"
fi

# Extract
echo "📦 Extracting..."
tar -xzf "cache/${TARBALL}" -C "${BUILD_DIR}" --strip-components=1

# Build
cd "${BUILD_DIR}"

# Set architecture
if [ "$ARCH" = "arm64" ]; then
    export CFLAGS="-arch arm64"
    export LDFLAGS="-arch arm64"
elif [ "$ARCH" = "x86_64" ]; then
    export CFLAGS="-arch x86_64"
    export LDFLAGS="-arch x86_64"
fi

echo "🔧 Compiling..."
make -j$(sysctl -n hw.ncpu) BUILD_TLS=no

# Package
cd ../..
PACKAGE_DIR="package/redis-${VERSION}-macos-${ARCH}"
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}/bin"

# Copy binaries
cp "${BUILD_DIR}/src/redis-server" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/src/redis-cli" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/src/redis-benchmark" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/src/redis-check-aof" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/src/redis-check-rdb" "${PACKAGE_DIR}/bin/"

# Strip binaries
strip "${PACKAGE_DIR}/bin/"*

# Create tarball
TARBALL_NAME="redis-${VERSION}-macos-${ARCH}.tar.gz"
echo "📦 Creating ${TARBALL_NAME}..."
cd package
tar -czf "../${OUTPUT_DIR}/${TARBALL_NAME}" "redis-${VERSION}-macos-${ARCH}"
cd ..

# Calculate checksum
CHECKSUM=$(shasum -a 256 "${OUTPUT_DIR}/${TARBALL_NAME}" | cut -d' ' -f1)
SIZE=$(stat -f%z "${OUTPUT_DIR}/${TARBALL_NAME}")

echo ""
echo "✅ Redis ${VERSION} built successfully!"
echo "   File: ${OUTPUT_DIR}/${TARBALL_NAME}"
echo "   Size: ${SIZE} bytes"
echo "   SHA256: ${CHECKSUM}"
echo ""
echo "Manifest entry:"
echo "\"${VERSION}\": {"
echo "  \"${ARCH}\": {"
echo "    \"url\": \"https://github.com/karajanchang/bitl-service-builds/releases/download/redis-${VERSION}/${TARBALL_NAME}\","
echo "    \"sha256\": \"${CHECKSUM}\","
echo "    \"size\": ${SIZE},"
echo "    \"binaries\": [\"redis-server\", \"redis-cli\", \"redis-benchmark\"]"
echo "  }"
echo "}"
