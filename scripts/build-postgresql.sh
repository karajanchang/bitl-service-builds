#!/bin/bash
set -e

VERSION=${1:-"16.4"}
ARCH=${2:-"arm64"}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../build/postgresql-$VERSION"
DIST_DIR="$SCRIPT_DIR/../dist"
PREFIX="$BUILD_DIR/install"

echo "🐘 Building PostgreSQL $VERSION for $ARCH..."

# Create directories
mkdir -p "$BUILD_DIR" "$DIST_DIR"
cd "$BUILD_DIR"

# Download source
if [ ! -f "postgresql-$VERSION.tar.bz2" ]; then
    echo "📥 Downloading PostgreSQL $VERSION..."
    curl -LO "https://ftp.postgresql.org/pub/source/v$VERSION/postgresql-$VERSION.tar.bz2"
fi

# Extract
if [ ! -d "postgresql-$VERSION" ]; then
    echo "📦 Extracting..."
    tar xf "postgresql-$VERSION.tar.bz2"
fi

cd "postgresql-$VERSION"

# Find OpenSSL and readline paths
if [ "$ARCH" = "arm64" ]; then
    HOMEBREW_PREFIX="/opt/homebrew"
else
    HOMEBREW_PREFIX="/usr/local"
fi

OPENSSL_PATH="$HOMEBREW_PREFIX/opt/openssl@3"
READLINE_PATH="$HOMEBREW_PREFIX/opt/readline"
ICU_PATH="$HOMEBREW_PREFIX/opt/icu4c"

# Configure
echo "⚙️ Configuring..."
./configure \
    --prefix="$PREFIX" \
    --with-openssl \
    --with-readline \
    --with-icu \
    --with-uuid=e2fs \
    --with-libxml \
    CFLAGS="-arch $ARCH -I$OPENSSL_PATH/include -I$READLINE_PATH/include -I$ICU_PATH/include" \
    LDFLAGS="-arch $ARCH -L$OPENSSL_PATH/lib -L$READLINE_PATH/lib -L$ICU_PATH/lib" \
    PKG_CONFIG_PATH="$OPENSSL_PATH/lib/pkgconfig:$READLINE_PATH/lib/pkgconfig:$ICU_PATH/lib/pkgconfig"

# Build
echo "🔨 Building..."
make -j$(sysctl -n hw.ncpu)

# Install to prefix
echo "📦 Installing..."
make install

# Create tarball with only essential binaries
echo "📦 Creating distribution tarball..."
cd "$PREFIX"

# Create a minimal dist with just what we need
TARBALL_NAME="postgresql-$VERSION-macos-$ARCH"
mkdir -p "$DIST_DIR/$TARBALL_NAME/bin"
mkdir -p "$DIST_DIR/$TARBALL_NAME/lib"
mkdir -p "$DIST_DIR/$TARBALL_NAME/share/postgresql"

# Copy essential binaries
for bin in postgres psql pg_ctl initdb createdb dropdb pg_dump pg_restore createuser dropuser pg_isready vacuumdb; do
    if [ -f "bin/$bin" ]; then
        cp "bin/$bin" "$DIST_DIR/$TARBALL_NAME/bin/"
    fi
done

# Copy libraries
cp -r lib/*.dylib "$DIST_DIR/$TARBALL_NAME/lib/" 2>/dev/null || true
cp -r lib/*.a "$DIST_DIR/$TARBALL_NAME/lib/" 2>/dev/null || true

# Copy share files (timezone, sql, etc.)
cp -r share/postgresql/* "$DIST_DIR/$TARBALL_NAME/share/postgresql/" 2>/dev/null || true

# Fix library paths to be relative
cd "$DIST_DIR/$TARBALL_NAME/bin"
for bin in *; do
    # Update library paths to use @executable_path/../lib
    install_name_tool -add_rpath @executable_path/../lib "$bin" 2>/dev/null || true
done

# Create tarball
cd "$DIST_DIR"
tar czf "$TARBALL_NAME.tar.gz" "$TARBALL_NAME"
rm -rf "$TARBALL_NAME"

echo "✅ Built: $DIST_DIR/$TARBALL_NAME.tar.gz"
ls -lh "$DIST_DIR/$TARBALL_NAME.tar.gz"
