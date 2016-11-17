FROM alpine:3.4

COPY init.sh            /init.sh
COPY my.cnf             /etc/mysql/my.cnf
COPY scripts/*          /usr/local/bin/

RUN \
apk --update add --no-cache \
mariadb mariadb-client tzdata \
&& chmod +x /usr/local/bin/* \
&& rm -rf /tmp/src /var/cache/apk/*

CMD ["/bin/sh", "/init.sh"]
