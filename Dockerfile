FROM arm32v7/ubuntu:18.04 as deb_container

# Download all the required debian packages for inclusion in the ISO
ARG REQ_PACKAGES
RUN mkdir -p /isodebs/
RUN echo "deb [trusted=yes] http://raspbian.raspberrypi.org/raspbian/ buster main contrib non-free rpi" > /etc/apt/sources.list
RUN cd /isodebs/ && apt-get update && apt-get download -y $REQ_PACKAGES

FROM ubuntu:18.04

RUN apt-get update -y && apt-get install -y \
    kpartx \
    wget \
    zip

RUN wget -O raspbian_lite.zip https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2020-02-14/2020-02-13-raspbian-buster-lite.zip
RUN unzip raspbian_lite.zip

RUN mkdir -p /deb/ /ROOTFS/
ADD deb /deb/
ADD ROOTFS /ROOTFS/

COPY --from=deb_container /isodebs/* /ROOTFS/media/rpi/sage-utils/dhcp-pxe/nfs/isodebs/

COPY release.sh .
