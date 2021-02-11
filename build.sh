#!/bin/bash -e

print_help() {
  echo """
usage: build.sh [-f]
Create the versioned Debian package.
 -f : force the build to proceed (debugging only) without checking for tagged commit
"""
}

FORCE=
while getopts "f?" opt; do
  case $opt in
    f) # force build
      echo "** Force build: ignore tag depth check **"
      FORCE=1
      ;;
    ?|*)
      print_help
      exit 1
      ;;
  esac
done

# determine full version
VERSION_SHORT=$(git describe --tags --dirty | cut -c2-)
VERSION_LONG=$(git describe --tags --long --dirty | cut -c2-)

TAG_DEPTH=$(echo ${VERSION_LONG} | cut -d '-' -f 2)
if [[ -z "${FORCE}" && "${TAG_DEPTH}_" != "0_" ]]; then
  echo "Error:"
  echo "  The current git commit has not been tagged. Please create a new tag first to ensure a proper unique version number."
  echo "  Use -f to ignore error (for debugging only)."
  exit 1
fi

# get the list of all required debian packages to install in final image
REQ_PACKAGES=$(sed -e '/^#/d' required_deb_packages.txt | tr '\n' ' ')

docker build --build-arg REQ_PACKAGES="${REQ_PACKAGES}" -t pi_build .
docker run --rm --privileged \
-v `pwd`:/output/ -e VERSION_SHORT=$VERSION_SHORT -e VERSION_LONG=$VERSION_LONG pi_build ./release.sh 
