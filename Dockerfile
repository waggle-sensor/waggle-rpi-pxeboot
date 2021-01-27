# define the container to get the qemu binaries
FROM amd64/ubuntu:bionic-20200921 as qemu_src
# download the qemu static binaries
RUN apt-get update && apt-get install --no-install-recommends -y qemu-user-static

FROM arm64v8/ubuntu:focal-20210119 as deb_container
# add support for transparent cross architecture builds
COPY --from=qemu_src /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static
# Download all the required debian packages for inclusion in the ISO
ARG REQ_PACKAGES
RUN mkdir -p /isodebs/
RUN cd /isodebs/ && apt-get update && apt-get download -y $REQ_PACKAGES

FROM ubuntu:18.04

RUN apt-get update -y && apt-get install -y \
    kpartx \
    wget \
    zip  \
    xz-utils

RUN wget https://cdimage.ubuntu.com/releases/20.04.1/release/ubuntu-20.04.1-preinstalled-server-arm64+raspi.img.xz
RUN unxz *.xz

RUN mkdir -p /deb/ /ROOTFS/
ADD deb /deb/
ADD ROOTFS /ROOTFS/

COPY --from=deb_container /isodebs/* /ROOTFS/media/rpi/sage-utils/dhcp-pxe/nfs/isodebs/

COPY release.sh .
