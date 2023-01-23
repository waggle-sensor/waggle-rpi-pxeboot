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

   rm -rf bootmnt
   rm -rf rootmnt
   echo "Cleanup complete!"
}
trap cleanup EXIT SIGINT

function create_deb()
{
   local inpath=$1
   local debname=$2
   local outpath=$3
   echo "Create Debian package [${debname}] from '${inpath}' and move to '${outpath}'"

   pushd ${inpath}
   find * -type f -not -path 'DEBIAN/*' -exec md5sum {} \; > DEBIAN/md5sums
   popd

   dpkg-deb --root-owner-group --build ${inpath} "${debname}"
   mkdir -p ${outpath}
   mv *.deb ${outpath}
}


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

# Build the pxe-boot debian package
BASEDIR=/tmp/base
# note: leaving 'sage' in Debian package name to ensure backward compatibility
NAME=sage-rpi-pxeboot
ARCH=all
MAINTAINER=waggle-edge.ai
MEDIA_RPI_PATH=/media/rpi/sage-utils/dhcp-pxe
DEB_OUT=/repo/output/

mkdir -p ${BASEDIR}

echo "Load base RPI filesystem"
mkdir -p ${BASEDIR}/${MEDIA_RPI_PATH}/tftp/
mkdir -p ${BASEDIR}/${MEDIA_RPI_PATH}/nfs/

rsync -axHAWX --numeric-ids --verbose bootmnt/ ${BASEDIR}/${MEDIA_RPI_PATH}/tftp
rsync -axHAWX --numeric-ids --verbose rootmnt/ ${BASEDIR}/${MEDIA_RPI_PATH}/nfs

echo "Update bootloader files"
rsync -av /rpi_fw/boot/bootcode.bin ${BASEDIR}/${MEDIA_RPI_PATH}/tftp
rsync -av /rpi_fw/boot/fixup*dat ${BASEDIR}/${MEDIA_RPI_PATH}/tftp
rsync -av /rpi_fw/boot/start*elf ${BASEDIR}/${MEDIA_RPI_PATH}/tftp

