#! /bin/bash
#
# test.sh is provided for local testing, since we likely cannot connect to 
# priviledged daemon on circleci easily.
#
# USAGE: ./test.sh ubuntu:14.04
#
#
# Copyright (c) 2018 Vanessa Sochat, All Rights Reserved
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

testing_container="vanessa/salad"
testing_version=v$(cat VERSION)

if [ $# == 1 ] ; then
    testing_container="${1:-}"
fi

image="singularityware/singularity2docker:${testing_version}"

echo ""
echo "Testing Container:  ${testing_container}";
echo "singularity2docker: v${testing_version}";
echo ""

echo "Pulling ${testing_container}"; 
docker pull "${testing_container}";

################################################################################
# Test 1. Entrypoint functions
################################################################################

echo "1. Testing simple run of container to verify entrypoint is working."
echo "docker run ${image}"
docker run "${image}"
test "$?" -eq "0" && echo "PASS" || echo "FAIL"

################################################################################
# Test 2. Basic Build
################################################################################

echo "2. Testing docker2singularity build with ${testing_container}"
TMPDIR=$(mktemp -d)
echo "docker run -v /var/run/docker.sock:/var/run/docker.sock -v ${TMPDIR}:/output --privileged -t --rm ${image} ${testing_container}"
docker run -v /var/run/docker.sock:/var/run/docker.sock -v ${TMPDIR}:/output --privileged -t --rm ${image} "${testing_container}"
ls ${TMPDIR};
test "$?" -eq "0" && echo "PASS" || echo "FAIL"

################################################################################
# Test 3. Build with Name
################################################################################

echo "3. Testing docker2singularity build with custom name"
echo "docker run -v /var/run/docker.sock:/var/run/docker.sock -v ${TMPDIR}:/output --privileged -t --rm ${image} --name chimichanga.simg ${testing_container}"
docker run -v /var/run/docker.sock:/var/run/docker.sock -v ${TMPDIR}:/output --privileged -t --rm ${image} --name chimichanga.simg "${testing_container}"
ls ${TMPDIR};
test "$?" -eq "0" && echo "PASS" || echo "FAIL"

################################################################################
# Test 4. Testing that container runs!
################################################################################

echo "4. Testing that container runs!"
echo "singularity run --pwd /go/src/github.com/vsoch/salad $TMPDIR/chimichanga.simg fork"
singularity run --pwd /go/src/github.com/vsoch/salad $TMPDIR/chimichanga.simg fork
test "$?" -eq "0" && echo "PASS" || echo "FAIL"

echo "Cleaning up..."
rm -rf "${TMPDIR}"
