#!/bin/bash
# Immich Networking Debug Script
# This script helps diagnose container communication issues between
# immich-server and immich-machine-learning containers

set -e

COMPOSE_DIR="/opt/podman/immich"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Immich Networking Debug Script"
echo "========================================"
echo ""

# Check if compose directory exists
if [ ! -d "$COMPOSE_DIR" ]; then
    echo -e "${RED}ERROR: Compose directory not found: $COMPOSE_DIR${NC}"
    exit 1
fi

cd "$COMPOSE_DIR"

# 1. Check container status
echo -e "${YELLOW}1. Container Status${NC}"
echo "---"
podman compose ps
echo ""

# 2. Check if containers are running
echo -e "${YELLOW}2. Verifying Containers are Running${NC}"
echo "---"
if podman ps | grep -q "immich_server"; then
    echo -e "${GREEN}✓ immich_server is running${NC}"
else
    echo -e "${RED}✗ immich_server is NOT running${NC}"
fi

if podman ps | grep -q "immich_machine_learning"; then
    echo -e "${GREEN}✓ immich_machine_learning is running${NC}"
else
    echo -e "${RED}✗ immich_machine_learning is NOT running${NC}"
fi
echo ""

# 3. Check network configuration
echo -e "${YELLOW}3. Network Configuration${NC}"
echo "---"
echo "Immich networks:"
podman network ls | grep -i immich || echo "No Immich networks found"
echo ""

# 4. Check which networks containers are on
echo -e "${YELLOW}4. Container Network Membership${NC}"
echo "---"
echo "immich_server networks:"
podman inspect immich_server 2>/dev/null | grep -A 5 '"Networks"' || echo "Container not found"
echo ""
echo "immich_machine_learning networks:"
podman inspect immich_machine_learning 2>/dev/null | grep -A 5 '"Networks"' || echo "Container not found"
echo ""

# 5. Check environment variables
echo -e "${YELLOW}5. Machine Learning URL Configuration${NC}"
echo "---"
ML_URL=$(podman inspect immich_server 2>/dev/null | grep IMMICH_MACHINE_LEARNING_URL | head -1 || echo "Not set")
echo "IMMICH_MACHINE_LEARNING_URL: $ML_URL"
echo ""

# 6. Check if ML container is listening
echo -e "${YELLOW}6. ML Container Listening Status${NC}"
echo "---"
if podman exec immich_machine_learning sh -c 'command -v netstat' >/dev/null 2>&1; then
    podman exec immich_machine_learning netstat -ln | grep 3003 || echo "Port 3003 not listening (or netstat not available)"
else
    echo "netstat not available in container, checking logs instead:"
    podman logs immich_machine_learning 2>&1 | grep -i "listening\|started" | tail -5 || echo "No listening messages found in logs"
fi
echo ""

# 7. Test connectivity from server to ML
echo -e "${YELLOW}7. Testing Server → ML Connectivity${NC}"
echo "---"
if podman exec immich_server sh -c 'command -v curl' >/dev/null 2>&1; then
    echo "Testing HTTP connection to ML service..."
    if podman exec immich_server curl -sf http://immich-machine-learning:3003/ping >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Successfully connected to ML service via service name${NC}"
    else
        echo -e "${RED}✗ Failed to connect to ML service${NC}"
        echo "Attempting to diagnose..."

        # Try to resolve DNS
        if podman exec immich_server sh -c 'command -v nslookup' >/dev/null 2>&1; then
            echo "DNS resolution test:"
            podman exec immich_server nslookup immich-machine-learning || echo "DNS resolution failed"
        fi

        # Try with verbose curl
        echo "Verbose curl output:"
        podman exec immich_server curl -v http://immich-machine-learning:3003/ping 2>&1 || true
    fi
else
    echo "curl not available in server container, skipping connectivity test"
fi
echo ""

# 8. Check health status
echo -e "${YELLOW}8. Container Health Status${NC}"
echo "---"
echo "immich_server health:"
podman inspect immich_server 2>/dev/null | grep -A 10 '"Health"' | head -15 || echo "No health data available"
echo ""
echo "immich_machine_learning health:"
podman inspect immich_machine_learning 2>/dev/null | grep -A 10 '"Health"' | head -15 || echo "No health data available"
echo ""

# 9. Check recent logs for errors
echo -e "${YELLOW}9. Recent Error Logs${NC}"
echo "---"
echo "Server errors (last 10):"
podman logs immich_server 2>&1 | grep -i "error\|fail\|unhealthy" | tail -10 || echo "No errors found"
echo ""
echo "ML errors (last 10):"
podman logs immich_machine_learning 2>&1 | grep -i "error\|fail" | tail -10 || echo "No errors found"
echo ""

# 10. Check compose file configuration
echo -e "${YELLOW}10. Docker Compose Configuration${NC}"
echo "---"
echo "Network configuration in docker-compose.yml:"
grep -A 3 "^networks:" docker-compose.yml 2>/dev/null || echo "No networks section found in compose file"
echo ""
echo "Server network config:"
grep -A 2 "immich-server:" docker-compose.yml | grep -A 2 "networks:" || echo "No network config for server"
echo ""
echo "ML network config:"
grep -A 2 "immich-machine-learning:" docker-compose.yml | grep -A 2 "networks:" || echo "No network config for ML"
echo ""

# Summary
echo "========================================"
echo -e "${YELLOW}Summary${NC}"
echo "========================================"
echo ""

# Check if both containers are healthy
SERVER_HEALTHY=$(podman inspect immich_server 2>/dev/null | grep -c '"Status": "healthy"' || echo "0")
ML_HEALTHY=$(podman inspect immich_machine_learning 2>/dev/null | grep -c '"Status": "healthy"' || echo "0")

if [ "$SERVER_HEALTHY" -gt 0 ] && [ "$ML_HEALTHY" -gt 0 ]; then
    echo -e "${GREEN}✓ Both containers appear healthy${NC}"
elif [ "$SERVER_HEALTHY" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Server healthy, but ML container may have issues${NC}"
elif [ "$ML_HEALTHY" -gt 0 ]; then
    echo -e "${YELLOW}⚠ ML healthy, but server container may have issues${NC}"
else
    echo -e "${RED}✗ One or both containers are unhealthy${NC}"
fi

echo ""
echo "For more detailed logs, run:"
echo "  cd $COMPOSE_DIR && podman compose logs -f"
echo ""
echo "To restart containers:"
echo "  cd $COMPOSE_DIR && podman compose restart"
echo ""
echo "To recreate containers with updated config:"
echo "  cd $COMPOSE_DIR && podman compose down && podman compose up -d"
echo ""
