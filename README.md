# Java 8 WAR hosting on Dokploy

Run Java **1.8 (Java 8)** WAR applications using **Tomcat 9**, with FTP uploads over explicit TLS (FTPS). The `tomcat` and `ftp` services share a persistent `webapps` volume. Tomcat automatically deploys WAR files and runs as UID 10001. FTP username: **war**.

## Deploy on Dokploy

1. Push this entire project to your Git repository, including the `ftp` directory.
2. In Dokploy, create a project and add a **Docker Compose** service. Connect your Git repository and select `docker-compose.yml` as the Compose path. Use Compose mode, not Docker Stack/Swarm mode, because this project builds the FTP image.
3. In the service's **Environment** tab, enter the values from `.env.example`. Change `FTP_PUBLIC_HOST` to your server's public IPv4 address or a DNS-only hostname, and set a unique `FTP_PASSWORD` with at least 16 characters. Do not include `ftp://` or a port in `FTP_PUBLIC_HOST`. Use single quotes around passwords containing `$` in a local `.env` file to prevent Compose interpolation.
4. Deploy the service.
5. Under **Domains**, add your application domain, select service **tomcat**, and set container port **8080**, path `/`. Enable HTTPS, point your domain's DNS to the Dokploy server, and redeploy to apply routing.
6. Allow inbound TCP **21** and **30000-30009** on the server/provider firewall. If you change `FTP_PORT`, allow that port instead of 21. Behind NAT, forward these ports to the server; passive ports must retain the same numbers. Restrict FTP access to your own IP addresses where possible.

HTTP traffic goes through Dokploy's domain routing. FTP connects directly to the server; it does not use the HTTPS domain proxy. If using Cloudflare, the FTP hostname must be DNS-only. The default passive port range supports a small number of concurrent transfers. Only one instance of this stack can bind these host ports per server without adjustments.

## Upload a WAR with FileZilla or WinSCP

| Setting | Value |
| --- | --- |
| Protocol | FTP |
| Encryption | Require explicit FTP over TLS |
| Host | Your server's public IPv4 or FTP DNS hostname |
| Port | 21 (or `FTP_PORT`) |
| Username | `war` |
| Password | Your `FTP_PASSWORD` |
| Transfer mode | Passive, binary |
| Remote folder | `/webapps` |

A self-signed TLS certificate is generated on first startup and persisted. Verify its SHA-256 fingerprint before trusting it in your client. From the repository directory on the deployment server (or the FTP container terminal), run:

```sh
docker compose exec ftp openssl x509 -in /etc/vsftpd/tls/server.crt -noout -fingerprint -sha256
```

In a Dokploy container terminal, omit `docker compose exec ftp`. For a trusted certificate, replace `server.crt` (PEM full chain) and `server.key` in the FTP TLS volume and restart FTP. The generated certificate expires after 365 days; replace/renew it before expiry. Dokploy's web HTTPS certificate does not automatically replace this FTP certificate.

**Upload using a temporary filename**, for example `/webapps/myapp.war.uploading`. Once the transfer completes, rename it to `myapp.war`. This prevents Tomcat from deploying a partially uploaded archive. For an update, upload the new temporary file, then rename it over the existing WAR; clients that cannot overwrite by rename must delete the old WAR immediately before renaming. This can cause a short outage. Keep a backup of the previous WAR outside `webapps`.

- `ROOT.war` serves `https://your-domain/` (uppercase ROOT).
- `myapp.war` serves `https://your-domain/myapp/`.
- Multiple WAR files can run in the same Tomcat instance.

Allow a few seconds for deployment and check Tomcat logs in Dokploy. Do not edit the automatically expanded application directories or delete them while an application is running. Removing a deployed WAR undeploys its application. A 404 at `/` before uploading `ROOT.war` is normal; the container health check only verifies that Tomcat responds, not that your application is healthy.

## Local startup and checks

With Docker running in Linux-container mode:

```sh
cp .env.example .env
# Edit .env: set a real password and FTP_PUBLIC_HOST=127.0.0.1 for local FTP.
docker compose config --quiet
docker compose up -d --build
docker compose exec tomcat java -version
docker compose exec tomcat catalina.sh version
docker compose logs --tail=100 tomcat ftp
```

Tomcat's port is not published to the host by default. For local HTTP testing, create a `compose.local.yml` file containing:

```yaml
services:
  tomcat:
    ports:
      - "127.0.0.1:8080:8080"
```

Then run `docker compose -f docker-compose.yml -f compose.local.yml up -d --build` and visit `http://localhost:8080/myapp/` after uploading your WAR.

## Persistence and application configuration

WAR files survive restarts and redeployments in the named `webapps` volume. Preserve the Compose project identity and back up that volume. `docker compose down -v` deletes uploaded applications and the FTP certificate. Tomcat console logs are available in Dokploy; file logs, work files, and temporary files are ephemeral.

Set JVM memory through `CATALINA_OPTS`; its default maximum heap is 1 GB, and the server needs extra memory for Java native allocations and other services. Add your application's database URLs, credentials, and other settings to the **tomcat** service's environment as required. No database is included. Applications that write persistent data outside `webapps` need additional volumes.

The image tag stays on Tomcat 9 and Java 8 while allowing patch updates. Pull/redeploy to receive fixes; pin a tested image digest if reproducible builds are required. The FTP account can replace executable application code, so treat its credentials as deployment credentials. Plain unencrypted FTP login is disabled.

## References

- [Official Tomcat Docker image](https://hub.docker.com/_/tomcat)
- [Dokploy Compose domains](https://docs.dokploy.com/docs/core/docker-compose/domains)
- [vsftpd configuration](https://security.appspot.com/vsftpd/vsftpd_conf.html)
