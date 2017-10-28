#! /bin/bash
#
# docker2singularity.sh will convert a docker image into a singularity
# Must be run with sudo to use docker commands (eg aufs)
#
# NOTES:
# If the docker image uses both ENTRYPOINT and CMD the latter will be ignored
#
# KNOWN ISSUES:
# Currently ENTRYPOINTs and CMDs with commas in the arguments are not supported
#
# USAGE: docker2singularity.sh ubuntu:14.04
#
#
# Copyright (c) 2016-2017 Vanessa Sochat, All Rights Reserved
# Copyright (c) 2017 Singularityware LLC and AUTHORS
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -o errexit
set -o nounset

USAGE="USAGE: docker2singularity [-m \"/mount_point1 /mount_point2\"] [options] docker_image_name"

# --- Option processing --------------------------------------------
if [ $# == 0 ] ; then
    echo $USAGE
    echo "OPTIONS:

          Image Format
              -f: build development sandbox (folder)
              -w: non-production writable image (ext3)         

              Default is squashfs (recommended)
              "

    exit 1;
fi

mount_points="/oasis /projects /scratch /local-scratch /work /home1 /corral-repl /corral-tacc /beegfs /share/PI /extra /data /oak"
image_format="squashfs"
while getopts ':hm:wf' option; do
  case "$option" in
    h) echo "$USAGE"
       exit 0
       ;;
    m) mount_points=$OPTARG
       ;;
    f) image_format="sandbox"
       ;;
    w) image_format="writable"
       ;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))

image=$1

echo ""
echo "Image Format: ${image_format}"

################################################################################
### CONTAINER RUNNING ID #######################################################
################################################################################

runningid=`docker run -d $image tail -f /dev/null`

# Full id looks like
# sha256:d59bdb51bb5c4fb7b2c8d90ae445e0720c169c553bcf553f67cb9dd208a4ec15

# Take the first 12 characters to get id of container
container_id=`echo ${runningid} | cut -c1-12`

# Network address, if needed
network_address=`docker inspect --format="{{.NetworkSettings.IPAddress}}" $container_id`


################################################################################
### IMAGE NAME #################################################################
################################################################################

image_name=`docker inspect --format="{{.Config.Image}}" $container_id`

