#!/bin/bash

INSTALL_DIR="$(pwd)"
MODELS_DIR="$INSTALL_DIR/models"

echo "===== OpenLLM Installation Script ====="

# Install system dependencies
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
  curl \
  git \
  wget \
  python3-pip \
  python3-venv

# Create directories
echo "Creating directories..."
mkdir -p "$MODELS_DIR"

# Create virtual environment
echo "Creating Python virtual environment..."
python3 -m venv "$INSTALL_DIR/venv"
source "$INSTALL_DIR/venv/bin/activate"

# Install OpenLLM
echo "Installing OpenLLM..."
pip install --upgrade pip
pip install "openllm[all]" vllm

# Create configuration file
echo "Creating default configuration..."
cat > "$INSTALL_DIR/config.sh" << EOF
#!/bin/bash

# OpenLLM Configuration
export MODELS_DIR="$MODELS_DIR"
export GPU_DEFAULT="0,1"
export VLLM_BACKEND="openllm"
export PORT_DEFAULT="8000"

# Activate virtual environment
source "$INSTALL_DIR/venv/bin/activate"
EOF

chmod +x "$INSTALL_DIR/config.sh"

echo ""
echo "===== Installation Complete ====="
echo "Configuration: $INSTALL_DIR/config.sh"
echo "Models directory: $MODELS_DIR"
echo ""
echo "To use OpenLLM:"
echo "1. Source the configuration:"
echo "   source config.sh"
echo "2. Run commands:"
echo "   ./openllm.sh <command>"