# OpenLLM Management System

A management system for running and managing OpenLLM and vLLM models.

## Installation

1. Clone this repository
2. Run the installation script:
```bash
./install_openllm.sh
```

openllm\
├── config.sh          # System configuration
├── install_openllm.sh # Installation script
├── openllm.sh        # Main management script
├── models/           # Models storage
│   ├── model1/      # Individual model directory
│   │   ├── model.bin
│   │   └── model.log
│   └── model2/
└── README.md         # Documentation

Model Management
# Download a model
./openllm.sh pull <model_name>

# List all installed models
./openllm.sh list

# Remove a model
./openllm.sh remove <model_name>

Model Execution
# Run a model with default GPUs (0,1)
./openllm.sh run <model_name>

# Run a model on specific GPU
./openllm.sh run <model_name> --gpu 0

# Run a model on multiple GPUs
./openllm.sh run <model_name> --gpu 0,1

Process Control
# Stop a specific running model
./openllm.sh stop <model_name>

# Stop all running models
./openllm.sh stop_all

## Configuration Details
### System Configuration (config.sh)
# Default configuration values
MODELS_DIR="./models"     # Models storage directory
GPU_DEFAULT="0,1"        # Default GPU indices
VLLM_BACKEND="openllm"   # Backend system
PORT_DEFAULT="8000"      # API port