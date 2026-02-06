#!/bin/bash
set -e

# MongoDB version
VERSION="${1:-8.0.4}"
ARCH="arm64"

echo "=== Packaging MongoDB $VERSION for macOS $ARCH ==="

# Create working directory
WORKDIR=$(mktemp -d)
cd "$WORKDIR"

# Download official MongoDB binary
DOWNLOAD_URL="https://fastdl.mongodb.org/osx/mongodb-macos-arm64-${VERSION}.tgz"
echo "Downloading from $DOWNLOAD_URL..."
curl -L -o mongodb-official.tgz "$DOWNLOAD_URL"

# Extract
echo "Extracting..."
tar xzf mongodb-official.tgz

# Find the extracted directory
MONGODB_DIR=$(ls -d mongodb-macos-*)
echo "Found: $MONGODB_DIR"

# Create BitL package structure
PACKAGE_NAME="mongodb-${VERSION}-macos-${ARCH}"
mkdir -p "$PACKAGE_NAME/bin"

# Copy binaries
echo "Copying binaries..."
cp "$MONGODB_DIR/bin/mongod" "$PACKAGE_NAME/bin/"
cp "$MONGODB_DIR/bin/mongos" "$PACKAGE_NAME/bin/" 2>/dev/null || true
cp "$MONGODB_DIR/bin/mongosh" "$PACKAGE_NAME/bin/" 2>/dev/null || true

# Check if mongosh exists, if not note it
if [ ! -f "$PACKAGE_NAME/bin/mongosh" ]; then
    echo "Note: mongosh not included in server package (install separately if needed)"
fi

# List what we have
echo "Binaries included:"
ls -la "$PACKAGE_NAME/bin/"

# Create tarball
OUTPUT_DIR="${2:-$(pwd)}"
OUTPUT_FILE="$OUTPUT_DIR/$PACKAGE_NAME.tar.gz"
echo "Creating package: $OUTPUT_FILE"
tar czf "$OUTPUT_FILE" "$PACKAGE_NAME"

# Calculate checksum
CHECKSUM=$(shasum -a 256 "$OUTPUT_FILE" | cut -d' ' -f1)
SIZE=$(stat -f%z "$OUTPUT_FILE")

echo ""
echo "=== Build Complete ==="
echo "File: $OUTPUT_FILE"
echo "Size: $SIZE bytes"
echo "SHA256: $CHECKSUM"
echo ""
echo "Add to services.json:"
cat << EOF
"mongodb": {
  "defaultPort": 27018,
  "requiresInit": true,
  "versions": {
    "8.0": {
      "latest": "${VERSION}",
      "releases": {
        "${VERSION}": {
          "arm64": {
            "url": "https://github.com/mur-run/bitl-service-builds/releases/download/mongodb-${VERSION}/mongodb-${VERSION}-macos-arm64.tar.gz",
            "sha256": "${CHECKSUM}",
            "size": ${SIZE},
            "binaries": ["mongod"]
          }
        }
      }
    }
  }
}
EOF

# Cleanup
cd /
rm -rf "$WORKDIR"

echo ""
echo "Done! Upload $OUTPUT_FILE to GitHub releases as mongodb-${VERSION}"
