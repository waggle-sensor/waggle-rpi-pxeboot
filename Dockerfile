# define the container to get the qemu binaries
FROM amd64/ubuntu:focal as qemu_src
# download the qemu static binaries
RUN apt-get update && apt-get install --no-install-recommends -y qemu-user-static

FROM arm64v8/ubuntu:focal-20210119 as deb_container
# add support for transparent cross architecture builds
COPY --from=qemu_src /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

RUN apt-get update -y && apt-get install -y \
    device-tree-compiler

# Download all the required debian packages for inclusion in the ISO
ARG REQ_PACKAGES
RUN mkdir -p /isodebs/
RUN cd /isodebs/ && apt-get update && apt-get download -y $REQ_PACKAGES

ADD build /build/
RUN cd /build/ && dtc -O dtb -o bme680-overlay.dtbo -b 0 -@ bme680-overlay.dts

FROM ubuntu:18.04

RUN apt-get update -y && apt-get install -y \
    git \
    kpartx \
    wget \
    zip  \
    xz-utils \
    rsync

# core OS files
RUN wget https://old-releases.ubuntu.com/releases/20.04.2/ubuntu-20.04.2-preinstalled-server-arm64+raspi.img.xz
RUN unxz --test *.xz
RUN unxz --verbose *.xz

# more up-to-date bootloader files - used for bootloader firmware files only
# lets do this instead and pull in the files we want https://github.com/raspberrypi/firmware/releases/tag/1.20230106
ENV FW_REPO=https://github.com/raspberrypi/firmware
ENV FW_VERSION=1.20230106
RUN git clone --depth 1 ${FW_REPO} -b ${FW_VERSION} /rpi_fw ; \
    cd /rpi_fw ; \
    rm -rf .git

RUN mkdir -p /deb/ /ROOTFS/
ADD deb /deb/
ADD ROOTFS /ROOTFS/

COPY --from=deb_container /isodebs/* /ROOTFS/media/rpi/sage-utils/dhcp-pxe/nfs/isodebs/
COPY --from=deb_container /build/bme680-overlay.dtbo /ROOTFS/media/rpi/sage-utils/dhcp-pxe/tftp/overlays/

COPY release.sh /release.sh
ENTRYPOINT [ "/release.sh" ]
