FROM arm32v7/ubuntu

RUN apt-get update -y && apt-get install -y \
    kpartx \
    wget \
    zip

RUN wget --no-check-certificate -O raspbian_lite.zip https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2020-02-14/2020-02-13-raspbian-buster-lite.zip
RUN unzip raspbian_lite.zip

RUN mkdir -p /deb/ /ROOTFS/
ADD deb /deb/
ADD ROOTFS /ROOTFS/

# Download all the required debian packages for inclusion in the ISO
ARG REQ_PACKAGES
RUN mkdir -p /ROOTFS/media/rpi/sage-utils/dhcp-pxe/nfs/isodebs/
RUN echo "deb [trusted=yes] http://raspbian.raspberrypi.org/raspbian/ buster main contrib non-free rpi" > /etc/apt/sources.list
RUN cd /ROOTFS/media/rpi/sage-utils/dhcp-pxe/nfs/isodebs/ && apt-get update && apt-get download -y $REQ_PACKAGES

COPY release.sh .
