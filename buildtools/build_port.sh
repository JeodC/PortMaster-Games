#!/bin/bash

# Shared build driver for RHH-Ports buildtools/
# Usage: ./build_port.sh <portdir>
# where <portdir> is e.g. buildtools/ports/sonic/rsdkv4/rsdkv4

set -e

HOSTROOT=`pwd`
DOCKERROOT=/root
BUILDTOOLS=$HOSTROOT/buildtools

PORTDIR=$1
PORTNAME=`basename $PORTDIR`
SRCDIR=$PORTDIR/src
SETUPSCRIPT=$BUILDTOOLS/docker-setup.sh
PRODUCTSCRIPT=$SRCDIR/retrieve-products.txt
BUILDSCRIPT=$SRCDIR/build.txt

# Resolve the Dockerfile. Prefer the port's own src/Dockerfile; if absent, fall
# back to the nearest shared Dockerfile in an ancestor dir. This lets a port
# group (e.g. buildtools/ports/harbourmasters/) keep one shared Dockerfile instead of
# an identical copy per port. Groups with port-specific deps just keep their own
# src/Dockerfile and hit the fast path unchanged.
DOCKERFILE=$SRCDIR/Dockerfile
_d=$SRCDIR
while [ ! -f "$DOCKERFILE" ]; do
    _d=$(dirname "$_d")
    if [ "$_d" = "." ] || [ "$_d" = "/" ]; then
        break
    fi
    DOCKERFILE=$_d/Dockerfile
done
if [ ! -f "$DOCKERFILE" ]; then
    echo "ERROR: no Dockerfile found for $PORTDIR (looked in src/ and shared ancestor dirs)" >&2
    exit 1
fi

BUILDDIR=build-port
CONTAINER=$PORTNAME-build

if grep -q '^FROM rhh-base' "$DOCKERFILE"; then
    if ! docker image inspect rhh-base >/dev/null 2>&1; then
        echo "Building rhh-base image..."
        docker build --platform linux/aarch64 -t rhh-base -f $BUILDTOOLS/Dockerfile.base $BUILDTOOLS
    fi
fi

# Stop any prior container for this port, and clean the shared staging dir
# so a previous port in the same run can't leak its src/* or build outputs.
docker rm -f $CONTAINER 2>/dev/null || true
sudo rm -rf $HOSTROOT/$BUILDDIR
mkdir -p $HOSTROOT/$BUILDDIR
cd $HOSTROOT/$BUILDDIR
cp $HOSTROOT/$SRCDIR/* .
cp "$HOSTROOT/$DOCKERFILE" ./Dockerfile

bash $SETUPSCRIPT $CONTAINER

sleep 5

docker exec -e FORCE_HEAD=${FORCE_HEAD:-false} $CONTAINER /bin/bash -c "cd $BUILDDIR && bash $DOCKERROOT/$BUILDSCRIPT"

bash $HOSTROOT/$PRODUCTSCRIPT $HOSTROOT/$BUILDDIR $HOSTROOT/$PORTDIR

docker rm -f $CONTAINER >/dev/null 2>&1 || true
