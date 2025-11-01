#!/bin/bash
#
# Judge0 Status Checker
# =====================
# Check the status of Judge0 services and API
#

set -e

# Configuration
JUDGE0_DIR="${JUDGE0_DIR:-$(dirname $(dirname $(realpath $0)))}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
API_URL="${API_URL:-http://localhost:2358}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "Judge0 Status Check"
echo "==================="
echo ""

cd "$JUDGE0_DIR"

# Git info
log_info "Repository Status:"
echo "  Branch: $(git branch --show-current)"
echo "  Commit: $(git rev-parse --short HEAD)"
echo "  Remote: $(git rev-parse --short origin/master 2>/dev/null || echo 'unknown')"
echo ""

# Docker containers
log_info "Docker Containers:"
docker-compose -f "$COMPOSE_FILE" ps
echo ""

# API health check
log_info "API Health Check:"
if command -v curl &> /dev/null; then
    if curl -s "$API_URL/about" > /dev/null 2>&1; then
        log_success "API is responding at $API_URL"

        # Get version info
        VERSION=$(curl -s "$API_URL/about" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
        echo "  Version: $VERSION"
    else
        log_warning "API is not responding at $API_URL"
    fi
else
    log_warning "curl not installed - skipping API check"
fi

echo ""
log_info "Done"
