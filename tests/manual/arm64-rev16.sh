#!/bin/sh
# Build a standalone Linux AArch64 executable; no guest packages are needed.
# Usage: sh tests/manual/arm64-rev16.sh /path/to/output-binary
# Run the output inside an ARM64 iSH guest. Success prints four cases passed.
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 output-binary" >&2
    exit 2
fi

test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"${CLANG:-clang}" --target=aarch64-linux-musl -nostdlib -static \
    -fuse-ld=lld -Wl,-e,_start "$test_dir/arm64-rev16.S" -o "$1"
