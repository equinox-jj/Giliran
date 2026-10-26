# syntax=docker/dockerfile:1
# Backup runner: pg_dump from the same PostgreSQL release as the database,
# plus the MinIO client from the same MinIO build as the server.
# Build from backend/: docker build deploy/backup (its own context, since
# .dockerignore keeps deploy/ out of the app images).
#
# Plain Alpine with only the client package, not the postgres image: that one
# carries the server and gosu, which the backup never runs but scanners flag.

FROM pgsty/minio:RELEASE.2026-08-04T00-00-00Z AS minio

FROM alpine:3.24
RUN apk add --no-cache postgresql18-client \
	&& adduser -D -H -u 10001 backup
# mc is a static binary (a symlink to mcli in the MinIO image).
COPY --from=minio /usr/bin/mcli /usr/local/bin/mc
COPY --chmod=0755 backup.sh /usr/local/bin/backup.sh
USER backup
ENTRYPOINT ["/usr/local/bin/backup.sh"]
