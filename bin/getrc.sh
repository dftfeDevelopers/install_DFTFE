#!/bin/bash
# This script sets up environment for running the rc shell.
# After it completes, start a login with "rc -l"

# Will look for rc in $PREFIX/bin and install if not present.
# Also sets 
PREFIX=$HOME/$LMOD_SYSTEM_NAME
if [ $# -eq 1 ]; then
    PREFIX="$1"
fi

get_rc() {
  mkdir -p $PREFIX
  dir="`mktemp -d`"
  cwd="`pwd`"
  cd "$dir"
    git clone --branch parser https://github.com/frobnitzem/rc
    cd rc
    mkdir -p "$PREFIX/bin"
    mkdir -p "$PREFIX/lib"
    mkdir -p "$PREFIX/share/man/man1"
    make -j4 install PREFIX="$PREFIX"
  cd "$cwd"
  rm -fr "$dir"
}

# test for functioning rc
test_rc() {
  rc -c 'echo success' 2>/dev/null | grep -q success
}

if ! test_rc; then
  if ! grep -q "$PREFIX/bin" <<<"$PATH"; then
    PATH="$PATH:$PREFIX/bin"
  fi
  if ! grep -q "$PREFIX/share/man" <<<"$MANPATH"; then
    MANPATH="$MANPATH:$PREFIX/share/man"
  fi
  if ! [ -x "$PREFIX/bin/rc" ]; then
      echo "Installing rc into $PREFIX/bin"
      get_rc
  fi
fi
