#!/usr/bin/env bash
# O que não está no repositório: os headers e a biblioteca da SDL3 para MinGW (o build para
# Windows) e as fontes da vitrine (Inter e JetBrains Mono, SIL OFL). Ficam em
# $LARPERKIT_DEPS (padrão: .deps), que o build lê com -Ddeps.
#   tools/deps.sh
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
out="${LARPERKIT_DEPS:-$here/.deps}"
dl="$out/dl"
w="$out/windows"
mkdir -p "$dl" "$w/include" "$w/lib" "$w/bin" "$out/fonts"

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

# As fontes da vitrine (examples/vitrine).
f=$(get https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip 9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e)
rm -rf "$t"/*
unzip -q -o "$f" -d "$t"
for wt in Regular Medium SemiBold Bold Italic; do cp "$t/extras/ttf/Inter-$wt.ttf" "$out/fonts/"; done
cp "$t/LICENSE.txt" "$out/fonts/Inter-LICENSE.txt"
f=$(get https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip 6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf)
rm -rf "$t"/*
unzip -q -o "$f" -d "$t"
cp "$t/fonts/ttf/JetBrainsMono-Regular.ttf" "$out/fonts/"
cp "$t/OFL.txt" "$out/fonts/JetBrainsMono-LICENSE.txt"
echo "dependências em $out"
