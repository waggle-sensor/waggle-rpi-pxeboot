# Waggle RPI PxEBoot

Creates Debian Package that set's up DHCP, NFS, and TFTP service on NX to allow for PXE booting a RPI4. Build's out RPI overlay rootfs and boot files inside package.

The produced Debian package is used by [wildnode-image](https://github.com/waggle-sensor/wildnode-image) to produce the Wild Waggle Node NX Build.

## Usage (how to build the rpi-pxeboot deb package)

To build a version of this debian package simply run the build.sh script:

```
./build.sh
```

In return, the script will return a versioned sage-rpi-pxeboot debian package.
For example: `sage-rpi-pxeboot_0.0.2.local-48b5c7d_all.deb`'

> Note: the resulting Debian package retains the 'sage' name to ensure backwards compatibility

## Installation

If you wanted to install this debian-package to allow for an rpi to pxe-boot off of your machine, simply use the dpkg -i option.

For example:

```
dpkg -i sage-rpi-pxeboot_0.0.2.local-48b5c7d_all.deb
```

Following the execution of this command, all services and files neccessary for pxe-booting will be on your machine.
To confirm, 

```
cat /etc/sage-utils/dhcp-pxe/version
```

This version should match the filename of the deb package installed (besides the _all.deb).

If you want to confirm your rpi is pxe-booting, you can observe this via:

```
tcpdump -vvv -i eth0
```

As a flurry of messages should pass containing the word .nfs, what's happening is that the rootfs is being served over to the rpi via nfs.


## References

- https://github.com/waggle-sensor/waggle-rpi-sd-flash - How to create and flash the RPi SD card image to enable net PxE booting
- https://blockdev.io/read-only-rpi/ - Note about this reference, it contains many unneccesary time-consuming steps but was very helpful nonetheless.
