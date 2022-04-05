#!/bin/sh

build_binutils1() {	
	cd binutils-$version

	mkdir -v build
	cd       build
	
	../configure  \
		--prefix=/tools \
		--with-sysroot=$ROOTFS \
		--target=$TARGET \
		--disable-nls \
		--disable-werror \
		--with-lib-path=/tools/lib:/tools/lib32
	make
	mkdir -v /tools/lib && ln -sv lib /tools/lib64
	mkdir -p /tools/lib32
	make install
}

build_binutils2() {	
	cd $name-$version

	mkdir -v build
	cd       build

	CC=$TARGET-gcc \
	AR=$TARGET-ar \
	RANLIB=$TARGET-ranlib \
	../configure \
		--prefix=/tools \
		--disable-nls \
		--disable-werror \
		--with-lib-path=/tools/lib \
		--with-sysroot
	make
	make install
	make -C ld clean
	make -C ld LIB_PATH=/usr/lib:/lib:/usr/lib32
	cp -v ld/ld-new /tools/bin
}

build_libgmp() {
	cd gmp-$version
	
	./configure \
		--prefix=/tools \
		--enable-cxx \
		--build=$TARGET \
		--disable-static
	make
	make install
}

build_libmpfr() {
	cd mpfr-$version
	
	./configure --prefix=/tools --disable-static
	make
	make install
}

build_libmpc() {
	cd mpc-$version
	
	./configure --prefix=/tools --disable-static
	make
	make install
}

