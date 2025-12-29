#!/bin/bash
#
# Judge0 WSL2 Setup Script
# ========================
# Fully automated setup of Judge0 on Windows Subsystem for Linux 2
#
# This script will:
#   1. Verify WSL2 and Docker prerequisites
#   2. Clone/setup the Judge0 repository
#   3. Configure Judge0 settings
#   4. Pull Docker images
#   5. Start all services
#   6. Verify the installation
#
# Usage:
#   curl -sL <raw-script-url> | bash
#   # OR
#   ./setup-wsl.sh [OPTIONS]
#
# Options:
#   --judge0-dir PATH    Installation directory (default: ~/judge0)
#   --skip-clone         Skip git clone (use existing directory)
#   --redis-pass PASS    Set Redis password (default: auto-generated)
#   --postgres-pass PASS Set PostgreSQL password (default: auto-generated)
#   --port PORT          API port (default: 2358)
#   --verbose            Enable verbose output
#   --dry-run            Show what would be done without executing
#

set -e

#=============================================================================
# Configuration Defaults
#=============================================================================
JUDGE0_DIR="${JUDGE0_DIR:-$HOME/judge0}"
JUDGE0_REPO="https://github.com/judge0/judge0.git"
JUDGE0_BRANCH="master"
API_PORT="${API_PORT:-2358}"
REDIS_PASSWORD=""
POSTGRES_PASSWORD=""
SKIP_CLONE=false
VERBOSE=false
DRY_RUN=false

#=============================================================================
# Colors and Logging
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

run_cmd() {
    local cmd="$1"
    local desc="${2:-Running command}"
    
    log_verbose "$desc: $cmd"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} $cmd"
        return 0
    fi
    
    if [ "$VERBOSE" = true ]; then
        eval "$cmd"
    else
        eval "$cmd" > /dev/null 2>&1
    fi
}

#=============================================================================
# Parse Arguments
#=============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --judge0-dir)
                JUDGE0_DIR="$2"
                shift 2
                ;;
            --skip-clone)
                SKIP_CLONE=true
                shift
                ;;
            --redis-pass)
                REDIS_PASSWORD="$2"
                shift 2
                ;;
            --postgres-pass)
                POSTGRES_PASSWORD="$2"
                shift 2
                ;;
            --port)
                API_PORT="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
Judge0 WSL2 Setup Script
========================

Usage: ./setup-wsl.sh [OPTIONS]

Options:
  --judge0-dir PATH    Installation directory (default: ~/judge0)
  --skip-clone         Skip git clone (use existing directory)
  --redis-pass PASS    Set Redis password (default: auto-generated)
  --postgres-pass PASS Set PostgreSQL password (default: auto-generated)
  --port PORT          API port (default: 2358)
  --verbose            Enable verbose output
  --dry-run            Show what would be done without executing
  --help, -h           Show this help message

Examples:
  # Basic setup with defaults
  ./setup-wsl.sh

  # Custom installation directory
  ./setup-wsl.sh --judge0-dir /opt/judge0

  # Use existing clone, custom passwords
  ./setup-wsl.sh --skip-clone --redis-pass mypass --postgres-pass dbpass

  # Preview what will happen
  ./setup-wsl.sh --dry-run
EOF
}

