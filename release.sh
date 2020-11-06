#!/bin/bash -e

losetup -D
dmsetup remove_all
kpartx -a -v *.img
mkdir {bootmnt,rootmnt}
mount /dev/mapper/loop0p1 bootmnt/
mount /dev/mapper/loop0p2 rootmnt/

mkdir -p /tmp/reg

# Build the registration debian package
BASEDIR=/tmp/reg
NAME=sage-dns-nfs
ARCH=all

mkdir -p ${BASEDIR}/DEBIAN
cat > ${BASEDIR}/DEBIAN/control <<EOL
Package: ${NAME}
Version: ${VERSION}
Maintainer: sagecontinuum.org
Description: Start DHCP container that allows for PXE booting from RPI
Architecture: ${ARCH}
Priority: optional
Pre-Depends: nfs-kernel-server, dnsmasq
EOL

cp -p deb/install/postinst ${BASEDIR}/DEBIAN/
cp -p deb/install/prerm ${BASEDIR}/DEBIAN/

mkdir -p ${BASEDIR}/etc/sage-utils/dns/tftp
mkdir -p ${BASEDIR}/etc/sage-utils/dns/nfs

cp -pr bootmnt/* ${BASEDIR}/etc/sage-utils/dns/tftp/
cp -pr rootmnt/* ${BASEDIR}/etc/sage-utils/dns/nfs/
cp -pr ROOTFS/etc/sage-utils/dns/* ${BASEDIR}/etc/sage-utils/dns/

echo "${VERSION}" > ${BASEDIR}/etc/sage-utils/dns/version

dpkg-deb --root-owner-group --build ${BASEDIR} "${NAME}_${VERSION}_${ARCH}.deb"
mv *.deb /output/
