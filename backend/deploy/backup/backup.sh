#!/bin/sh
# Daily off-site backup (PRD §10): a pg_dump of the database and a mirror of
# the MinIO bucket, both sent to an S3-compatible remote (R2, B2, another
# MinIO...). Run it from the prod Compose file:
#
#   docker compose -f deploy/docker-compose.prod.yml run --rm backup
#
# Reads POSTGRES_* and MINIO_* from ../.env like the other services, plus:
#   BACKUP_S3_URL         remote endpoint, e.g. https://<account>.r2.cloudflarestorage.com
#   BACKUP_S3_ACCESS_KEY  remote credentials
#   BACKUP_S3_SECRET_KEY
#   BACKUP_S3_BUCKET      remote bucket (must exist)
#   BACKUP_RETENTION_DAYS dumps older than this are deleted (default 30)
#
# Layout on the remote:
#   <bucket>/postgres/giliran-<UTC timestamp>.dump   pg_dump -Fc, one per run
#   <bucket>/minio/<object key>                      mirror of the live bucket
#
# The mirror runs with --remove, so objects the cleanup job purges (proof
# images past retention, deleted avatars) are removed off-site too, as the
# retention rules require (DB_SCHEME §10).
set -eu
set -o pipefail

: "${POSTGRES_USER:?}" "${POSTGRES_PASSWORD:?}" "${POSTGRES_DB:?}"
: "${MINIO_ROOT_USER:?}" "${MINIO_ROOT_PASSWORD:?}"
: "${BACKUP_S3_URL:?}" "${BACKUP_S3_ACCESS_KEY:?}" "${BACKUP_S3_SECRET_KEY:?}" "${BACKUP_S3_BUCKET:?}"
retention="${BACKUP_RETENTION_DAYS:-30}"
bucket="${MINIO_BUCKET:-giliran}"
pg_host="${BACKUP_PG_HOST:-postgres}"
minio_url="${BACKUP_MINIO_URL:-http://minio:9000}"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) backup: $*"; }

# mc keeps its aliases here; the container is thrown away after each run.
export MC_CONFIG_DIR="$(mktemp -d)"
work="$(mktemp -d)"
trap 'rm -rf "$work" "$MC_CONFIG_DIR"' EXIT

mc alias set local "$minio_url" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
mc alias set remote "$BACKUP_S3_URL" "$BACKUP_S3_ACCESS_KEY" "$BACKUP_S3_SECRET_KEY" >/dev/null

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
dump="$work/giliran-$stamp.dump"
log "dumping $POSTGRES_DB"
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$pg_host" -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
	--format=custom --compress=9 --no-owner --file="$dump"
# A dump that pg_restore cannot list is not a backup.
pg_restore --list "$dump" >/dev/null
log "uploading $(du -h "$dump" | cut -f1) to remote/$BACKUP_S3_BUCKET/postgres/"
mc --quiet cp "$dump" "remote/$BACKUP_S3_BUCKET/postgres/"

log "mirroring local/$bucket to remote/$BACKUP_S3_BUCKET/minio/"
mc --quiet mirror --overwrite --remove "local/$bucket" "remote/$BACKUP_S3_BUCKET/minio"

log "pruning dumps older than ${retention}d"
mc --quiet rm --recursive --force --older-than "${retention}d" "remote/$BACKUP_S3_BUCKET/postgres/"

log "done"
