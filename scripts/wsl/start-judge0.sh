#!/bin/bash
#
# Judge0 WSL Startup Script
# =========================
# Starts Judge0 from the Windows-mounted source directory.
# Designed for the dedicated judge0-wsl instance.
#
# Usage:
#   ./start-judge0.sh [OPTIONS]
#
# Options:
#   --pull      Pull latest Docker images before starting
#   --fresh     Remove existing containers and volumes, start fresh
#   --logs      Follow logs after starting
#   --check     Just check status, don't start
#

set -e

#=============================================================================
# Configuration
#=============================================================================
# Judge0 source on Windows mount
JUDGE0_DIR="${JUDGE0_DIR:-/mnt/c/myStuff/_tooling/Judge0}"
COMPOSE_FILE="docker-compose.yml"

#=============================================================================
# Colors
#=============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_header() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

#=============================================================================
# Parse Arguments
#=============================================================================
DO_PULL=false
DO_FRESH=false
DO_LOGS=false
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --pull)
            DO_PULL=true
            shift
            ;;
        --fresh)
            DO_FRESH=true
            shift
            ;;
        --logs)
            DO_LOGS=true
            shift
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --pull      Pull latest Docker images before starting"
            echo "  --fresh     Remove existing containers and volumes, start fresh"
            echo "  --logs      Follow logs after starting"
            echo "  --check     Just check status, don't start"
            echo ""
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

#=============================================================================
# Main
#=============================================================================
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║            Judge0 WSL Startup                             ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

#-----------------------------------------------------------------------------
# Verify Environment
#-----------------------------------------------------------------------------
log_header "Verifying Environment"

# Check Judge0 directory
log_step "Checking Judge0 source..."
if [ ! -d "$JUDGE0_DIR" ]; then
    log_error "Judge0 directory not found: $JUDGE0_DIR"
    exit 1
fi

if [ ! -f "$JUDGE0_DIR/$COMPOSE_FILE" ]; then
    log_error "docker-compose.yml not found in $JUDGE0_DIR"
    exit 1
fi
log_success "Judge0 source: $JUDGE0_DIR"

# Check Docker
log_step "Checking Docker..."
if ! command -v docker &> /dev/null; then
    log_error "Docker not found!"
    echo ""
    echo "Ensure Docker Desktop WSL Integration is enabled:"
    echo "  Docker Desktop → Settings → Resources → WSL Integration"
    echo ""
    exit 1
fi

if ! docker info &> /dev/null; then
    log_error "Docker daemon not running!"
    echo ""
    echo "Please start Docker Desktop on Windows"
    echo ""
    exit 1
fi
log_success "Docker is available"

# Check docker-compose
log_step "Checking docker-compose..."
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    log_error "docker-compose not found!"
    exit 1
fi
log_success "Using: $COMPOSE_CMD"

cd "$JUDGE0_DIR"

#-----------------------------------------------------------------------------
# Status Check
#-----------------------------------------------------------------------------
if [ "$CHECK_ONLY" = true ]; then
    log_header "Judge0 Status"
    
    log_info "Container status:"
    $COMPOSE_CMD -f "$COMPOSE_FILE" ps
    echo ""
    
    log_info "API check:"
    if curl -s "http://localhost:2358/about" > /dev/null 2>&1; then
        log_success "API is responding"
        curl -s "http://localhost:2358/about" | jq . 2>/dev/null || curl -s "http://localhost:2358/about"
    else
        log_warning "API is not responding"
    fi
    exit 0
fi

#-----------------------------------------------------------------------------
# Fresh Start (if requested)
#-----------------------------------------------------------------------------
if [ "$DO_FRESH" = true ]; then
    log_header "Fresh Start - Removing Existing Data"
    
    log_warning "This will remove all containers and volumes!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi
    
    log_step "Stopping containers..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    log_success "Containers and volumes removed"
fi

#-----------------------------------------------------------------------------
# Pull Images (if requested)
#-----------------------------------------------------------------------------
if [ "$DO_PULL" = true ]; then
    log_header "Pulling Docker Images"
    
    log_step "Pulling latest images..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" pull
    log_success "Images updated"
fi

#-----------------------------------------------------------------------------
# Start Services
#-----------------------------------------------------------------------------
log_header "Starting Judge0 Services"

log_step "Starting containers..."
$COMPOSE_CMD -f "$COMPOSE_FILE" up -d

log_success "Containers started"
echo ""

# Show status
log_info "Container status:"
$COMPOSE_CMD -f "$COMPOSE_FILE" ps
echo ""

#-----------------------------------------------------------------------------
# Wait for API
#-----------------------------------------------------------------------------
log_step "Waiting for API to be ready..."

max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -s "http://localhost:2358/about" > /dev/null 2>&1; then
        echo ""
        log_success "API is ready!"
        break
    fi
    printf "\r  Attempt %d/%d..." "$attempt" "$max_attempts"
    sleep 2
    ((attempt++))
done

if [ $attempt -gt $max_attempts ]; then
    echo ""
    log_warning "API did not respond within timeout"
    log_info "Check logs with: j0-logs"
fi

#-----------------------------------------------------------------------------
# Summary
#-----------------------------------------------------------------------------
log_header "Judge0 is Running!"

echo ""
echo -e "  ${CYAN}API URL:${NC}   http://localhost:2358"
echo -e "  ${CYAN}Docs:${NC}      http://localhost:2358/docs"
echo -e "  ${CYAN}Source:${NC}    $JUDGE0_DIR"
echo ""
echo -e "  ${CYAN}Commands:${NC}"
echo "    j0-logs     - View logs"
echo "    j0-ps       - Container status"
echo "    j0-down     - Stop services"
echo "    j0-restart  - Restart services"
echo ""

#-----------------------------------------------------------------------------
# Follow Logs (if requested)
#-----------------------------------------------------------------------------
if [ "$DO_LOGS" = true ]; then
    log_header "Following Logs (Ctrl+C to exit)"
    $COMPOSE_CMD -f "$COMPOSE_FILE" logs -f
fi
