FROM rockylinux:9
RUN echo "ip_resolve=4" >> /etc/dnf/dnf.conf
RUN yum -y update && \
    yum -y install unzip telnet wget procps-ng \
        zlib.i686 libgcc.i686 libstdc++.i686 \
        libxcrypt.i686 libxcrypt-compat.i686 \
        net-tools psmisc && \
    yum clean all && \
    rm -rf /var/cache/yum /var/cache/dnf
RUN mkdir -p /opt/SIP-DECT
RUN echo "OMM_CONFIG_FILE=/conf/omm_conf.txt" > /etc/sysconfig/SIP-DECT
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x ./entrypoint.sh
CMD ["/entrypoint.sh"]

