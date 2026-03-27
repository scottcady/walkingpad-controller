#!/bin/bash
#
# Start the WalkingPad Bridge Server
# This script sets up the environment and runs the bridge.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "=================================="
echo "  WalkingPad Bridge Setup"
echo "=================================="
echo ""

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    echo "Install it from https://www.python.org/downloads/"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install/update dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
pip install -q --upgrade pip
pip install -q -r requirements.txt

# Get local IP address
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}Starting bridge server...${NC}"
echo ""
echo "=================================="
echo "  Bridge URL: http://$IP:8000"
echo "=================================="
echo ""
echo "Enter this URL in the iOS app Settings."
echo "Press Ctrl+C to stop the server."
echo ""

# Run with caffeinate to prevent sleep
caffeinate -i python3 bridge.py
