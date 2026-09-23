#!/bin/sh
set -eu

: "${FTP_PASSWORD:?FTP_PASSWORD is required}"
: "${FTP_PUBLIC_HOST:?FTP_PUBLIC_HOST is required}"
case "$FTP_PUBLIC_HOST" in
  *[!a-zA-Z0-9.-]*|'') echo 'FTP_PUBLIC_HOST must be an IPv4 address or DNS hostname (no scheme or port).' >&2; exit 1 ;;
esac
# chpasswd accepts one account per line. Reject embedded line breaks.
case "$FTP_PASSWORD" in
  *"
"*|*"$(printf '\r')"*) echo 'FTP_PASSWORD cannot contain line breaks.' >&2; exit 1 ;;
esac
if [ "${#FTP_PASSWORD}" -lt 16 ]; then
  echo 'FTP_PASSWORD must contain at least 16 characters.' >&2
  exit 1
fi
printf 'war:%s\n' "$FTP_PASSWORD" | chpasswd
unset FTP_PASSWORD
printf 'war\n' > /etc/vsftpd.allowed_users

# The chroot root stays owned by root. Only webapps is writable by the user.
chown root:root /srv/ftp
chmod 0755 /srv/ftp
mkdir -p /srv/ftp/webapps /var/run/vsftpd/empty
chown 10001:10001 /srv/ftp/webapps
chmod 0755 /srv/ftp/webapps

if [ ! -s /etc/vsftpd/tls/server.crt ] || [ ! -s /etc/vsftpd/tls/server.key ]; then
  openssl req -x509 -nodes -newkey rsa:3072 -days 365 \
    -keyout /etc/vsftpd/tls/server.key \
    -out /etc/vsftpd/tls/server.crt \
    -subj "/CN=$FTP_PUBLIC_HOST"
fi
chmod 0600 /etc/vsftpd/tls/server.key
cp /etc/vsftpd.conf /run/vsftpd.conf
printf '\npasv_address=%s\n' "$FTP_PUBLIC_HOST" >> /run/vsftpd.conf
exec /usr/sbin/vsftpd /run/vsftpd.conf
