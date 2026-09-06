#!/bin/sh
# Build the Myon interpreter if needed, then run the MSX emulator.
set -e

cd "$(dirname "$0")"

if [ ! -x ./Myon/myon ]; then
    if [ ! -d ./Myon ]; then
        echo "==> cloning Myon"
        git clone --depth 1 https://github.com/TeamMyonlang/Myon Myon
    fi
    echo "==> building Myon (needs a C compiler and OpenSSL headers)"
    make -C Myon
fi

echo "==> running msx.myon"
exec ./Myon/myon msx.myon "$@"
