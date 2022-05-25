FROM registry.access.redhat.com/ubi8/ubi
MAINTAINER Steffen Scheib
# system preperation
RUN dnf update -y && dnf -y install libusb hidapi hidapi-devel gcc-c++ make pkgconf-pkg-config zabbix-sender python3-pip
RUN ln -s /usr/lib64/libusb-1.0.so.0 /usr/lib64/libusb.so
RUN pip3 install dumb-init

# init
RUN mkdir /init
ADD containerfiles/init.sh /init/init.sh
RUN chmod 755 /init/init.sh

# app building
RUN mkdir /build_dir/
ADD src/* /build_dir/
RUN cd /build_dir && make clean && make

# setup /app
RUN mkdir /app
RUN mv /build_dir/tempsense /app/tempsense
RUN chmod 775 /app/tempsense
# ADD zabbix_agentd.conf /app/zabbix_agentd.conf

# cleanup
RUN dnf remove -y gcc-c++ make pkgconf-pkg-config
RUN rm -rf /build_dir/
 
# Run the command on container startup
ENTRYPOINT ["dumb-init", "--"]
CMD ["bash", "-c", "/init/init.sh && exec /app/tempsense -z $ZBX_SERVER -n $ZBX_HOSTNAME"]
