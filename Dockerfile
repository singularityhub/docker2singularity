FROM golang:1.18.10-alpine as base

################################################################################
#
# Copyright (C) 2019-2023 Vanessa Sochat.
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
################################################################################

FROM docker:18.09.8 as builder
COPY --from=base /go /go
COPY --from=base /usr/local/go /usr/local/go
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
ENV GOLANG_VERSION 1.18.10

RUN apk update && \
    apk add --virtual automake build-base linux-headers libffi-dev
RUN apk add --no-cache bash git openssh gcc squashfs-tools sudo libtool gawk ca-certificates libseccomp libseccomp-dev
RUN apk add --no-cache linux-headers build-base openssl-dev util-linux util-linux-dev python rsync cryptsetup glib-dev

ENV SINGULARITY_VERSION 3.11.0
RUN mkdir -p /usr/local/var/singularity/mnt && \
    mkdir -p $GOPATH/src/github.com/sylabs && \
    cd $GOPATH/src/github.com/sylabs && \
    wget -qO- https://github.com/sylabs/singularity/releases/download/v${SINGULARITY_VERSION}/singularity-ce-${SINGULARITY_VERSION}.tar.gz | \
    tar xzv && \
    cd singularity-ce-${SINGULARITY_VERSION} && \
    ./mconfig -p /usr/local/singularity && \
    make -C builddir && \
    make -C builddir install

# See https://docs.docker.com/develop/develop-images/multistage-build/
# for more information on multi-stage builds.

FROM docker:18.09.8
LABEL Maintainer @vsoch
COPY --from=builder /usr/local/singularity /usr/local/singularity
RUN apk add --no-cache ca-certificates libseccomp squashfs-tools bash python rsync
ENV PATH="/usr/local/singularity/bin:$PATH"

ADD docker2singularity.sh /docker2singularity.sh
ADD addLabel.py /addLabel.py
ADD scripts /scripts
RUN chmod a+x docker2singularity.sh
ENTRYPOINT ["docker-entrypoint.sh", "/docker2singularity.sh"]

