# BitL Service Builds

Pre-built service binaries for [BitL](https://github.com/karajanchang/BitL) — a native macOS development environment manager.

## Supported Services

| Service | Versions | Architectures |
|---------|----------|---------------|
| MySQL | 8.4, 8.0 | arm64, x86_64 |
| MariaDB | 11.4 | arm64, x86_64 |
| PostgreSQL | 16, 15 | arm64, x86_64 |
| Redis | 7 | arm64, x86_64 |
| Meilisearch | 1.10 | arm64, x86_64 |
| Typesense | 27 | arm64 |
| MinIO | 2024 | arm64, x86_64 |

## Download

Binaries are available as GitHub Releases. BitL automatically downloads them when needed.

Manual download:
```bash
# Example: MySQL 8.4.3 for Apple Silicon
curl -LO https://github.com/karajanchang/bitl-service-builds/releases/download/mysql-8.4.3/mysql-8.4.3-macos-arm64.tar.gz
```

## Manifest

The version manifest is at [`config/services.json`](config/services.json).

BitL fetches this to determine available versions and download URLs.

## Building

Each service has a build script in `scripts/`:

```bash
# Build MySQL 8.4.3 for arm64
./scripts/build-mysql.sh 8.4.3 arm64

# Build all services
./scripts/build-all.sh
```

### Requirements

- macOS 13+ (Ventura)
- Xcode Command Line Tools
- CMake (`brew install cmake`)

## License

Build scripts are MIT licensed. Individual services retain their original licenses:
- MySQL: GPL v2
- MariaDB: GPL v2
- PostgreSQL: PostgreSQL License
- Redis: BSD 3-Clause
- Meilisearch: MIT
- Typesense: GPL v3
- MinIO: AGPL v3