# using bash substitution
# removing special chars [perhaps echo + sed would be better for other chars]
image_name=${image_name//\//_}
image_name=${image_name/:/_}

# following is the date of the container, not the docker image.
#creation_date=`docker inspect --format="{{.Created}}" $container_id`
creation_date=`docker inspect --format="{{.Created}}" $image`


################################################################################
### IMAGE SIZE #################################################################
################################################################################

size=`docker inspect --format="{{.Size}}" $image`
# convert size in MB
size=`echo $(($size/1000000+1))`
echo "Inspected Size: $size MB"
echo ""

################################################################################
### IMAGE CREATION #############################################################
################################################################################
TMPDIR=$(mktemp -u -d)
mkdir -p $TMPDIR

creation_date=`echo ${creation_date} | cut -c1-10`
new_container_name=/tmp/$image_name-$creation_date-$container_id
build_sandbox="${new_container_name}.build"
echo "(1/9) Creating a build sandbox..."
mkdir -p ${build_sandbox}
echo "(2/9) Exporting filesystem..."
docker export $container_id >> $build_sandbox.tar
singularity image.import $build_sandbox < $build_sandbox.tar
docker inspect $container_id >> $build_sandbox/singularity.json


################################################################################
### METADATA ###################################################################
################################################################################

# For docker2singularity, installation is at /usr/local
zcat /usr/local/libexec/singularity/bootstrap-scripts/environment.tar | ( cd $build_sandbox; tar -xf - >/dev/null)

################################################################################
### SINGULARITY RUN SCRIPT #####################################################
################################################################################
echo "(3/9) Adding run script..."
CMD=$(docker inspect --format='{{json .Config.Cmd}}' $image)
if [[ $CMD != [* ]]; then
    if [[ $CMD != "null" ]]; then
        CMD="/bin/sh -c "$CMD
    fi
fi
# Remove quotes, commas, and braces
CMD=`echo "${CMD//\"/}" | sed 's/\[//g' | sed 's/\]//g' | sed 's/,//g'`

ENTRYPOINT=$(docker inspect --format='{{json .Config.Entrypoint}}' $image)
if [[ $ENTRYPOINT != [* ]]; then
    if [[ $ENTRYPOINT != "null" ]]; then
        ENTRYPOINT="/bin/sh -c "$ENTRYPOINT
    fi
fi

# Remove quotes, commas, and braces
ENTRYPOINT=`echo "${ENTRYPOINT//\"/}" | sed 's/\[//g' | sed 's/\]//g' | sed 's/,/ /g'`

echo '#!/bin/sh' > $build_sandbox/.singularity.d/runscript
if [[ $ENTRYPOINT != "null" ]]; then
    echo $ENTRYPOINT '$@' >> $build_sandbox/.singularity.d/runscript;
else
    if [[ $CMD != "null" ]]; then
        echo $CMD '$@' >> $build_sandbox/.singularity.d/runscript;
    fi
fi

chmod +x $build_sandbox/.singularity.d/runscript;


################################################################################
### SINGULARITY ENVIRONMENT ####################################################
################################################################################
echo "(4/9) Setting ENV variables..."
docker run --rm --entrypoint="/usr/bin/env" $image > $TMPDIR/docker_environment
# do not include HOME and HOSTNAME - they mess with local config
sed -i '/^HOME/d' $TMPDIR/docker_environment
sed -i '/^HOSTNAME/d' $TMPDIR/docker_environment
sed -i 's/^/export /' $TMPDIR/docker_environment
# add quotes around the variable names
sed -i 's/=/="/' $TMPDIR/docker_environment
sed -i 's/$/"/' $TMPDIR/docker_environment
cp $TMPDIR/docker_environment $build_sandbox/.singularity.d/env/10-docker.sh
chmod +x $build_sandbox/.singularity.d/env/10-docker.sh;
rm -rf $TMPDIR


################################################################################
### Permissions ################################################################
################################################################################
if [ "${mount_points}" ] ; then
    echo "(5/9) Adding mount points..."
    mkdir -p "${build_sandbox}/${mount_points}"
else
    echo "(5/9) Skipping mount points..."
fi 

# making sure that any user can read and execute everything in the container
echo "(6/9) Fixing permissions..."

find ${build_sandbox}/* -maxdepth 0 -not -path '${build_sandbox}/dev*' -not -path '${build_sandbox}/proc*' -not -path '${build_sandbox}/sys*' -exec chmod a+r -R '{}' \;
find ${build_sandbox}/* -type f -or -type d -perm -u+x,o-x -not -path '${build_sandbox}/dev*' -not -path '${build_sandbox}/proc*' -not -path '${build_sandbox}/sys*' -exec chmod a+x '{}' \;

echo "(7/9) Stopping and removing the container..."
docker stop $container_id >> /dev/null
docker rm $container_id >> /dev/null

# Build a final image from the sandbox
echo "(8/9) Building ${image_format} container..."
if [ "$image_format" == "squashfs" ]; then
    new_container_name=${new_container_name}.simg
    singularity build ${new_container_name} $build_sandbox
elif [ "$image_format" == "writable" ]; then
    new_container_name=${new_container_name}.img    
    singularity build --writable ${new_container_name} $build_sandbox
else
    mv $build_sandbox $new_container_name
fi

echo "(9/9) Moving the image to the output folder..."
finalsize=`du -shm $new_container_name | cut -f1`
rsync --info=progress2 -a $new_container_name /output/
echo "Final Size: ${finalsize}MB"
