#!/bin/bash

# Judge0 Management Menu
# Location: ~/.steve/scripts/manageJudge.sh

JUDGE0_DIR="/opt/judge0"

# Colors for better visibility
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

show_header() {
    clear
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   Judge0 Management Menu${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

show_menu() {
    show_header
    echo -e "${GREEN}1)${NC} Check Status"
    echo -e "${GREEN}2)${NC} View Logs (real-time)"
    echo -e "${GREEN}3)${NC} Start Services"
    echo -e "${GREEN}4)${NC} Stop Services"
    echo -e "${GREEN}5)${NC} Restart Services"
    echo -e "${GREEN}6)${NC} Pull Latest Images"
    echo -e "${GREEN}7)${NC} View Container Details"
    echo -e "${GREEN}8)${NC} Test API Connection"
    echo -e "${RED}9)${NC} Exit"
    echo ""
    echo -n "Select an option [1-9]: "
}

check_status() {
    show_header
    echo -e "${YELLOW}Checking Judge0 status...${NC}"
    echo ""
    cd "$JUDGE0_DIR" && sudo docker compose ps
    echo ""
    read -p "Press Enter to continue..."
}

view_logs() {
    show_header
    echo -e "${YELLOW}Viewing logs (Ctrl+C to exit)...${NC}"
    echo ""
    cd "$JUDGE0_DIR" && sudo docker compose logs -f
}

start_services() {
    show_header
    echo -e "${YELLOW}Starting Judge0 services...${NC}"
    echo ""
    cd "$JUDGE0_DIR"
    echo "Starting database and Redis..."
    sudo docker compose up -d db redis
    echo "Waiting 10 seconds..."
    sleep 10
    echo "Starting all services..."
    sudo docker compose up -d
    echo ""
    echo -e "${GREEN}Services started!${NC}"
    echo ""
    sudo docker compose ps
    echo ""
    read -p "Press Enter to continue..."
}

stop_services() {
    show_header
    echo -e "${YELLOW}Stopping Judge0 services...${NC}"
    echo ""
    cd "$JUDGE0_DIR" && sudo docker compose down
    echo ""
    echo -e "${GREEN}Services stopped!${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

restart_services() {
    show_header
    echo -e "${YELLOW}Restarting Judge0 services...${NC}"
    echo ""
    cd "$JUDGE0_DIR" && sudo docker compose restart
    echo ""
    echo -e "${GREEN}Services restarted!${NC}"
    echo ""
    sudo docker compose ps
    echo ""
    read -p "Press Enter to continue..."
}

pull_images() {
    show_header
    echo -e "${YELLOW}Pulling latest Judge0 images...${NC}"
    echo ""
    cd "$JUDGE0_DIR"
    sudo docker compose pull
    echo ""
    echo -e "${GREEN}Images updated!${NC}"
    echo -e "${YELLOW}Run 'Restart Services' to use the new images.${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

view_details() {
    show_header
    echo -e "${YELLOW}Container Details:${NC}"
    echo ""
    cd "$JUDGE0_DIR" && sudo docker compose ps -a
    echo ""
    echo -e "${YELLOW}Disk Usage:${NC}"
    sudo docker system df
    echo ""
    read -p "Press Enter to continue..."
}

test_api() {
    show_header
    echo -e "${YELLOW}Testing Judge0 API...${NC}"
    echo ""
    echo "Testing /languages endpoint:"
    curl -s http://localhost:2358/languages | head -20
    echo ""
    echo ""
    echo -e "${GREEN}API is responding!${NC}"
    echo "Full docs at: http://$(curl -s ifconfig.me):2358/docs"
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_menu
    read -r choice

    case $choice in
        1) check_status ;;
        2) view_logs ;;
        3) start_services ;;
        4) stop_services ;;
        5) restart_services ;;
        6) pull_images ;;
        7) view_details ;;
        8) test_api ;;
        9)
            show_header
            echo -e "${GREEN}Goodbye!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please select 1-9.${NC}"
            sleep 2
            ;;
    esac
done
