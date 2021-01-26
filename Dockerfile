FROM arm64v8/ubuntu as deb_container

# Download all the required debian packages for inclusion in the ISO
ARG REQ_PACKAGES
RUN mkdir -p /isodebs/
RUN cd /isodebs/ && apt-get update && apt-get download -y $REQ_PACKAGES

FROM ubuntu:18.04

RUN apt-get update -y && apt-get install -y \
    kpartx \
    wget \
    zip  \
    xz-utils \
    rsync

RUN wget https://cdimage.ubuntu.com/releases/20.04.1/release/ubuntu-20.04.1-preinstalled-server-arm64+raspi.img.xz
RUN unxz *.xz

RUN mkdir -p /deb/ /ROOTFS/
ADD deb /deb/
ADD ROOTFS /ROOTFS/

COPY --from=deb_container /isodebs/* /ROOTFS/media/rpi/sage-utils/dhcp-pxe/nfs/isodebs/

COPY release.sh .
