FROM docker:1.13

RUN apk add --update automake libtool python m4 autoconf alpine-sdk linux-headers && \
    wget -qO- https://github.com/singularityware/singularity/archive/2.4.tar.gz | tar zxv && \
    cd singularity-2.4 && ./autogen.sh && ./configure --prefix=/usr/local && make && make install && \
    cd ../ && rm -rf singularity-2.4 && \
    apk del automake libtool m4 autoconf alpine-sdk linux-headers

RUN mkdir -p /usr/local/var/singularity/mnt

RUN apk add e2fsprogs bash tar rsync squashfs-tools
ADD docker2singularity.sh /docker2singularity.sh
RUN chmod a+x docker2singularity.sh

ENTRYPOINT ["docker-entrypoint.sh", "/docker2singularity.sh"]
