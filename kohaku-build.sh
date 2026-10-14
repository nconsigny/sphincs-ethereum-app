#!/usr/bin/env bash
# kohaku-build.sh: production build for every device, laid out for the
# ZKNOX Orange sideloader (https://github.com/ZKNoxHQ/ZKNOXorange):
#
#   build/prod/<target>/app.elf  app.apdu  artifact-manifest.txt
#
# Run from the repository root inside the Ledger app builder image:
#
#   docker run --rm -v "$PWD:/app" \
#     ghcr.io/ledgerhq/ledger-app-builder/ledger-app-builder-lite:latest ./kohaku-build.sh
#
#   DEVICES="nanos2 flex" ./kohaku-build.sh    restrict to those targets
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

declare -A SDK=(
    [nanos2]="$NANOSP_SDK"
    [nanox]="$NANOX_SDK"
    [stax]="$STAX_SDK"
    [flex]="$FLEX_SDK"
    [apex_p]="$APEX_P_SDK"
)

git() { command git -c safe.directory='*' "$@"; }

# artifact-manifest.txt names the source commit, so build from a clean tree.
if [ -n "$(git status --porcelain --untracked-files=no -- . ':!build')" ]; then
    echo "working tree has uncommitted changes; commit before building" >&2
    exit 1
fi
COMMIT="$(git rev-parse HEAD)"

for target in ${DEVICES:-nanos2 nanox stax flex apex_p}; do
    sdk="${SDK[$target]}"
    echo "── $target ($sdk) ──"
    make -j"$(nproc)" BOLOS_SDK="$sdk"

    out="build/prod/$target"
    mkdir -p "$out"
    cp "build/$target/bin/app.elf" "build/$target/bin/app.apdu" "$out/"
    {
        echo "target=$target"
        echo "mode=prod"
        echo "commit=$COMMIT"
        echo "sdk=$(git -C "$sdk" describe --tags --always)"
        echo "elf_sha256=$(sha256sum "$out/app.elf" | cut -d' ' -f1)"
    } > "$out/artifact-manifest.txt"
    echo "   → $out/"
done
