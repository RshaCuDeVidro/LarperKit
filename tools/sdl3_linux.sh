#!/usr/bin/env bash
# A SDL3 compilada do código-fonte, para um Linux que não tem o pacote dela (o Ubuntu do CI).
# Fica em $LARPERKIT_DEPS/sdl3-linux (padrão: .deps/sdl3-linux); depois:
#   export PKG_CONFIG_PATH=$LARPERKIT_DEPS/sdl3-linux/lib/pkgconfig
#   export LD_LIBRARY_PATH=$LARPERKIT_DEPS/sdl3-linux/lib
# Sem os pacotes de X11 e Wayland, ela sai só com os drivers offscreen e dummy, que bastam
# para os testes e para a vitrine.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
out="${LARPERKIT_DEPS:-$here/.deps}"
dl="$out/dl"
prefix="$out/sdl3-linux"
mkdir -p "$dl"
[ -f "$prefix/lib/pkgconfig/sdl3.pc" ] && { echo "SDL3 já em $prefix"; exit 0; }

f="$dl/SDL3-3.4.20.tar.gz"
[ -f "$f" ] || curl -fsSL --retry 3 -o "$f" https://github.com/libsdl-org/SDL/releases/download/release-3.4.20/SDL3-3.4.20.tar.gz
echo "f3bb06f55bed9557227a700af2ea62e49497ebdf58037732a731a5fb3ef8581f  $f" | sha256sum -c --quiet -
t=$(mktemp -d -p "$out")
trap 'rm -rf "$t"' EXIT
tar -xf "$f" -C "$t"
cmake -S "$t"/SDL3-3.4.20 -B "$t/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF >/dev/null
cmake --build "$t/build" -j"${JOBS:-2}" >/dev/null
cmake --install "$t/build" >/dev/null
echo "SDL3 em $prefix"
