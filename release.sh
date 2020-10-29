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

mkdir -p ${BASEDIR}/etc/sage-utils/dns/tftp
mkdir -p ${BASEDIR}/etc/sage-utils/dns/nfs

cp -p ROOTFS/etc/sage-utils/dns/* ${BASEDIR}/etc/sage-utils/dns/
cp -pr bootmnt/* ${BASEDIR}/etc/sage-utils/dns/tftp/
cp -pr rootmnt/* ${BASEDIR}/etc/sage-utils/dns/nfs/

#modify boot fs
echo "console=serial0,115200 console=tty1 root=/dev/nfs nfsroot=1.1.1.1:/etc/sage-utils/dns/nfs,vers=3 rw ip=dhcp rootwait elevator=deadline" > ${BASEDIR}/etc/sage-utils/dns/tftp/cmdline.txt

#modify rootfs
touch ${BASEDIR}/etc/sage-utils/dns/nfs/ssh
echo "proc       /proc        proc     defaults    0    0"   > ${BASEDIR}/etc/sage-utils/dns/nfs/etc/fstab
echo "1.1.1.1:/etc/sage-utils/dns/tftp /boot nfs defaults,vers=3 0 0" >> ${BASEDIR}/etc/sage-utils/dns/nfs/etc/fstab

dpkg-deb --root-owner-group --build ${BASEDIR} "${NAME}_${VERSION}_${ARCH}.deb"
mv *.deb /output/
