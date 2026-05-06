#!/bin/bash
# Backup postgres database to mounted RAID storage.
# Runs every other day via cron.

set -euo pipefail

PROJECT_DIR="/app"
BACKUP_DIR="/mnt/backups"
LOG_FILE="${PROJECT_DIR}/logging/backup.log"

log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

cd "$PROJECT_DIR" || { log "ERROR" "Failed to cd to $PROJECT_DIR"; exit 1; }

source .env

BACKUP_FILE="${BACKUP_DIR}/backup_$(date +%Y%m%d).sql"

log "INFO" "Starting database backup to $BACKUP_FILE"

docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml up -d postgres
sleep 5

if docker-compose -f docker-compose.yaml -f docker-compose.prod.yaml exec -T postgres \
    pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"; then
    log "INFO" "Backup completed successfully: $BACKUP_FILE"
else
    log "ERROR" "Backup failed"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Keep only the last 30 backups
find "$BACKUP_DIR" -name "backup_*.sql" -type f | sort | head -n -30 | xargs -r rm
log "INFO" "Old backups pruned, keeping last 30"
