#!/bin/bash
set -euo pipefail

# Build nginx with static OpenSSL for BitL
# Uses /tmp/bitl/nginx as default paths (user-writable, no sudo needed)

NGINX_VERSION="${1:-1.27.3}"
OPENSSL_VERSION="3.2.1"
PCRE2_VERSION="10.42"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${ROOT_DIR}/build/nginx-${NGINX_VERSION}"
OUTPUT_DIR="${ROOT_DIR}/dist/nginx"

echo "🔨 Building nginx ${NGINX_VERSION} with static OpenSSL..."

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download sources
echo "📦 Downloading nginx ${NGINX_VERSION}..."
curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | tar xz

echo "📦 Downloading OpenSSL ${OPENSSL_VERSION}..."
curl -fsSL "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" | tar xz

echo "📦 Downloading PCRE2 ${PCRE2_VERSION}..."
curl -fsSL "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz" | tar xz

# Build nginx
cd "nginx-${NGINX_VERSION}"

echo "⚙️  Configuring nginx..."
./configure \
    --prefix=/tmp/bitl/nginx \
    --sbin-path=/tmp/bitl/nginx/nginx \
    --conf-path=/tmp/bitl/nginx/nginx.conf \
    --error-log-path=/tmp/bitl/nginx/error.log \
    --http-log-path=/tmp/bitl/nginx/access.log \
    --pid-path=/tmp/bitl/nginx/nginx.pid \
    --lock-path=/tmp/bitl/nginx/nginx.lock \
    --http-client-body-temp-path=/tmp/bitl/nginx/client_body_temp \
    --http-proxy-temp-path=/tmp/bitl/nginx/proxy_temp \
    --http-fastcgi-temp-path=/tmp/bitl/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/tmp/bitl/nginx/uwsgi_temp \
    --http-scgi-temp-path=/tmp/bitl/nginx/scgi_temp \
    --with-openssl="../openssl-${OPENSSL_VERSION}" \
    --with-pcre="../pcre2-${PCRE2_VERSION}" \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --without-http_autoindex_module \
    --without-http_ssi_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module

echo "🔨 Building..."
make -j$(sysctl -n hw.ncpu)

# Verify it's statically linked (no OpenSSL dylib refs)
echo "🔍 Checking dependencies..."
if otool -L objs/nginx | grep -q "libssl\|libcrypto"; then
    echo "⚠️  Warning: nginx still has dynamic OpenSSL references"
    otool -L objs/nginx | grep -E "libssl|libcrypto" || true
else
    echo "✅ OpenSSL is statically linked"
fi

# Package
mkdir -p "$OUTPUT_DIR"
cp objs/nginx "$OUTPUT_DIR/nginx"
chmod +x "$OUTPUT_DIR/nginx"

# Get version info
VERSION=$("$OUTPUT_DIR/nginx" -v 2>&1 | cut -d'/' -f2)

# Create manifest
cat > "$OUTPUT_DIR/manifest.json" << EOF
{
    "name": "nginx",
    "version": "${VERSION}",
    "openssl_version": "${OPENSSL_VERSION}",
    "pcre2_version": "${PCRE2_VERSION}",
    "architecture": "arm64",
    "platform": "darwin",
    "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "static_openssl": true,
    "default_paths": {
        "prefix": "/tmp/bitl/nginx",
        "error_log": "/tmp/bitl/nginx/error.log",
        "pid": "/tmp/bitl/nginx/nginx.pid"
    }
}
EOF

echo ""
echo "✅ nginx ${VERSION} built successfully!"
echo "   Output: ${OUTPUT_DIR}/nginx"
echo "   Size: $(du -h "$OUTPUT_DIR/nginx" | cut -f1)"
echo ""
echo "📋 Default paths (all user-writable):"
echo "   prefix:    /tmp/bitl/nginx"
echo "   error_log: /tmp/bitl/nginx/error.log"
echo "   pid:       /tmp/bitl/nginx/nginx.pid"