build_linux_headers() {
	cd linux-$version
	make mrproper
	make headers
	find usr/include -name '.*' -delete
	rm usr/include/Makefile
	mkdir -p /tools/include
	cp -rv usr/include/* /tools/include
}

build_glibc() {
	cd $name-$version

	mkdir -v build32
	cd       build32
		
	echo slibdir=/tools/lib32 > configparms
	../configure \
		  --prefix=/tools \
		  --host=$TARGET32 \
		  --build=$(../scripts/config.guess) \
		  --libdir=/tools/lib32 \
		  --enable-kernel=3.2 \
		  --with-headers=/tools/include \
		  CC="$TARGET-gcc -m32" \
		  CXX="$TARGET-g++ -m32"
	make
	make install

	mkdir -v ../build
	cd       ../build
	
	../configure \
		  --prefix=/tools \
		  --host=$TARGET \
		  --build=$(../scripts/config.guess) \
		  --enable-kernel=3.2 \
		  --with-headers=/tools/include
	make
	make install
}

build_gcc2() {	
	cd $name-$version

	mkdir -v build32
	cd       build32
		
	../libstdc++-v3/configure \
		--host=i686-venom-linux-gnu \
		--prefix=/tools \
		--libdir=/tools/lib32 \
		--disable-multilib \
		--disable-nls \
		--disable-libstdcxx-threads \
		--disable-libstdcxx-pch \
		--with-gxx-include-dir=/tools/$TARGET/include/c++/$version \
		CC="$TARGET-gcc -m32"          \
		CXX="$TARGET-g++ -m32"
	make
	make install
	cd -

	mkdir -v build
	cd       build
	
	../libstdc++-v3/configure \
		--host=$TARGET \
		--prefix=/tools \
		--disable-multilib \
		--disable-nls \
		--disable-libstdcxx-threads \
		--disable-libstdcxx-pch \
		--with-gxx-include-dir=/tools/$TARGET/include/c++/$version
	make
	make install
}

modify_gcc() {
	for file in gcc/config/linux.h gcc/config/i386/linux.h gcc/config/i386/linux64.h
	do
	  cp -uv $file $file.orig
	  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
		  -e 's@/usr@/tools@g' $file.orig > $file
	  echo '
	#undef STANDARD_STARTFILE_PREFIX_1
	#undef STANDARD_STARTFILE_PREFIX_2
	#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
	#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
	  touch $file.orig
	done
	
	sed -i -e 's@/lib/ld-linux.so.2@/lib32/ld-linux.so.2@g' gcc/config/i386/linux64.h
	sed -i -e '/MULTILIB_OSDIRNAMES/d' gcc/config/i386/t-linux64
	echo "MULTILIB_OSDIRNAMES = m64=../lib m32=../lib32 mx32=../libx32" >> gcc/config/i386/t-linux64
}

build_gcc3() {
	cd $name-$version

	#mv -v ../mpfr-$mpfr_ver mpfr
	#mv -v ../gmp-$gmp_ver gmp
	#mv -v ../mpc-$mpc_ver mpc
	
	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
		`dirname $($TARGET-gcc -print-libgcc-file-name)`/include-fixed/limits.h
		
	modify_gcc
	
	mkdir -v build
	cd       build
	
	CC=$TARGET-gcc \
	CXX=$TARGET-g++ \
	AR=$TARGET-ar \
	RANLIB=$TARGET-ranlib \
	../configure \
		--prefix=/tools \
		--with-local-prefix=/tools \
		--with-native-system-header-dir=/tools/include \
		--with-mpc=/tools \
		--with-gmp=/tools \
		--with-mpfr=/tools \
		--enable-languages=c,c++ \
		--disable-libstdcxx-pch \
		--disable-bootstrap \
		--disable-libgomp \
		--with-multilib-list=m32,m64
	make
	make install
	ln -sv gcc /tools/bin/cc
}

build_gcc1() {
	cd $name-$version

	#mv -v ../mpfr-$mpfr_ver mpfr
	#mv -v ../gmp-$gmp_ver gmp
	#mv -v ../mpc-$mpc_ver mpc
	
	modify_gcc
	
	mkdir -v build
	cd       build

	../configure \
		--target=$TARGET \
		--prefix=/tools \
		--with-glibc-version=2.11 \
		--with-sysroot=$ROOTFS \
		--with-newlib \
		--without-headers \
		--with-local-prefix=/tools \
		--with-native-system-header-dir=/tools/include \
		--with-mpc=/tools \
		--with-gmp=/tools \
		--with-mpfr=/tools \
		--disable-nls \
		--disable-shared \
		--disable-decimal-float \
		--disable-threads \
		--disable-libatomic \
		--disable-libgomp \
		--disable-libmpx \
		--disable-libquadmath \
		--disable-libssp \
		--disable-libvtv \
		--disable-libstdcxx \
		--enable-languages=c,c++ \
		--with-multilib-list=m32,m64
	make
	make install	
}

build_bash() {
	cd $name-$version
	./configure --prefix=/tools --without-bash-malloc
	make -j1
	make install
	ln -sv bash /tools/bin/sh
}

build_bzip2() {
	cd $name-$version
	make -f Makefile-libbz2_so
	make clean
	make
	make PREFIX=/tools install
	cp -v bzip2-shared /tools/bin/bzip2
	cp -av libbz2.so* /tools/lib
	ln -sv libbz2.so.1.0 /tools/lib/libbz2.so
}

build_coreutils() {
	build_default --enable-install-program=hostname
}

build_openssl() {
	cd $name-$version

	./config \
		--prefix=/tools \
		--openssldir=/tools/etc/ssl \
		--libdir=lib \
		shared \
		no-ssl3-method
	make
	make -j1 MANDIR=/tools/share/man MANSUFFIX=ssl install
}

build_ca_certificates() {
	install -Dm644 $SOURCEDIR/cacert-$_version.pem /tools/etc/ssl/cert.pem
}

build_texinfo() {
	cd $name-$version
	
	# fix an issue building the package with Glibc-2.34 or later
        sed -e 's/__attribute_nonnull__/__nonnull/' \
            -i gnulib/lib/malloc/dynarray-skeleton.c
            
	./configure --prefix=/tools
	make
	make install
}

build_scratchpkg() {
	cd $name-*
	
	for s in $WORKDIR/*; do
			case $s in
					*.patch) patch -Np1 -i $s;;
			esac
	done

	install -m755 ../pkgin /tools/bin
	install -m755 xchroot scratch pkgadd pkgdel pkgbuild portsync /tools/bin
	
	sed 's,/etc/scratchpkg.conf,/tools/etc/scratchpkg.conf,' -i /tools/bin/pkgbuild
	sed 's,/etc/scratchpkg.conf,/tools/etc/scratchpkg.conf,' -i /tools/bin/scratch
	sed 's,/etc/scratchpkg.repo,/tools/etc/scratchpkg.repo,' -i /tools/bin/scratch
	
	cat > /tools/etc/scratchpkg.conf << EOF
#
# Configuration file for scratchpkg
#

export CFLAGS="$CFLAGS"
export CXXFLAGS="\${CFLAGS}"
export MAKEFLAGS="$MAKEFLAGS"

# SOURCE_DIR="$SOURCEDIR"
# PACKAGE_DIR="$PACKAGEDIR"
# WORK_DIR="$WORKDIR"
# CURL_OPTS=""
# COMPRESSION_MODE="xz"
# NO_STRIP="no"
# IGNORE_MDSUM="no"
# KEEP_LIBTOOL="no"
# KEEP_LOCALE="no"
# KEEP_DOC="no"

EOF
}

build_curl() {
	cd $name-$version
	./configure \
		--prefix=/tools \
		--disable-static \
		--enable-threaded-resolver \
		--with-openssl \
		--with-ca-bundle=/tools/etc/ssl/cert.pem
	make
	make install
}

build_perl() {
	cd $name-$version
	sh Configure -des -Dprefix=/tools -Dlibs=-lm
	make
	cp -v perl cpan/podlators/scripts/pod2man /tools/bin
	mkdir -pv /tools/lib/perl5/$version
	cp -Rv lib/* /tools/lib/perl5/$version
}

build_python3() {
	cd Python-$version
	./configure --prefix=/tools --without-ensurepip
	make
	make install
}

build_make() {
	build_default --without-guile
}

build_gettext() {
	cd $name-$version
	./configure --disable-shared
	make -j1
	cp -v gettext-tools/src/msgfmt \
	      gettext-tools/src/msgmerge \
	      gettext-tools/src/xgettext \
	      /tools/bin	
}

build_ncurses() {
	cd $name-$version

	sed -i s/mawk// configure
	
	./configure \
		--prefix=/tools \
		--with-shared   \
		--without-debug \
		--without-ada   \
		--enable-widec  \
		--enable-overwrite
	make
	make install
	ln -s libncursesw.so /tools/lib/libncurses.so
}

fetch() {
	[ "$1" ] || continue
	for url in $@; do
		case $url in
			http*|ftp*)
				src=${url##*/}
				[ -f $SOURCEDIR/$src ] && continue
				echo "fetching $url..."
				curl -C - -L --fail --ftp-pasv --retry 999 --retry-delay 3 -o $SOURCEDIR/$src.part $url && \
				mv $SOURCEDIR/$src.part $SOURCEDIR/$src || {
					echo "failed fetch $url"
					exit 1
				};;
		esac
	done
}

