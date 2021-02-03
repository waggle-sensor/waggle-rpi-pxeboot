#!/bin/bash -e

function cleanup()
{
   echo "Checking if loopback device needs cleanup."
   if [ -z "$NEWDEVICE" ]; then
        echo "Manual cleanup of loopback devices neccessary."
	return -1
   fi

   echo "NEWDEVICE set @ $NEWDEVICE. Proceeding with cleanup!"
   #free loopback devices
   losetup -d $NEWDEVICE

   umount bootmnt/
   umount rootmnt/

   loopDev1=$(echo $(basename ${NEWDEVICE})p1)
   loopDev2=$(echo $(basename ${NEWDEVICE})p2)
   dmsetup remove $loopDev1
   dmsetup remove $loopDev2
   echo "Cleanup complete!"
}

trap cleanup EXIT SIGINT

echo "Mounting RPI Filesystem"
#determine currently used loopback devices
losetup --output NAME -n > loopbackdevs

kpartx -a -v *.img
mkdir {bootmnt,rootmnt}

#determine which loopback device we just created
losetup --output NAME -n > loopbackdevsAFTER
NEWDEVICE=$(grep -v -F -x -f loopbackdevs loopbackdevsAFTER)

#deterine paths to mount boot and root from (NEWDEVICE includes /dev/ path to device which is why we progress 5 characters)
bootloc=$(echo /dev/mapper/$(basename ${NEWDEVICE})p1)
rootloc=$(echo /dev/mapper/$(basename ${NEWDEVICE})p2)

mount $bootloc bootmnt/
mount $rootloc rootmnt/

mkdir -p /tmp/reg

# Build the pxe-boot debian package
BASEDIR=/tmp/reg
NAME=sage-rpi-pxeboot
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

echo "Copying Over RPI Filesystem and DHCP/NFS config files"
cp -p deb/install/postinst ${BASEDIR}/DEBIAN/
cp -p deb/install/prerm ${BASEDIR}/DEBIAN/

mkdir -p ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe/tftp/
mkdir -p ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe/nfs/

rsync -axHAWX --numeric-ids --verbose bootmnt/ ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe/tftp
rsync -axHAWX --numeric-ids --verbose rootmnt/ ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe/nfs
cp -pr ROOTFS/media/rpi/sage-utils/dhcp-pxe/* ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe
zcat ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe/tftp/vmlinuz > ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe/tftp/vmlinux

wget https://github.com/rancher/k3s/releases/download/v1.20.0+k3s2/k3s-arm64
chmod +x k3s-arm64
mv k3s-arm64 ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe/nfs/usr/local/bin/k3s

echo "${VERSION}" > ${BASEDIR}/media/rpi/sage-utils/dhcp-pxe/version
echo "Done Copying RPI Filesystem and DHCP/NFS config files"

pushd ${BASEDIR}
find * -type f -not -path 'DEBIAN/*' -exec md5sum {} \; > DEBIAN/md5sums
popd

dpkg-deb --root-owner-group --build ${BASEDIR} "${NAME}_${VERSION}_${ARCH}.deb"
mv *.deb /output/
