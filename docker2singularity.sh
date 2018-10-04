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
# Copyright (c) 2016-2018 Vanessa Sochat, All Rights Reserved
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

function usage() {

    echo "USAGE: docker2singularity [-m \"/mount_point1 /mount_point2\"] [options] docker_image_name"
    echo ""
    echo "OPTIONS:

          Image Format
              --folder   -f   build development sandbox (folder)
              --writable -w   non-production writable image (ext3)         
                              Default is squashfs (recommended)
              --name     -n   provide basename for the container (default based on URI)
              --mount    -m   provide list of custom mount points (in quotes!)
              --help     -h   show this help and exit
              "
}

# --- Option processing --------------------------------------------
if [ $# == 0 ] ; then
    usage
    exit 0;
fi

mount_points="/oasis /projects /scratch /local-scratch /work /home1 /corral-repl /corral-tacc /beegfs /share/PI /extra /data /oak"
image_format="squashfs"
new_container_name=""

while true; do
    case ${1:-} in
        -h|--help|help)
            usage
            exit 0
        ;;
        -n|--name)
            shift
            new_container_name="${1:-}"
            shift
        ;;
        -m|--mount)
            shift
            mount_points="${1:-}"
            shift
        ;;
        -f|--folder)
            shift
            image_format="sandbox"
            shift
        ;;
        -w|--wrtiable)
            shift
            image_format="writable"
            shift
        ;;
        :) printf "missing argument for -%s\n" "$option" >&2
           usage
           exit 1
        ;;
        \?) printf "illegal option: -%s\n" "$option" >&2
            usage
            exit 1
        ;;
        -*)
            printf "illegal option: -%s\n" "$option" >&2
            usage
            exit 1
        ;;
        *)
            break;
        ;;
    esac
done

image=$1

echo ""
echo "Image Format: ${image_format}"
echo "Docker Image: ${image}"

if [ "${new_container_name}" != "" ]; then
    echo "Container Name: ${new_container_name}"
fi

echo ""

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

# The user has not provided a custom name
if [ "${new_container_name}" == "" ]; then
    new_container_name=/tmp/$image_name-$creation_date-$container_id

# The user has provided a custom name
else
    new_container_name=/tmp/$(basename $new_container_name)
    new_container_name="${new_container_name%.*}"
fi


build_sandbox="${new_container_name}.build"


echo "(1/10) Creating a build sandbox..."
mkdir -p ${build_sandbox}
echo "(2/10) Exporting filesystem..."
docker export $container_id >> $build_sandbox.tar
singularity image.import $build_sandbox < $build_sandbox.tar
docker inspect $container_id >> $build_sandbox/singularity.json


################################################################################
### METADATA ###################################################################
################################################################################

# Quiet Singularity debug output when adding labels
SINGULARITY_MESSAGELEVEL=0
export SINGULARITY_MESSAGELEVEL

# For docker2singularity, installation is at /usr/local
echo "(3/10) Creating labels..."
libexec="/usr/local/libexec/singularity"
zcat "${libexec}/bootstrap-scripts/environment.tar" | ( cd $build_sandbox; tar -xf - >/dev/null)
LABELS=$(docker inspect --format='{{json .Config.Labels}}' $image)
LABELFILE=$(printf "%q" "$build_sandbox/.singularity.d/labels.json")
ADD_LABEL="${libexec}/python/helpers/json/add.py -f --file ${LABELFILE}"

# Labels could be null
if [ "${LABELS}" == "null" ]; then
    LABELS="{}"
fi

# Extract some other "nice to know" metadata from docker
SINGULARITY_version=`singularity --version`
SINGULARITY_VERSION=$(printf "%q" "$SINGULARITY_version")
DOCKER_VERSION=$(docker inspect --format='{{json .DockerVersion}}' $image)
DOCKER_ID=$(docker inspect --format='{{json .Id}}' $image)

# Add labels from Docker, then relevant to Singularity build
echo $LABELS > $LABELFILE;
eval $ADD_LABEL --key "org.label-schema.schema-version" --value "1.0"
eval $ADD_LABEL --key "org.label-schema.singularity.build-type" --value "docker2singularity" 
eval $ADD_LABEL --key "org.label-schema.singularity.build" --value "${image_format}" 
eval $ADD_LABEL --key "org.label-schema.build-date" --value $(date +%Y-%m-%d-%H:%M:%S)
eval $ADD_LABEL --key "org.label-schema.singularity.version" --value "${SINGULARITY_VERSION}"
eval $ADD_LABEL --key "org.label-schema.docker.version" --value "${DOCKER_VERSION}"
eval $ADD_LABEL --key "org.label-schema.docker.Created" --value "${creation_date}"
eval $ADD_LABEL --key "org.label-schema.docker.Id" --value "${DOCKER_ID}"

unset SINGULARITY_MESSAGELEVEL

################################################################################
### SINGULARITY RUN SCRIPT #####################################################
################################################################################
echo "(4/10) Adding run script..."
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

echo "(5/10) Setting ENV variables..."
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
    echo "(6/10) Adding mount points..."
    mkdir -p "${build_sandbox}/${mount_points}"
else
    echo "(6/10) Skipping mount points..."
fi 

# making sure that any user can read and execute everything in the container
echo "(7/10) Fixing permissions..."

find ${build_sandbox}/* -maxdepth 0 -not -path '${build_sandbox}/dev*' -not -path '${build_sandbox}/proc*' -not -path '${build_sandbox}/sys*' -exec chmod a+r -R '{}' \;
find ${build_sandbox}/* -type f -or -type d -perm -u+x,o-x -not -path '${build_sandbox}/dev*' -not -path '${build_sandbox}/proc*' -not -path '${build_sandbox}/sys*' -exec chmod a+x '{}' \;

echo "(8/10) Stopping and removing the container..."
docker stop $container_id >> /dev/null
docker rm $container_id >> /dev/null

# Build a final image from the sandbox
echo "(9/10) Building ${image_format} container..."
if [ "$image_format" == "squashfs" ]; then
    new_container_name=${new_container_name}.simg
    singularity build ${new_container_name} $build_sandbox
elif [ "$image_format" == "writable" ]; then
    new_container_name=${new_container_name}.img    
    singularity build --writable ${new_container_name} $build_sandbox
else
    mv $build_sandbox $new_container_name
fi

echo "(10/10) Moving the image to the output folder..."
finalsize=`du -shm $new_container_name | cut -f1`
rsync --info=progress2 -a $new_container_name /output/
echo "Final Size: ${finalsize}MB"
