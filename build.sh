#!/bin/bash -e
# Build Docker Container -> Run It -> 

# determine full version
BASE_VERSION="$(cat 'version' | xargs).${BUILD_NUMBER:-local}"
GIT_SHA=$(git rev-parse --short HEAD)
DIRTY=$([[ -z $(git status -s) ]] || echo '-dirty')
VERSION=${BASE_VERSION}-${GIT_SHA}${DIRTY}

docker build -t pi_build .
docker run --rm --privileged \
-v `pwd`:/output/ -e VERSION=$VERSION pi_build ./release.sh  
