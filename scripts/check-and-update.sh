#!/bin/bash
#
# Judge0 Update Checker and Deployer
# ===================================
# Checks GitHub remote for updates and restarts Judge0 if changes are found
#
# Usage:
#   ./check-and-update.sh [--force] [--dry-run]
#
# Options:
#   --force      Force update even if no changes detected
#   --dry-run    Check for updates but don't apply them
#

set -e  # Exit on error

# Configuration
JUDGE0_DIR="${JUDGE0_DIR:-$(dirname $(dirname $(realpath $0)))}"
BRANCH="${BRANCH:-master}"
REMOTE="${REMOTE:-origin}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
FORCE_UPDATE=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force] [--dry-run]"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_separator() {
    echo "=================================================="
}

check_requirements() {
    log_info "Checking requirements..."

    if ! command -v git &> /dev/null; then
        log_error "git is not installed"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose is not installed"
        exit 1
    fi

    log_success "All requirements met"
}

check_for_updates() {
    log_info "Checking for updates from ${REMOTE}/${BRANCH}..."

    cd "$JUDGE0_DIR"

    # Fetch latest changes
    git fetch "$REMOTE" "$BRANCH" 2>&1 || {
        log_error "Failed to fetch from remote"
        exit 1
    }

    # Get current commit
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse "$REMOTE/$BRANCH")

    echo ""
    log_info "Local commit:  $LOCAL_COMMIT"
    log_info "Remote commit: $REMOTE_COMMIT"
    echo ""

    if [ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]; then
        if [ "$FORCE_UPDATE" = true ]; then
            log_warning "No updates found, but --force specified"
            return 0
        else
            log_success "Already up to date!"
            return 1
        fi
    else
        # Show what changed
        log_info "Changes found:"
        echo ""
        git log --oneline --decorate "$LOCAL_COMMIT..$REMOTE_COMMIT"
        echo ""
        return 0
    fi
}

pull_updates() {
    log_info "Pulling updates from ${REMOTE}/${BRANCH}..."

    cd "$JUDGE0_DIR"

    # Check for local changes
    if ! git diff-index --quiet HEAD --; then
        log_warning "Local changes detected:"
        git status --short
        echo ""
        log_error "Please commit or stash local changes before updating"
        exit 1
    fi

    # Pull changes
    git pull "$REMOTE" "$BRANCH" || {
        log_error "Failed to pull updates"
        exit 1
    }

    log_success "Updates pulled successfully"
}

restart_judge0() {
    log_info "Restarting Judge0 services..."

    cd "$JUDGE0_DIR"

    # Stop services
    log_info "Stopping services..."
    docker-compose -f "$COMPOSE_FILE" down || {
        log_warning "Failed to stop services (may not be running)"
    }

    # Pull latest images
    log_info "Pulling latest Docker images..."
    docker-compose -f "$COMPOSE_FILE" pull || {
        log_error "Failed to pull Docker images"
        exit 1
    }

    # Start services
    log_info "Starting services..."
    docker-compose -f "$COMPOSE_FILE" up -d || {
        log_error "Failed to start services"
        exit 1
    }

    log_success "Judge0 services restarted"
}

check_service_health() {
    log_info "Checking service health..."

    cd "$JUDGE0_DIR"

    # Wait a bit for services to start
    sleep 5

    # Check running containers
    log_info "Running containers:"
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""

    # Try to get Judge0 version (if API is accessible)
    if command -v curl &> /dev/null; then
        log_info "Checking API health..."
        if curl -s http://localhost:2358/about > /dev/null 2>&1; then
            log_success "API is responding"
        else
            log_warning "API not responding yet (may need more time to start)"
        fi
    fi
}

# Main execution
main() {
    print_separator
    echo "Judge0 Update Checker"
    echo "Directory: $JUDGE0_DIR"
    echo "Remote: $REMOTE"
    echo "Branch: $BRANCH"
    echo "Compose: $COMPOSE_FILE"
    print_separator
    echo ""

    check_requirements
    echo ""

    if check_for_updates; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Dry run mode - skipping update"
            exit 0
        fi

        echo ""
        print_separator
        log_info "Starting update process..."
        print_separator
        echo ""

        pull_updates
        echo ""

        restart_judge0
        echo ""

        check_service_health
        echo ""

        print_separator
        log_success "Update complete!"
        print_separator
    else
        log_info "No action needed"
    fi

    echo ""
    log_info "Done"
}

# Run main function
main
