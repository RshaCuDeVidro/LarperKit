#!/usr/bin/env bash
# As fontes da vitrine (examples/vitrine): Inter e JetBrains Mono, SIL OFL. Ficam em
# $LARPERKIT_DEPS/fonts (padrão: .deps/fonts); a vitrine lê com --fonts. A SDL3 do Windows o
# build baixa sozinho (build.zig.zon); a do Linux, onde não houver pacote, tools/sdl3_linux.sh.
#   tools/deps.sh
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
out="${LARPERKIT_DEPS:-$here/.deps}"
dl="$out/dl"
mkdir -p "$dl" "$out/fonts"

get() { # url sha256 -> caminho do arquivo baixado (hash errado para tudo)
    local f="$dl/$(basename "$1")"
    [ -f "$f" ] || curl -fsSL --retry 3 -o "$f" "$1"
    echo "$2  $f" | sha256sum -c --quiet -
    echo "$f"
}

t=$(mktemp -d -p "$out")
trap 'rm -rf "$t"' EXIT

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
