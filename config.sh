#!/bin/bash

# OpenLLM Configuration
export MODELS_DIR="$(dirname "$0")/models"
export GPU_DEFAULT="0,1"
export VLLM_BACKEND="openllm"
export PORT_DEFAULT="8000"

# Activate virtual environment if it exists
if [ -d "$(dirname "$0")/venv" ]; then
    source "$(dirname "$0")/venv/bin/activate"
fi