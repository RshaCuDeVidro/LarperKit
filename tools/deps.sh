#!/usr/bin/env bash
# O que o build para Windows precisa e não está no repositório: os headers e a biblioteca
# da SDL3 para MinGW. Ficam em $LARPERKIT_DEPS (padrão: .deps), que o build lê com -Ddeps.
#   tools/deps.sh
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
out="${LARPERKIT_DEPS:-$here/.deps}"
dl="$out/dl"
w="$out/windows"
mkdir -p "$dl" "$w/include" "$w/lib" "$w/bin"

get() { # url sha256 -> caminho do arquivo baixado (hash errado para tudo)
    local f="$dl/$(basename "$1")"
    [ -f "$f" ] || curl -fsSL --retry 3 -o "$f" "$1"
    echo "$2  $f" | sha256sum -c --quiet -
    echo "$f"
}

f=$(get https://github.com/libsdl-org/SDL/releases/download/release-3.4.20/SDL3-devel-3.4.20-mingw.tar.gz d2d3bf3fb97a90b22e908a306d7362631ef1bab229d988fe6669595dc29cd9ed)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
tar -xf "$f" -C "$t"
cp -r "$t"/SDL3-*/x86_64-w64-mingw32/include/. "$w/include/"
cp "$t"/SDL3-*/x86_64-w64-mingw32/lib/libSDL3.dll.a "$w/lib/"
cp "$t"/SDL3-*/x86_64-w64-mingw32/bin/SDL3.dll "$w/bin/"
echo "dependências em $out"
