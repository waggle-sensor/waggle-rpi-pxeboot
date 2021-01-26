# determine full version
BASE_VERSION="$(cat 'version' | xargs).${BUILD_NUMBER:-local}"
GIT_SHA=$(git rev-parse --short HEAD)
DIRTY=$([[ -z $(git status -s) ]] || echo '-dirty')
VERSION=${BASE_VERSION}-${GIT_SHA}${DIRTY}

# get the list of all required debian packages to install in final image
REQ_PACKAGES=$(sed -e '/^#/d' required_deb_packages.txt | tr '\n' ' ')

docker build --build-arg REQ_PACKAGES="${REQ_PACKAGES}" -t pi_build .
docker run --rm --privileged \
-v `pwd`:/output/ -e VERSION=$VERSION pi_build ./release.sh 
