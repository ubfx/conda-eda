#!/bin/bash

# gcc linux-musl build
set -e
set -x

if [ -z "${TOOLCHAIN_ARCH}" ]; then
	export | grep -i toolchain
	echo "Missing \${TOOLCHAIN_ARCH} env value"
	exit 1
else
	echo "TOOLCHAIN_ARCH: '$TOOLCHAIN_ARCH'"
fi
if [ x"$PKG_VERSION" = x ]; then
	export | grep version
	export | grep VERSION
	exit 1
else
	echo "PKG_VERSION: '$PKG_VERSION'"
fi

if [ x"$TRAVIS" = xtrue ]; then
	CPU_COUNT=2
fi
echo
echo
echo "============================================================"
echo "CFLAGS='$CFLAGS'"
echo "CXXFLAGS='$CXXFLAGS'"
echo "CPPFLAGS='$CPPFLAGS'"
echo "DEBUG_CXXFLAGS='$DEBUG_CXXFLAGS'"
echo "DEBUG_CPPFLAGS='$DEBUG_CPPFLAGS'"
echo "LDFLAGS='$LDFLAGS'"
echo "------------------------------------------------------------"
export CFLAGS="$(echo $CFLAGS) -w"
export CXXFLAGS="$(echo $CXXFLAGS | sed -e's/-std=c++17 //') -w"
export CPPFLAGS="$(echo $CPPFLAGS | sed -e's/-std=c++17 //')"
export DEBUG_CXXFLAGS="$(echo $DEBUG_CXXFLAGS | sed -e's/-std=c++17 //') -w"
export DEBUG_CPPFLAGS="$(echo $DEBUG_CPPFLAGS | sed -e's/-std=c++17 //')"
echo "CFLAGS='$CFLAGS'"
echo "CXXFLAGS='$CXXFLAGS'"
echo "CPPFLAGS='$CPPFLAGS'"
echo "DEBUG_CXXFLAGS='$DEBUG_CXXFLAGS'"
echo "DEBUG_CPPFLAGS='$DEBUG_CPPFLAGS'"
echo "LDFLAGS='$LDFLAGS'"
echo "------------------------------------------------------------"
export
echo "============================================================"
echo
echo
echo "Start directory ============================================"
echo $PWD
ls -l $PWD
echo "------------------------------------------------------------"
ls -l $PWD/*
echo "============================================================"
echo
echo
echo "Source directory ==========================================="
echo $SRC_DIR
ls -l $SRC_DIR
echo "------------------------------------------------------------"
ls -l $SRC_DIR/*
echo "============================================================"
echo
echo

METAL_TARGET=${TOOLCHAIN_ARCH}-elf
LINUX_TARGET=${TOOLCHAIN_ARCH}-linux-musl

# ============================================================

# Check binutils
echo -n "---?"
which $METAL_TARGET-as
ls -l $(which $METAL_TARGET-as)
file $(which $METAL_TARGET-as)
echo "---"
$METAL_TARGET-as --version 2>&1
echo "---"

# Install aliases for the binutil tools
for BINUTIL in $(ls $PREFIX/bin/$METAL_TARGET-* | grep /$METAL_TARGET-); do
	LINUX_BINUTIL="$(echo $BINUTIL | sed -e"s_/$METAL_TARGET-_/$LINUX_TARGET-_" -e's/linux-musl-linux-musl/linux-musl/')"

	if [ ! -e "$LINUX_BINUTIL" ]; then
		ln -sv "$BINUTIL" "$LINUX_BINUTIL"
	fi
done
ls -l $PREFIX/bin/$LINUX_TARGET-*

# ============================================================

# Check the "nostdc" gcc is already installed
echo -n "---?"
which $METAL_TARGET-gcc
ls -l $(which $METAL_TARGET-gcc)
file $(which $METAL_TARGET-gcc)
echo "---"
$METAL_TARGET-gcc --version 2>&1
echo "---"

GCC_STAGE1_VERSION=$($METAL_TARGET-gcc --version 2>&1 | head -1 | sed -e"s/$METAL_TARGET-gcc (//" -e"s/).*//")
GCC_STAGE2_VERSION=$(echo $PKG_VERSION | sed -e's/-.*//')
if [ "$GCC_STAGE1_VERSION" != "$GCC_STAGE2_VERSION" ]; then
	echo
	echo "nostdc version: $GCC_STAGE1_VERSION"
	echo "  this version: $GCC_STAGE2_VERSION"
	echo
	echo "Stage 1 compiler (nostdc) not the same version as us!"
	echo
 	exit 1
fi

rm -rf libstdc++-v3
cd ..

# ============================================================

mkdir -p $SRC_DIR/build-gcc
cd $SRC_DIR/build-gcc

$SRC_DIR/gcc/configure \
	\
        --prefix=/ \
	--program-prefix=$LINUX_TARGET- \
	\
        --with-gmp=$CONDA_PREFIX \
        --with-mpfr=$CONDA_PREFIX \
        --with-mpc=$CONDA_PREFIX \
        --with-isl=$CONDA_PREFIX \
        --with-cloog=$CONDA_PREFIX \
	\
	--target=$LINUX_TARGET \
	--with-pkgversion=$PKG_VERSION \
	--enable-languages="c" \
	--enable-threads=single \
	--enable-multilib \
	\
	--with-musl \
	\
	--disable-nls \
	--disable-libatomic \
	--enable-libgcc \
	--disable-libgomp \
	--disable-libmudflap \
	--disable-libquadmath \
	--disable-libssp \
	--disable-nls \
	--disable-shared \
	--disable-tls \
	\


# Build GCC
mkdir -p $SRC_DIR/build-gcc
cd $SRC_DIR/build-gcc

make -j$CPU_COUNT
make DESTDIR=${PREFIX} install-strip

cd ..

# ============================================================

mkdir -p $SRC_DIR/build-musl
cd $SRC_DIR/build-musl
CC=$LINUX_TARGET $SRC_DIR/musl/configure \
	\
        --prefix=/ \
	\
	--enable-multilib \
	\

# Build libc (musl)
mkdir -p $SRC_DIR/build-musl
cd $SRC_DIR/build-musl
make -j$CPU_COUNT
make DESTDIR=$PREFIX install
cd ..

# ============================================================

$PREFIX/bin/$METAL_TARGET-gcc --version
$PREFIX/bin/$LINUX_TARGET-gcc --version

echo $($PREFIX/bin/$LINUX_TARGET-gcc --version 2>&1 | head -1 | sed -e"s/$LINUX_TARGET-gcc (GCC) //")
