#!/bin/bash -e

get_version_short() {
  git describe --tags --dirty 2>/dev/null || echo "v0.0.0"
}

get_version_long() {
  sha=$(git rev-parse --short HEAD)
  if [ -n "${sha}" ]; then
    sha="-${sha}"
  fi
  git describe --tags --long --dirty 2>/dev/null || echo "v0.0.0${sha}"
}

trim_version_prefix() {
  sed -e 's/^v//'
}

# determine version
VERSION_SHORT=$(get_version_short | trim_version_prefix)
echo "VERSION_SHORT: ${VERSION_SHORT}"
VERSION_LONG=$(get_version_long | trim_version_prefix)
echo "VERSION_LONG: ${VERSION_LONG}"

# get the list of all required debian packages to install in final image
REQ_PACKAGES=$(sed -e '/^#/d' required_deb_packages.txt | tr '\n' ' ')

docker build --build-arg REQ_PACKAGES="${REQ_PACKAGES}" -t pi_build .
docker run --rm --privileged \
-v "$PWD:/repo" -e VERSION_SHORT=$VERSION_SHORT -e VERSION_LONG=$VERSION_LONG pi_build
