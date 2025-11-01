#!/bin/bash
#
# Judge0 Service Restart Script
# ==============================
# Simple script to restart Judge0 services
#
# Usage:
#   ./restart.sh [dev|prod]
#

set -e

# Configuration
JUDGE0_DIR="${JUDGE0_DIR:-$(dirname $(dirname $(realpath $0)))}"
MODE="${1:-prod}"

if [ "$MODE" == "dev" ]; then
    COMPOSE_FILE="docker-compose.dev.yml"
else
    COMPOSE_FILE="docker-compose.yml"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo "Judge0 Restart Script"
echo "====================="
echo "Directory: $JUDGE0_DIR"
echo "Mode: $MODE"
echo "Compose: $COMPOSE_FILE"
echo ""

cd "$JUDGE0_DIR"

log_info "Stopping services..."
docker-compose -f "$COMPOSE_FILE" down

echo ""
log_info "Starting services..."
docker-compose -f "$COMPOSE_FILE" up -d

echo ""
log_info "Service status:"
docker-compose -f "$COMPOSE_FILE" ps

echo ""
log_success "Judge0 restarted!"