echo "Make custom changes to the RPI filesystem (i.e. DHCP/NFS config files)"
# remove the etc/resolv.conf symlink to be replaced by our custom file
rm ${BASEDIR}/${MEDIA_RPI_PATH}/nfs/etc/resolv.conf
# remove the rsyslog configuration, as we are not using rsyslog
rm ${BASEDIR}/${MEDIA_RPI_PATH}/nfs/etc/rsyslog.d/*

cp -pr ROOTFS/* ${BASEDIR}/
zcat ${BASEDIR}/${MEDIA_RPI_PATH}/tftp/vmlinuz > ${BASEDIR}/${MEDIA_RPI_PATH}/tftp/vmlinux

chmod 755 ${BASEDIR}/${MEDIA_RPI_PATH}/tftp/overlays/bme680-overlay.dtbo
chmod 600 ${BASEDIR}/${MEDIA_RPI_PATH}/nfs/etc/ssh/ssh_host_ecdsa_key

chmod 644 ${BASEDIR}/${MEDIA_RPI_PATH}/nfs/etc/waggle/docker/certs/domain.crt

wget https://github.com/rancher/k3s/releases/download/v1.20.2+k3s1/k3s-arm64
chmod +x k3s-arm64
mv k3s-arm64 ${BASEDIR}/${MEDIA_RPI_PATH}/nfs/usr/local/bin/k3s

echo "${VERSION_LONG}" > ${BASEDIR}/${MEDIA_RPI_PATH}/version

# Break-up the debian package into smaller pieces to ease installation in a Docker environment
BASEDIR_TMP=/tmp/split

########################################################################
## Boot PxE
echo "Creating 'Boot' Debian package..."
SPLIT_DEB_BOOT=${NAME}-boot
mkdir -p ${BASEDIR_TMP}

# copy all files in /etc
rsync -axHAWX --numeric-ids --verbose ${BASEDIR}/etc ${BASEDIR_TMP}
# copy over the tftp boot files
rsync -axHAWX --numeric-ids --verbose --relative ${BASEDIR}/./${MEDIA_RPI_PATH}/tftp ${BASEDIR_TMP}

mkdir -p ${BASEDIR_TMP}/DEBIAN
cat > ${BASEDIR_TMP}/DEBIAN/control <<EOL
Package: ${SPLIT_DEB_BOOT}
Version: ${VERSION_LONG}
Maintainer: ${MAINTAINER}
Description: RPi 'boot' sub-package: adds support to PxE boot the RPi OS
Architecture: ${ARCH}
Priority: optional
Pre-Depends: dnsmasq, nfs-kernel-server
Replaces: ${NAME} (<< 2.2.0)
Breaks: ${NAME} (<< 2.2.0)
EOL

create_deb ${BASEDIR_TMP} "${SPLIT_DEB_BOOT}_${VERSION_SHORT}_${ARCH}.deb" ${DEB_OUT}

rm -rf ${BASEDIR_TMP}
echo "Creating 'Boot' Debian package... Done"

########################################################################
## OS - /usr/lib/firmware
echo "Creating 'OS - /usr/lib/firmware' Debian package..."
SPLIT_DEB_USRLIBFW=${NAME}-os-usrlibfw
mkdir -p ${BASEDIR_TMP}

# copy over the OS /usr/lib/firmware files
rsync -axHAWX --numeric-ids --verbose --relative ${BASEDIR}/./${MEDIA_RPI_PATH}/nfs/usr/lib/firmware ${BASEDIR_TMP}

mkdir -p ${BASEDIR_TMP}/DEBIAN
cat > ${BASEDIR_TMP}/DEBIAN/control <<EOL
Package: ${SPLIT_DEB_USRLIBFW}
Version: ${VERSION_LONG}
Maintainer: ${MAINTAINER}
Description: RPi 'os - /usr/lib/firmware' sub-package: contains the large /usr/lib/firmware OS files
Architecture: ${ARCH}
Priority: optional
Replaces: ${NAME} (<< 2.2.0)
Breaks: ${NAME} (<< 2.2.0)
EOL

create_deb ${BASEDIR_TMP} "${SPLIT_DEB_USRLIBFW}_${VERSION_SHORT}_${ARCH}.deb" ${DEB_OUT}

rm -rf ${BASEDIR_TMP}
echo "Creating 'OS - /usr/lib/firmware' Debian package... Done"

########################################################################
## OS - /usr/lib - other
echo "Creating 'OS - /usr/lib - other' Debian package..."
SPLIT_DEB_USRLIB=${NAME}-os-usrlib
mkdir -p ${BASEDIR_TMP}

# copy over the OS /usr/lib - other files
rsync -axHAWX --numeric-ids --verbose --exclude="${MEDIA_RPI_PATH}/nfs/usr/lib/firmware" --relative ${BASEDIR}/./${MEDIA_RPI_PATH}/nfs/usr/lib ${BASEDIR_TMP}

mkdir -p ${BASEDIR_TMP}/DEBIAN
cat > ${BASEDIR_TMP}/DEBIAN/control <<EOL
Package: ${SPLIT_DEB_USRLIB}
Version: ${VERSION_LONG}
Maintainer: ${MAINTAINER}
Description: RPi 'os - /usr/lib' sub-package: contains the large /usr/lib OS files (excluding /usr/lib/firmware)
Architecture: ${ARCH}
Priority: optional
Replaces: ${NAME} (<< 2.2.0)
Breaks: ${NAME} (<< 2.2.0)
EOL

create_deb ${BASEDIR_TMP} "${SPLIT_DEB_USRLIB}_${VERSION_SHORT}_${ARCH}.deb" ${DEB_OUT}

rm -rf ${BASEDIR_TMP}
echo "Creating 'OS - /usr/lib - other' Debian package... Done"

########################################################################
## OS - Other (everything else)
echo "Creating 'OS - Other' Debian package..."
SPLIT_DEB_OTHER=${NAME}-os-other
mkdir -p ${BASEDIR_TMP}

# copy over all remaining OS files (exclude /usr/lib)
rsync -axHAWX --numeric-ids --verbose --exclude="${MEDIA_RPI_PATH}/nfs/usr/lib" --relative ${BASEDIR}/./${MEDIA_RPI_PATH}/nfs ${BASEDIR_TMP}

mkdir -p ${BASEDIR_TMP}/DEBIAN
cat > ${BASEDIR_TMP}/DEBIAN/control <<EOL
Package: ${SPLIT_DEB_OTHER}
Version: ${VERSION_LONG}
Maintainer: ${MAINTAINER}
Description: RPi 'os - other' sub-package: contains the remaining OS files (excluding: /usr/lib)
Architecture: ${ARCH}
Priority: optional
Replaces: ${NAME} (<< 2.2.0)
Breaks: ${NAME} (<< 2.2.0)
EOL

create_deb ${BASEDIR_TMP} "${SPLIT_DEB_OTHER}_${VERSION_SHORT}_${ARCH}.deb" ${DEB_OUT}

rm -rf ${BASEDIR_TMP}
echo "Creating 'OS - Other' Debian package... Done"

########################################################################
## Meta package
echo "Creating 'Meta' Debian package..."
SPLIT_DEB_NAME=${NAME}
mkdir -p ${BASEDIR_TMP}

# copy only files (no folders) from root MEDIA_RPI_PATH
rsync -axHAWX --numeric-ids --verbose --exclude="${MEDIA_RPI_PATH}/*/" --relative ${BASEDIR}/./${MEDIA_RPI_PATH}/ ${BASEDIR_TMP}

mkdir -p ${BASEDIR_TMP}/DEBIAN
cat > ${BASEDIR_TMP}/DEBIAN/control <<EOL
Package: ${NAME}
Version: ${VERSION_LONG}
Maintainer: ${MAINTAINER}
Description: RPi Meta package: includes references to all sub-packages needed to support RPi PxE Booting using an NFS file system.
Architecture: ${ARCH}
Priority: optional
Depends: ${SPLIT_DEB_BOOT}, ${SPLIT_DEB_USRLIBFW}, ${SPLIT_DEB_USRLIB}, ${SPLIT_DEB_OTHER}
EOL

cp -p deb/install/postinst ${BASEDIR_TMP}/DEBIAN/
cp -p deb/install/prerm ${BASEDIR_TMP}/DEBIAN/

create_deb ${BASEDIR_TMP} "${SPLIT_DEB_NAME}_${VERSION_SHORT}_${ARCH}.deb" ${DEB_OUT}

rm -rf ${BASEDIR_TMP}
echo "Creating 'Meta' Debian package... Done"
