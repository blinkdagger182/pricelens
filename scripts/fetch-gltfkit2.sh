#!/bin/bash
set -euo pipefail

VENDOR_DIR="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}/Vendor"
FRAMEWORK="${VENDOR_DIR}/GLTFKit2.xcframework"
CHECKSUM="9d0c338282acce4986494aa02a5f1495278f56c60d43f31453fefea6875b4928"
URL="https://github.com/warrenm/GLTFKit2/releases/download/0.5.15/GLTFKit2.xcframework.zip"

if [ -d "${FRAMEWORK}" ]; then
  exit 0
fi

mkdir -p "${VENDOR_DIR}"
TMP_ZIP="$(mktemp -t GLTFKit2.XXXXXX.zip)"
trap 'rm -f "${TMP_ZIP}"' EXIT

echo "Downloading GLTFKit2.xcframework…"
curl -fsSL -o "${TMP_ZIP}" "${URL}"

if command -v shasum >/dev/null 2>&1; then
  ACTUAL="$(shasum -a 256 "${TMP_ZIP}" | awk '{print $1}')"
  if [ "${ACTUAL}" != "${CHECKSUM}" ]; then
    echo "error: GLTFKit2 checksum mismatch" >&2
    exit 1
  fi
fi

unzip -qo "${TMP_ZIP}" -d "${VENDOR_DIR}"
echo "Installed ${FRAMEWORK}"
