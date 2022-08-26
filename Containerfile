FROM alpine:3.12

STOPSIGNAL SIGTERM

# update OS and install some necessary packages
RUN apk update && apk upgrade
RUN apk add --no-cache --clean-protected \
            dumb-init \
            pcre \
            g++ \
            libusb \
            libusb-dev \
            hidapi-dev 

# install build-dependencies
RUN apk add --no-cache --virtual build-dependencies \
            autoconf \
            automake \
            openssl-dev \
            pcre-dev \
            make \
            git \
            coreutils

# link libusb so ld can find it
RUN ln -s /usr/lib/libusb-1.0.so /usr/lib/libusb.so

# setup init
RUN mkdir /init
ADD containerfiles/init.sh /init/init.sh
RUN chmod 755 /init/init.sh

# setup /app
RUN mkdir -p /app/code
RUN git clone https://github.com/sscheib/diamex_tempsense_zabbix.git /app/code/
RUN cd /app/code/src/ && make clean && make
RUN mv /app/code/src/tempsense /app/
RUN rm -rf /app/code/
RUN chmod 755 /app/tempsense


# build zabbix_sender
RUN set -eux
ARG MAJOR_VERSION=6.0
ARG ZBX_VERSION=${MAJOR_VERSION}.3
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git
ENV TERM=xterm ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}
RUN set -eux && \
    cd /tmp/ && \
    git clone ${ZBX_SOURCES} --branch ${ZBX_VERSION} --depth 1 --single-branch zabbix-${ZBX_VERSION} && \
    cd /tmp/zabbix-${ZBX_VERSION} && \
    zabbix_revision=`git rev-parse --short HEAD` && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" include/version.h && \
    ./bootstrap.sh && \
    export CFLAGS="-fPIC -pie -Wl,-z,relro -Wl,-z,now" && \
    ./configure \
            --datadir=/usr/lib \
            --libdir=/usr/lib/zabbix \
            --prefix=/usr \
            --sysconfdir=/etc/zabbix \
            --prefix=/usr \
            --with-openssl \
            --enable-agent \
            --silent && \
    make -j"$(nproc)" -s && \
    cp /tmp/zabbix-${ZBX_VERSION}/src/zabbix_sender/zabbix_sender /usr/bin/zabbix_sender && \
    chmod +x /usr/bin/zabbix_sender

# cleanup
RUN cd /tmp/ && \
    rm -rf /tmp/zabbix-${ZBX_VERSION}/ && \
    apk del --purge --no-network \
            build-dependencies && \
    rm -rf /var/cache/apk/*

# Run the command on container startup
ENTRYPOINT ["dumb-init", "--"]
CMD ["/bin/sh", "-c", "/init/init.sh && exec /app/tempsense -z $ZBX_SERVER -n $ZBX_HOSTNAME"]
