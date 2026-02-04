#!/bin/bash
# Build MySQL for macOS
#
# Usage: ./scripts/build-mysql.sh <version> [arch]
# Example: ./scripts/build-mysql.sh 8.4.3 arm64
#
# Requirements:
#   - CMake: brew install cmake
#   - OpenSSL: brew install openssl@3
#   - pkg-config: brew install pkg-config

set -euo pipefail

VERSION="${1:-8.4.3}"
ARCH="${2:-$(uname -m)}"
BUILD_DIR="build/mysql-${VERSION}"
OUTPUT_DIR="dist"
NPROC=$(/usr/sbin/sysctl -n hw.ncpu)

echo "🔨 Building MySQL ${VERSION} for ${ARCH}..."

# Check dependencies
command -v cmake >/dev/null 2>&1 || { echo "❌ cmake required. Install with: brew install cmake"; exit 1; }

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" cache

# Download source
TARBALL="mysql-${VERSION}.tar.gz"
if [ ! -f "cache/${TARBALL}" ]; then
    echo "⬇️  Downloading MySQL ${VERSION}..."
    curl -fSL "https://dev.mysql.com/get/Downloads/MySQL-${VERSION%.*}/mysql-${VERSION}.tar.gz" -o "cache/${TARBALL}"
fi

# Extract
echo "📦 Extracting..."
mkdir -p "${BUILD_DIR}/src"
tar -xzf "cache/${TARBALL}" -C "${BUILD_DIR}/src" --strip-components=1

# Configure
cd "${BUILD_DIR}"
mkdir -p build && cd build

# Find OpenSSL
if [ -d "/opt/homebrew/opt/openssl@3" ]; then
    OPENSSL_ROOT="/opt/homebrew/opt/openssl@3"
elif [ -d "/usr/local/opt/openssl@3" ]; then
    OPENSSL_ROOT="/usr/local/opt/openssl@3"
else
    echo "❌ OpenSSL not found. Install with: brew install openssl@3"
    exit 1
fi

# Find Homebrew bison
if [ -d "/opt/homebrew/opt/bison/bin" ]; then
    BISON_PATH="/opt/homebrew/opt/bison/bin/bison"
elif [ -d "/usr/local/opt/bison/bin" ]; then
    BISON_PATH="/usr/local/opt/bison/bin/bison"
else
    echo "❌ Homebrew bison not found. Install with: brew install bison"
    exit 1
fi

echo "🔧 Configuring (using bison: ${BISON_PATH})..."
cmake ../src \
    -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_SSL="${OPENSSL_ROOT}" \
    -DWITH_BOOST=system \
    -DDOWNLOAD_BOOST=ON \
    -DWITH_UNIT_TESTS=OFF \
    -DWITH_ROUTER=OFF \
    -DWITH_DEBUG=OFF \
    -DWITH_EDITLINE=bundled \
    -DWITH_LIBEVENT=bundled \
    -DWITH_LZ4=bundled \
    -DWITH_ZSTD=bundled \
    -DWITH_ZLIB=bundled \
    -DWITH_PROTOBUF=bundled \
    -DBISON_EXECUTABLE="${BISON_PATH}"

# Build
echo "🔧 Compiling (this takes ~30 minutes)..."
cmake --build . --parallel ${NPROC} --target mysqld mysql mysqladmin mysqldump

# Package
cd ../../..
PACKAGE_DIR="package/mysql-${VERSION}-macos-${ARCH}"
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}/bin" "${PACKAGE_DIR}/lib"

# Copy binaries
cp "${BUILD_DIR}/build/runtime_output_directory/mysqld" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/build/runtime_output_directory/mysql" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/build/runtime_output_directory/mysqladmin" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/build/runtime_output_directory/mysqldump" "${PACKAGE_DIR}/bin/"

# Copy required libraries
cp -R "${BUILD_DIR}/build/library_output_directory/"*.dylib "${PACKAGE_DIR}/lib/" 2>/dev/null || true

# Strip binaries
strip "${PACKAGE_DIR}/bin/"* 2>/dev/null || true

# Create tarball
TARBALL_NAME="mysql-${VERSION}-macos-${ARCH}.tar.gz"
echo "📦 Creating ${TARBALL_NAME}..."
cd package
tar -czf "../${OUTPUT_DIR}/${TARBALL_NAME}" "mysql-${VERSION}-macos-${ARCH}"
cd ..

# Calculate checksum
CHECKSUM=$(shasum -a 256 "${OUTPUT_DIR}/${TARBALL_NAME}" | cut -d' ' -f1)
SIZE=$(stat -f%z "${OUTPUT_DIR}/${TARBALL_NAME}")

echo ""
echo "✅ MySQL ${VERSION} built successfully!"
echo "   File: ${OUTPUT_DIR}/${TARBALL_NAME}"
echo "   Size: ${SIZE} bytes"
echo "   SHA256: ${CHECKSUM}"
