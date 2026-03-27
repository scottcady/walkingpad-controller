#!/usr/bin/env python3
"""
WalkingPad Bridge Server

A FastAPI server that bridges iOS app commands to the WalkingPad via Bluetooth.
Run this on your Mac while using the iOS app.

Usage:
    python bridge.py

The server will:
1. Scan for and connect to your WalkingPad
2. Start an HTTP server on port 8000
3. Relay commands from the iOS app to the WalkingPad
"""

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from ph4_walkingpad.pad import Scanner, Controller, WalkingPad, WalkingPadCurStatus

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class WalkingPadController(Controller):
    """Extended Controller that captures status updates."""

    def __init__(self, address=None):
        super().__init__(address)
        self.last_status: Optional[WalkingPadCurStatus] = None

    def on_cur_status_received(self, sender, status: WalkingPadCurStatus):
        """Callback when WalkingPad sends status update."""
        self.last_status = status


# Global state
controller: Optional[WalkingPadController] = None
device_address: Optional[str] = None
connected = False


async def scan_for_device():
    """Scan for WalkingPad device."""
    import bleak

    logger.info("Scanning for all Bluetooth devices...")

    # First, scan for ALL devices to see what's available
    all_devices = await bleak.BleakScanner.discover(timeout=5.0)

    if all_devices:
        logger.info(f"Found {len(all_devices)} Bluetooth devices:")
        for d in all_devices:
            logger.info(f"  - {d.name or 'Unknown'} ({d.address})")
    else:
        logger.info("No Bluetooth devices found at all.")

    # Now try the WalkingPad-specific scan
    logger.info("Looking for WalkingPad specifically...")
    scanner = Scanner()
    devices = await scanner.scan(timeout=5.0)

    if devices:
        device = devices[0]
        logger.info(f"Found WalkingPad: {device.name} ({device.address})")
        return device.address

    # If WalkingPad scan failed, check if any device looks like a WalkingPad
    for d in all_devices:
        name = (d.name or "").lower()
        if "walk" in name or "pad" in name or "a1" in name:
            logger.info(f"Found potential WalkingPad: {d.name} ({d.address})")
            return d.address

    raise Exception("No WalkingPad found. Make sure it's powered on and not connected to another device (like the phone app).")


async def connect_to_pad():
    """Scan for and connect to the WalkingPad."""
    global controller, device_address, connected

    try:
        # Scan for device
        device_address = await scan_for_device()

        # Create controller and connect
        logger.info(f"Connecting to {device_address}...")
        controller = WalkingPadController(device_address)
        await controller.run()
        connected = True
        logger.info("Connected to WalkingPad!")

        # Get initial status
        await controller.ask_stats()
        await asyncio.sleep(0.5)

    except Exception as e:
        logger.error(f"Failed to connect: {e}")
        connected = False
        raise


async def disconnect_from_pad():
    """Disconnect from the WalkingPad."""
    global controller, connected

    if controller:
        try:
            await controller.disconnect()
        except Exception as e:
            logger.warning(f"Error during disconnect: {e}")
        finally:
            connected = False
            controller = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage connection lifecycle."""
    await connect_to_pad()
    yield
    await disconnect_from_pad()


# Create FastAPI app
app = FastAPI(
    title="WalkingPad Bridge",
    description="Bridge server for WalkingPad control",
    version="1.0.0",
    lifespan=lifespan
)

# Allow CORS for local network access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def require_connection():
    """Check if connected to WalkingPad."""
    if not connected or not controller:
        raise HTTPException(
            status_code=400,
            detail="Not connected to WalkingPad"
        )


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "running",
        "connected": connected,
        "device": device_address
    }


@app.get("/status")
async def get_status():
    """Get current WalkingPad status."""
    require_connection()

    # Request fresh status
    await controller.ask_stats()
    await asyncio.sleep(0.3)

    status = controller.last_status
    if not status:
        raise HTTPException(
            status_code=400,
            detail="No status available"
        )

    return {
        "time": status.time,
        "distance": status.dist / 100,
        "steps": status.steps,
        "speed": status.speed / 10,
        "state": status.belt_state,
        "mode": status.manual_mode,
        "running": status.belt_state == 1
    }


@app.post("/start")
async def start():
    """Start the WalkingPad belt."""
    require_connection()

    logger.info("Starting belt...")
    await controller.switch_mode(WalkingPad.MODE_MANUAL)
    await asyncio.sleep(0.2)
    await controller.start_belt()

    return {"status": "started"}


@app.post("/stop")
async def stop():
    """Stop the WalkingPad belt."""
    require_connection()

    logger.info("Stopping belt...")
    await controller.stop_belt()

    return {"status": "stopped"}


@app.post("/speed/{value}")
async def set_speed(value: int):
    """
    Set the WalkingPad speed.

    Args:
        value: Speed as integer (5-60), representing 0.5-6.0 km/h
               Multiply km/h by 10 to get the value.
    """
    require_connection()

    if value < 5 or value > 60:
        raise HTTPException(
            status_code=400,
            detail="Speed must be between 5 and 60 (0.5 - 6.0 km/h)"
        )

    logger.info(f"Setting speed to {value / 10} km/h")
    await controller.change_speed(value)

    return {"status": "speed_set", "speed": value / 10}


@app.post("/reconnect")
async def reconnect():
    """Reconnect to the WalkingPad."""
    global connected

    logger.info("Reconnecting...")
    await disconnect_from_pad()
    await connect_to_pad()

    return {"status": "reconnected", "connected": connected}


if __name__ == "__main__":
    import uvicorn

    print("\n" + "=" * 50)
    print("  WalkingPad Bridge Server")
    print("=" * 50)
    print("\nMake sure your WalkingPad is powered on!")
    print("The server will scan for it automatically.\n")

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