#=============================================================================
# Generate Random Password
#=============================================================================
generate_password() {
    local length="${1:-32}"
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

#=============================================================================
# Prerequisite Checks
#=============================================================================
check_wsl() {
    log_step "Checking WSL environment..."
    
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_success "Running in WSL"
        
        # Check WSL version
        if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
            log_verbose "WSL interop enabled"
        fi
        
        # Check for WSL2 (has full Linux kernel)
        if uname -r | grep -qi "microsoft.*WSL2\|microsoft-standard"; then
            log_success "WSL2 detected (required for Docker)"
        else
            log_warning "May be WSL1 - Docker requires WSL2"
            log_info "To upgrade: wsl --set-version <distro> 2"
        fi
    else
        log_warning "Not running in WSL - script designed for WSL2"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_docker() {
    log_step "Checking Docker..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found!"
        echo ""
        echo "Please install Docker Desktop for Windows with WSL2 backend:"
        echo "  1. Download from: https://www.docker.com/products/docker-desktop/"
        echo "  2. Install and enable WSL2 backend"
        echo "  3. In Settings > Resources > WSL Integration, enable your distro"
        echo "  4. Restart this script"
        echo ""
        exit 1
    fi
    log_success "Docker CLI found"
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running!"
        echo ""
        echo "Please ensure Docker Desktop is running:"
        echo "  - Check the Docker Desktop icon in Windows system tray"
        echo "  - If not running, start Docker Desktop"
        echo "  - Wait for it to fully initialize"
        echo ""
        exit 1
    fi
    log_success "Docker daemon is running"
    
    # Check docker-compose
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose version --short 2>/dev/null || echo "unknown")
        log_success "docker-compose found (v$compose_version)"
    elif docker compose version &> /dev/null; then
        log_success "docker compose (plugin) found"
        # Create alias function for compatibility
        docker-compose() { docker compose "$@"; }
        export -f docker-compose
    else
        log_error "docker-compose not found!"
        echo "Please install docker-compose or use Docker Desktop which includes it"
        exit 1
    fi
}

check_git() {
    log_step "Checking Git..."
    
    if ! command -v git &> /dev/null; then
        log_warning "Git not found - installing..."
        run_cmd "sudo apt-get update && sudo apt-get install -y git" "Installing git"
    fi
    log_success "Git available"
}

check_dependencies() {
    log_step "Checking additional dependencies..."
    
    local missing=()
    
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_info "Installing: ${missing[*]}"
        run_cmd "sudo apt-get update && sudo apt-get install -y ${missing[*]}" "Installing dependencies"
    fi
    
    log_success "All dependencies available"
}

#=============================================================================
# Setup Judge0
#=============================================================================
setup_repository() {
    log_step "Setting up Judge0 repository..."
    
    if [ "$SKIP_CLONE" = true ]; then
        if [ ! -d "$JUDGE0_DIR" ]; then
            log_error "Directory $JUDGE0_DIR does not exist and --skip-clone specified"
            exit 1
        fi
        log_info "Using existing directory: $JUDGE0_DIR"
    else
        if [ -d "$JUDGE0_DIR" ]; then
            log_warning "Directory $JUDGE0_DIR already exists"
            read -p "Remove and re-clone? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                run_cmd "rm -rf '$JUDGE0_DIR'" "Removing existing directory"
            else
                log_info "Using existing directory"
                SKIP_CLONE=true
            fi
        fi
        
        if [ "$SKIP_CLONE" = false ]; then
            log_info "Cloning Judge0 repository..."
            run_cmd "git clone --branch '$JUDGE0_BRANCH' '$JUDGE0_REPO' '$JUDGE0_DIR'" "Cloning repository"
        fi
    fi
    
    log_success "Repository ready at $JUDGE0_DIR"
}

configure_judge0() {
    log_step "Configuring Judge0..."
    
    cd "$JUDGE0_DIR"
    
    # Generate passwords if not provided
    if [ -z "$REDIS_PASSWORD" ]; then
        REDIS_PASSWORD=$(generate_password 32)
        log_verbose "Generated Redis password"
    fi
    
    if [ -z "$POSTGRES_PASSWORD" ]; then
        POSTGRES_PASSWORD=$(generate_password 32)
        log_verbose "Generated PostgreSQL password"
    fi
    
    # Backup existing config
    if [ -f "judge0.conf" ]; then
        cp judge0.conf judge0.conf.backup.$(date +%Y%m%d_%H%M%S)
        log_verbose "Backed up existing judge0.conf"
    fi
    
    # Create/update configuration
    log_info "Writing configuration..."
    
    if [ "$DRY_RUN" = false ]; then
        # Check if config has placeholders or needs passwords set
        if grep -q "^REDIS_PASSWORD=$" judge0.conf 2>/dev/null || \
           ! grep -q "^REDIS_PASSWORD=" judge0.conf 2>/dev/null; then
            # Need to set passwords - use sed to update or append
            
            # Create a temporary file with updated values
            cat > judge0.conf.tmp << EOF
################################################################################
# Judge0 Configuration File (WSL2 Setup)
# Generated: $(date)
################################################################################

# Database Configuration
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=judge0
POSTGRES_USER=judge0
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Redis Configuration  
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASSWORD

################################################################################
# Include the rest of the default configuration
################################################################################
EOF
            # Append the original config, skipping password lines
            grep -v "^POSTGRES_PASSWORD=\|^REDIS_PASSWORD=" judge0.conf >> judge0.conf.tmp 2>/dev/null || true
            mv judge0.conf.tmp judge0.conf
        fi
    fi
    
    # Update docker-compose port if needed
    if [ "$API_PORT" != "2358" ]; then
        log_info "Updating API port to $API_PORT..."
        if [ "$DRY_RUN" = false ]; then
            sed -i "s/\"2358:2358\"/\"$API_PORT:2358\"/" docker-compose.yml
        fi
    fi
    
    log_success "Configuration complete"
    
    # Save credentials for user
    if [ "$DRY_RUN" = false ]; then
        cat > "$JUDGE0_DIR/.credentials" << EOF
# Judge0 Credentials (generated $(date))
# Keep this file secure!

REDIS_PASSWORD=$REDIS_PASSWORD
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
API_URL=http://localhost:$API_PORT
EOF
        chmod 600 "$JUDGE0_DIR/.credentials"
        log_info "Credentials saved to $JUDGE0_DIR/.credentials"
    fi
}

#=============================================================================
# Docker Operations
#=============================================================================
pull_images() {
    log_step "Pulling Docker images (this may take a while)..."
    
    cd "$JUDGE0_DIR"
    
    local images=(
        "judge0/judge0:latest"
        "postgres:16.2"
        "redis:7.2.4"
    )
    
    for image in "${images[@]}"; do
        log_info "Pulling $image..."
        if [ "$DRY_RUN" = false ]; then
            docker pull "$image"
        else
            echo "  [DRY-RUN] docker pull $image"
        fi
    done
    
    log_success "All images pulled"
}

start_services() {
    log_step "Starting Judge0 services..."
    
    cd "$JUDGE0_DIR"
    
    # Stop any existing containers
    log_info "Stopping any existing containers..."
    run_cmd "docker-compose down 2>/dev/null || true" "Stopping containers"
    
    # Start services
    log_info "Starting containers..."
    if [ "$DRY_RUN" = false ]; then
        docker-compose up -d
    else
        echo "  [DRY-RUN] docker-compose up -d"
    fi
    
    log_success "Services started"
}

#=============================================================================
# Verification
#=============================================================================
wait_for_api() {
    log_step "Waiting for API to be ready..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would wait for API at http://localhost:$API_PORT"
        return 0
    fi
    
    local max_attempts=60
    local attempt=1
    local api_url="http://localhost:$API_PORT"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$api_url/about" > /dev/null 2>&1; then
            log_success "API is responding!"
            return 0
        fi
        
        # Show progress
        printf "\r  Attempt %d/%d - waiting..." "$attempt" "$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    echo ""
    log_error "API did not respond within timeout"
    log_info "Check logs with: docker-compose logs"
    return 1
}

verify_installation() {
    log_step "Verifying installation..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Would verify installation"
        return 0
    fi
    
    cd "$JUDGE0_DIR"
    local api_url="http://localhost:$API_PORT"
    
    # Check containers
    log_info "Container status:"
    docker-compose ps
    echo ""
    
    # Check API
    log_info "API information:"
    local about=$(curl -s "$api_url/about" 2>/dev/null || echo "{}")
    echo "$about" | jq . 2>/dev/null || echo "$about"
    echo ""
    
    # Check languages
    log_info "Available languages:"
    local lang_count=$(curl -s "$api_url/languages" 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    log_success "$lang_count languages available"
    
    # Test submission
    log_info "Testing code execution..."
    local test_result=$(curl -s -X POST "$api_url/submissions?wait=true" \
        -H "Content-Type: application/json" \
        -d '{
            "source_code": "print(\"Hello from Judge0!\")",
            "language_id": 71
        }' 2>/dev/null)
    
    local status=$(echo "$test_result" | jq -r '.status.description' 2>/dev/null || echo "unknown")
    local output=$(echo "$test_result" | jq -r '.stdout' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    
    if [ "$status" = "Accepted" ]; then
        log_success "Test execution successful: $output"
    else
        log_warning "Test execution status: $status"
        log_verbose "Full response: $test_result"
    fi
}

#=============================================================================
# Summary
#=============================================================================
print_summary() {
    log_header "Setup Complete!"
    
    echo ""
    echo -e "${GREEN}Judge0 is now running on your WSL2 instance!${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}Quick Reference${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "  ${CYAN}API URL:${NC}        http://localhost:$API_PORT"
    echo -e "  ${CYAN}Documentation:${NC}  http://localhost:$API_PORT/docs"
    echo -e "  ${CYAN}Installation:${NC}   $JUDGE0_DIR"
    echo -e "  ${CYAN}Credentials:${NC}    $JUDGE0_DIR/.credentials"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}Common Commands${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  # View status"
    echo "  cd $JUDGE0_DIR && docker-compose ps"
    echo ""
    echo "  # View logs"
    echo "  cd $JUDGE0_DIR && docker-compose logs -f"
    echo ""
    echo "  # Restart services"
    echo "  cd $JUDGE0_DIR && docker-compose restart"
    echo ""
    echo "  # Stop services"
    echo "  cd $JUDGE0_DIR && docker-compose down"
    echo ""
    echo "  # Start services"
    echo "  cd $JUDGE0_DIR && docker-compose up -d"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}Test Submission (Python)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    cat << 'EOF'
  curl -X POST "http://localhost:2358/submissions?wait=true" \
    -H "Content-Type: application/json" \
    -d '{"source_code": "print(1+1)", "language_id": 71}'
EOF
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

#=============================================================================
# Main
#=============================================================================
main() {
    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          Judge0 WSL2 Automated Setup Script               ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    parse_args "$@"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    
    log_header "Checking Prerequisites"
    check_wsl
    check_docker
    check_git
    check_dependencies
    
    log_header "Setting Up Judge0"
    setup_repository
    configure_judge0
    
    log_header "Deploying Services"
    pull_images
    start_services
    
    log_header "Verifying Installation"
    wait_for_api
    verify_installation
    
    print_summary
}

# Run main function
main "$@"
