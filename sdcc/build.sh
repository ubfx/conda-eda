#!/bin/bash

set -x
set -e

mkdir build
cd build
CPPFLAGS=-I$PREFIX/include \
CXXFLAGS=-I$PREFIX/include \
../configure \
  --prefix=$PREFIX \
  --disable-pic14-port \
  --disable-pic16-port

make -j$CPU_COUNT
make install
