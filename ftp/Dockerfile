FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends vsftpd openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 war \
    && useradd --uid 10001 --gid 10001 --home-dir /srv/ftp --shell /bin/bash war \
    && mkdir -p /srv/ftp/webapps /var/run/vsftpd/empty /etc/vsftpd/tls \
    && chown 10001:10001 /srv/ftp/webapps

COPY vsftpd.conf /etc/vsftpd.conf
COPY entrypoint.sh /usr/local/bin/ftp-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/ftp-entrypoint \
    && chmod 0755 /usr/local/bin/ftp-entrypoint

EXPOSE 21 30000-30009
ENTRYPOINT ["/usr/local/bin/ftp-entrypoint"]