unpack() {
	[ "$1" ] || continue
	rm -fr $WORKDIR/*
	for src in $@; do
		filename=${src##*/}
		case $src in
			*.tar|*.tar.gz|*.tar.Z|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.lzma|*.zip)
				echo "extracting $filename..."
				tar -xf "$SOURCEDIR/$filename" -C "$WORKDIR" || {
					echo "failed extracting $filename"
					exit 1
				};;
			*) cp $PORTSDIR/main/$name/$src $WORKDIR;;
		esac
	done	
}

build_default() {
	cd $name-$version
	
	./configure \
		--prefix=/tools $@
	make
	make install
}

toolsbuild() {
	pkg=$1	# name provided in list
	npkg=$(echo $pkg | sed 's/-/_/g') # for calling function
	
	if [ -f /tools/$pkg ]; then
		echo "skipping $pkg"
		return
	fi
	command -V "build_$npkg" 2>/dev/null | grep -qwi function
	if [ $? -ne 0 ]; then
		echo "build function for $pkg not exist!"
		npkg=default
	fi
	
	# name is for cd and extract source
	case $npkg in
		gcc*) name=gcc;;
		binutils*) name=binutils;;
		linux_headers) name=linux;;
		*) name=$pkg;;
	esac
	
	if [ -d $PORTSDIR/main/$name ]; then
		. $PORTSDIR/main/$name/spkgbuild
	else
		echo "port not exist: $name"
		exit 1
	fi
	
	fetch $source
	unpack $source
	
	cd $WORKDIR
	
	echo "--- building $npkg $version ..."
	(set -e -x; build_$npkg)
	if [ $? -ne 0 ]; then
		echo "!!! build $pkg-$version failed !!!"
		exit 1
	else
		echo "--- build $pkg-$version success ---"
	fi
	unset name version source
	touch /tools/$pkg
}

