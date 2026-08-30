#!/bin/bash

set -eux

target="${1}"

# Allow setting a channel to account for required components (MinGW)
channel="${2:-nightly}"

# Some runners (native ppc and s390x, self-hosted) don't have all the dependencies
# we need, so we need to install them.

needed_deps=()
to_install=()

if [ "$RUN_IN_DOCKER" != "0" ]; then
    needed_deps+=(rustup m4)
fi

for dep in "${needed_deps[@]}"; do
    ! command -v "$dep" && to_install+=("$dep")
done

if [ ${#to_install[@]} -ne 0 ]; then
    if command -v apt-get; then
        sudo apt-get update
        sudo apt-get install -y "${to_install[@]}"
    elif command -v apk; then
        doas apk add "${to_install[@]}"
    else
        echo "No package manager found"
    fi
fi

# Install the correct Rust version
rustup update "$channel" --no-self-update
rustup default "$channel"
rustup target add "$target"

# `i686-pc-windows-gnu` lost its host tools in rust-lang/rust#161681, so it is
# now built from an `x86_64-pc-windows-gnu` host. Cross-linking needs a 32-bit
# MinGW, which the runner image's software list does not include. MSYS2 does
# ship on the image, so install it from there.
if [ "$target" = "i686-pc-windows-gnu" ]; then
    mingw32_bin="C:/msys64/mingw32/bin"

    /c/msys64/usr/bin/pacman -Sy --noconfirm --needed mingw-w64-i686-gcc

    # Point at the linker directly rather than putting `mingw32/bin` on PATH,
    # where it would shadow the 64-bit toolchain the host build uses.
    echo "CARGO_TARGET_I686_PC_WINDOWS_GNU_LINKER=$mingw32_bin/i686-w64-mingw32-gcc.exe" \
        >> "${GITHUB_ENV:-/dev/null}"
fi
