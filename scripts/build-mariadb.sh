#!/bin/bash
# Build MariaDB for macOS
#
# Usage: ./scripts/build-mariadb.sh <version> [arch]
# Example: ./scripts/build-mariadb.sh 11.4.4 arm64
#
# Requirements:
#   - CMake: brew install cmake
#   - OpenSSL: brew install openssl@3
#   - bison: brew install bison

set -euo pipefail

VERSION="${1:-11.4.4}"
ARCH="${2:-$(uname -m)}"
BUILD_DIR="build/mariadb-${VERSION}"
OUTPUT_DIR="dist"
NPROC=$(/usr/sbin/sysctl -n hw.ncpu)

echo "🔨 Building MariaDB ${VERSION} for ${ARCH}..."

# Check dependencies
command -v cmake >/dev/null 2>&1 || { echo "❌ cmake required. Install with: brew install cmake"; exit 1; }

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" cache

# Download source
TARBALL="mariadb-${VERSION}.tar.gz"
if [ ! -f "cache/${TARBALL}" ]; then
    echo "⬇️  Downloading MariaDB ${VERSION}..."
    curl -fSL "https://archive.mariadb.org/mariadb-${VERSION}/source/mariadb-${VERSION}.tar.gz" -o "cache/${TARBALL}"
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
if [ -f "/opt/homebrew/opt/bison/bin/bison" ]; then
    BISON_PATH="/opt/homebrew/opt/bison/bin/bison"
elif [ -f "/usr/local/opt/bison/bin/bison" ]; then
    BISON_PATH="/usr/local/opt/bison/bin/bison"
else
    echo "❌ Homebrew bison not found. Install with: brew install bison"
    exit 1
fi

# Find SDK root (critical for GitHub Actions)
if [ -z "${SDKROOT:-}" ]; then
    SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
fi
echo "📱 Using SDK: ${SDKROOT}"

echo "🔧 Configuring (using bison: ${BISON_PATH})..."
cmake ../src \
    -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
    -DCMAKE_OSX_SYSROOT="${SDKROOT}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-isysroot ${SDKROOT}" \
    -DCMAKE_CXX_FLAGS="-isysroot ${SDKROOT} -stdlib=libc++" \
    -DWITH_SSL="${OPENSSL_ROOT}" \
    -DWITH_UNIT_TESTS=OFF \
    -DPLUGIN_TOKUDB=NO \
    -DPLUGIN_MROONGA=NO \
    -DPLUGIN_SPIDER=NO \
    -DPLUGIN_OQGRAPH=NO \
    -DPLUGIN_SPHINX=NO \
    -DPLUGIN_CONNECT=NO \
    -DPLUGIN_ROCKSDB=NO \
    -DPLUGIN_COLUMNSTORE=NO \
    -DPLUGIN_S3=NO \
    -DWITH_MARIABACKUP=OFF \
    -DWITH_WSREP=OFF \
    -DBISON_EXECUTABLE="${BISON_PATH}"

# Build
echo "🔧 Compiling (this takes ~20 minutes)..."
cmake --build . --parallel ${NPROC} --target mariadbd mariadb mariadb-admin mariadb-dump mysql_install_db

# Package
cd ../../..
PACKAGE_DIR="package/mariadb-${VERSION}-macos-${ARCH}"
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}/bin" "${PACKAGE_DIR}/share/mariadb" "${PACKAGE_DIR}/lib"

# Copy binaries
cp "${BUILD_DIR}/build/sql/mariadbd" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/build/client/mariadb" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/build/client/mariadb-admin" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/build/client/mariadb-dump" "${PACKAGE_DIR}/bin/"
cp "${BUILD_DIR}/build/scripts/mysql_install_db" "${PACKAGE_DIR}/bin/" 2>/dev/null || true

# Create MySQL-compatible symlinks
cd "${PACKAGE_DIR}/bin"
ln -sf mariadbd mysqld
ln -sf mariadb mysql
ln -sf mariadb-admin mysqladmin
ln -sf mariadb-dump mysqldump
cd -

# Copy share files needed for initialization
cp -R "${BUILD_DIR}/src/scripts/mysql_system_tables.sql" "${PACKAGE_DIR}/share/mariadb/" 2>/dev/null || true
cp -R "${BUILD_DIR}/src/scripts/mysql_system_tables_data.sql" "${PACKAGE_DIR}/share/mariadb/" 2>/dev/null || true
cp -R "${BUILD_DIR}/build/sql/share/"* "${PACKAGE_DIR}/share/mariadb/" 2>/dev/null || true

# Copy required libraries
cp "${BUILD_DIR}/build/libmariadb/libmariadb"*.dylib "${PACKAGE_DIR}/lib/" 2>/dev/null || true

# Strip binaries
strip "${PACKAGE_DIR}/bin/mariadbd" "${PACKAGE_DIR}/bin/mariadb" "${PACKAGE_DIR}/bin/mariadb-admin" "${PACKAGE_DIR}/bin/mariadb-dump" 2>/dev/null || true

# Create tarball
TARBALL_NAME="mariadb-${VERSION}-macos-${ARCH}.tar.gz"
echo "📦 Creating ${TARBALL_NAME}..."
cd package
tar -czf "../${OUTPUT_DIR}/${TARBALL_NAME}" "mariadb-${VERSION}-macos-${ARCH}"
cd ..

# Calculate checksum
CHECKSUM=$(shasum -a 256 "${OUTPUT_DIR}/${TARBALL_NAME}" | cut -d' ' -f1)
SIZE=$(stat -f%z "${OUTPUT_DIR}/${TARBALL_NAME}")

echo ""
echo "✅ MariaDB ${VERSION} built successfully!"
echo "   File: ${OUTPUT_DIR}/${TARBALL_NAME}"
echo "   Size: ${SIZE} bytes"
echo "   SHA256: ${CHECKSUM}"
echo ""
echo "Manifest entry:"
echo "\"${VERSION}\": {"
echo "  \"${ARCH}\": {"
echo "    \"url\": \"https://github.com/mur-run/bitl-service-builds/releases/download/mariadb-${VERSION}/${TARBALL_NAME}\","
echo "    \"sha256\": \"${CHECKSUM}\","
echo "    \"size\": ${SIZE},"
echo "    \"binaries\": [\"mariadbd\", \"mariadb\", \"mariadb-admin\", \"mariadb-dump\"]"
echo "  }"
echo "}"