venom_dirs() {
	mkdir -pv $ROOTFS/bin $ROOTFS/usr/lib $ROOTFS/usr/bin $ROOTFS/etc || true
	for i in bash cat chmod dd echo ln mkdir pwd rm stty touch; do
		ln -sv /tools/bin/$i $ROOTFS/bin
	done
	for i in env install perl printf; do
		ln -sv /tools/bin/$i $ROOTFS/usr/bin
	done
	ln -sv /tools/lib/libgcc_s.so /tools/lib/libgcc_s.so.1 $ROOTFS/usr/lib
	ln -sv /tools/lib/libstdc++.a /tools/lib/libstdc++.so /tools/lib/libstdc++.so.6 $ROOTFS/usr/lib
	ln -sv bash $ROOTFS/bin/sh
	ln -sv /proc/self/mounts $ROOTFS/etc/mtab
	install -dm 1777 $ROOTFS/tmp

cat > $ROOTFS/etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
EOF

cat > $ROOTFS/etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
wheel:x:17:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
nogroup:x:99:
users:x:999:
EOF

	# scratchpkg db
	mkdir -p \
		$ROOTFS/var/lib/scratchpkg/db \
		$ROOTFS/var/lib/scratchpkg/db.perms
	
	# pkgs and srcs
	mkdir -p \
		$ROOTFS/var/cache/scratchpkg/sources \
		$ROOTFS/var/cache/scratchpkg/packages \
		$ROOTFS/var/cache/scratchpkg/work
		
	# ports
	mkdir -p $ROOTFS/usr/ports/main
}

mount_pseudo() {
	mkdir -p $ROOTFS/dev $ROOTFS/run $ROOTFS/proc $ROOTFS/sys
	mount --bind /dev $ROOTFS/dev
	mount -t devpts devpts $ROOTFS/dev/pts -o gid=5,mode=620
	mount -t proc proc $ROOTFS/proc
	mount -t sysfs sysfs $ROOTFS/sys
	mount -t tmpfs tmpfs $ROOTFS/run
	if [ -h $ROOTFS/dev/shm ]; then
	  mkdir -p $ROOTFS/$(readlink $ROOTFS/dev/shm)
	fi
}

umount_pseudo() {
	unmount $ROOTFS/dev/pts
	unmount $ROOTFS/dev
	unmount $ROOTFS/run
	unmount $ROOTFS/proc
	unmount $ROOTFS/sys
}

mountbind_srcpkg() {
	mount --bind $SOURCEDIR $ROOTFS/var/cache/scratchpkg/sources
	mount --bind $PACKAGEDIR $ROOTFS/var/cache/scratchpkg/packages
	mount --bind $WORKDIR $ROOTFS/var/cache/scratchpkg/work
	mount --bind $PORTSDIR $ROOTFS/usr/ports
}

