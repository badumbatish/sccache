#!/usr/bin/env bash
set -euo pipefail

TARGET="x86_64-unknown-linux-musl"
MUSL_SYSROOT="/usr/lib/musl"
RUST_MUSL_LIBDIR="$(rustc --print sysroot)/lib/rustlib/${TARGET}/lib/self-contained"

if [ ! -f "${RUST_MUSL_LIBDIR}/libc.a" ]; then
    echo "Installing musl target..."
    rustup target add "${TARGET}"
fi

export RUSTC_WRAPPER="sccache"
export CC_x86_64_unknown_linux_musl="clang"
export CFLAGS_x86_64_unknown_linux_musl="--target=${TARGET} --sysroot=${MUSL_SYSROOT} -isystem ${MUSL_SYSROOT}/include"
export AR_x86_64_unknown_linux_musl="llvm-ar"
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER="clang"
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_RUSTFLAGS="\
    -C link-arg=--target=${TARGET} \
    -C link-arg=-fuse-ld=lld \
    -C link-arg=-L${RUST_MUSL_LIBDIR} \
    -C link-arg=-nostdlib"

EXTRA_CONFIGS=()
if [[ "${1:-}" == "--perf" ]]; then
    shift
    echo "Building sccache for ${TARGET} (perf mode: debug symbols, no strip)..."
    EXTRA_CONFIGS+=(--config 'profile.release.strip=false')
    EXTRA_CONFIGS+=(--config 'profile.release.debug=2')
else
    echo "Building sccache for ${TARGET}..."
fi

cargo build --release --target "${TARGET}" \
    --features vendored-openssl \
    --config 'profile.release.lto="thin"' \
    --config 'profile.release.codegen-units=16' \
    "${EXTRA_CONFIGS[@]}" \
    "$@"

BINARY="target/${TARGET}/release/sccache"
echo "Built: ${BINARY}"
file "${BINARY}"

STARDUST_SCCACHE="/home/jjasmine/Developer/igalia/stardust/third_party/prebuilt-toolchain/sccache/sccache-v0.15.0-x86_64-unknown-linux-musl/sccache"
if [ -f "${STARDUST_SCCACHE}" ]; then
    "${STARDUST_SCCACHE}" --stop-server 2>/dev/null || true
    cp -f "${BINARY}" "${STARDUST_SCCACHE}"
    echo "Deployed to stardust"
fi
