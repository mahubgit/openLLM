#!/bin/bash
MODELS_DIR="$(dirname "$0")/models"
GPU_DEFAULT="0,1"
VLLM_BACKEND="python -m openllm"  # Correction de la commande
PORT_DEFAULT="8000"

# Activate virtual environment if it exists
if [ -d "$(dirname "$0")/venv" ]; then
    source "$(dirname "$0")/venv/bin/activate"
fi