unmountbind_srcpkg() {
	unmount $ROOTFS/var/cache/scratchpkg/sources
	unmount $ROOTFS/var/cache/scratchpkg/packages
	unmount $ROOTFS/var/cache/scratchpkg/work
	unmount $ROOTFS/usr/ports
}

unmount() {
	while true; do
		mountpoint -q $1 || break
		umount $1 2>/dev/null
	done
}

interrupted() {
	die "script $(basename $0) aborted!"
}

die() {
	[ "$@" ] && printerror $@
	unmountbind_srcpkg
	umount_pseudo
	exit 1
}

printerror() {
	echo "ERROR: $@"
}

runinchroot() {
	if [ -x $ROOTFS/usr/bin/env ]; then
		ENVVENOM=/usr/bin/env
	else
		ENVVENOM=/tools/bin/env
	fi
	cd $ROOTFS >/dev/null 2>&1
	mount_pseudo
	mountbind_srcpkg
	cp -L /etc/resolv.conf $ROOTFS/etc/
	chroot "$ROOTFS" $ENVVENOM -i \
		BOOTSTRAP=1 \
	    HOME=/root \
	    TERM="$TERM" \
	    PS1='(venom chroot) \u:\w\$ ' \
	    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin $@
	retval=$?
	unmountbind_srcpkg
	umount_pseudo
	cd - >/dev/null 2>&1
	return $retval
}

bootsrap_base() {	
	if [ ! -d $ROOTFS/var/lib/scratchpkg/db ]; then
		venom_dirs
	fi
	
	for i in $basepkgs; do
		[ -f $ROOTFS/var/lib/scratchpkg/db/$i ] && continue
		case $i in
			filesystem|gcc|bash|dash|perl|coreutils) runinchroot pkgin -i -c $i || die;;
			*)          runinchroot pkgin -i $i || die;;
		esac
	done
}

TOPDIR="$(dirname $(dirname $(realpath $0)))"

trap "interrupted" 1 2 3 15

PATH=/tools/bin:$PATH

TARGET=x86_64-venom-linux-gnu
TARGET32=i686-venom-linux-gnu

MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"
CFLAGS="${CFLAGS:--O2 -march=x86-64 -pipe}"

export LC_ALL=C PATH MAKEFLAGS ROOTFS TARGET TARGET32

PORTSDIR="$TOPDIR/ports"
SOURCEDIR="$TOPDIR/output/sources"
PACKAGEDIR="$TOPDIR/output/packages"
WORKDIR="$TOPDIR/output/work"
ROOTFS="$TOPDIR/output/rootfs"

mkdir -p $WORKDIR $SOURCEDIR $PACKAGEDIR $ROOTFS

pkgs="binutils1 libgmp libmpfr libmpc gcc1 linux-headers glibc gcc2 binutils2 gcc3 m4 ncurses bash bison
	bzip2 coreutils diffutils file findutils gawk gettext grep gzip make patch perl
	python3 sed tar texinfo xz openssl ca-certificates curl scratchpkg"

basepkgs="filesystem linux-api-headers man-pages glibc tzdata zlib bzip2 file readline m4 bc binutils libgmp libmpfr libmpc attr acl shadow gcc
	pkgconf ncurses libcap sed psmisc iana-etc bison flex grep bash dash libtool gdbm gperf autoconf automake expat inetutils perl
	xz kmod gettext openssl ca-certificates curl elfutils libffi python3 coreutils diffutils gawk findutils groff less gzip iproute2 kbd libpipeline make patch man-db tar texinfo vim procps-ng
	util-linux e2fsprogs sysklogd sysvinit eudev scratchpkg sqlite pcre which pcre2 libarchive git dhcpcd rc base"

main() {
	case $1 in
		toolchain)
			for i in $pkgs; do
				toolsbuild $i
			done
			;;
		bootstrap)
			bootsrap_base
			;;
		chroot)
			runinchroot bash
			;;
	esac
}

main $@
