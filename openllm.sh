#!/bin/bash

# Configuration handling
init_config() {
    CONFIG_FILE="$(dirname "$0")/config.sh"
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        MODELS_DIR="$(dirname "$0")/models"
        GPU_DEFAULT="0,1"
        VLLM_BACKEND="openllm"
        PORT_DEFAULT="8000"
    fi
    mkdir -p "$MODELS_DIR"
}

# Model management functions
get_model_pid() {
    local full_path="$1"
    local model_dir="${full_path/\//_}"
    if [ -f "$MODELS_DIR/$model_dir.pid" ]; then
        cat "$MODELS_DIR/$model_dir.pid"
    fi
}

# Function to show detailed status of all models
show_status() {
    log_message "INFO" "Model Status:"
    
    if [ -z "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
        echo "  No models found in $MODELS_DIR"
        return
    fi
    
    printf "  %-30s %-10s %-15s %s\n" "MODEL" "STATUS" "PID" "PORT"
    printf "  %-30s %-10s %-15s %s\n" "-----" "------" "---" "----"
    
    for model in "$MODELS_DIR"/*; do
        if [ -d "$model" ]; then
            model_name=$(basename "$model")
            if is_model_running "$model_name"; then
                pid=$(get_model_pid "$model_name")
                port=$(ps -p $pid -o args= | grep -o "\-\-port [0-9]*" | awk '{print $2}')
                if [ -z "$port" ]; then
                    port="$PORT_DEFAULT"
                fi
                printf "  %-30s %-10s %-15s %s\n" "$model_name" "RUNNING" "$pid" "$port"
            else
                printf "  %-30s %-10s %-15s %s\n" "$model_name" "STOPPED" "-" "-"
            fi
        fi
    done
}

# Function to list all local models
list_models() {
    log_message "INFO" "Available local models:"
    
    if [ -z "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
        echo "  No models found in $MODELS_DIR"
        return
    fi
    
    for model in "$MODELS_DIR"/*; do
        if [ -d "$model" ]; then
            model_name=$(basename "$model")
            if is_model_running "$model_name"; then
                echo "  - $model_name (RUNNING)"
            else
                echo "  - $model_name"
            fi
        fi
    done
}

# Function to display usage information
usage() {
    echo "OpenLLM and vLLM Management Script"
    echo "Usage:"
    echo "  ./openllm.sh pull <model_name>         # Download a model"
    echo "  ./openllm.sh list                      # List all local models"
    echo "  ./openllm.sh remove <model_name>       # Remove a model"
    echo "  ./openllm.sh run <model_name> [OPTIONS]  # Run a model"
    echo "  ./openllm.sh stop <model_name>         # Stop a running model"
    echo "  ./openllm.sh stop_all                  # Stop all running models"
    echo "  ./openllm.sh status                    # Show status of all models"
    echo ""
    echo "Options for run command:"
    echo "  --gpu <gpu_indices>  # Specify GPU indices (e.g., 0 or 0,1)"
    echo "                       # Default: $GPU_DEFAULT"
    echo "  --port <port>        # Specify API port"
    echo "                       # Default: $PORT_DEFAULT"
    echo "  --backend <backend>  # Specify backend (vllm, transformers)"
    echo "                       # Default: vllm"
    exit 1
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}

# Function to check if a model exists
check_model_exists() {
    local full_path="$1"
    # First check with slashes
    if [ -d "$MODELS_DIR/$full_path" ]; then
        return 0
    fi
    # Then check with underscores
    local model_dir="${full_path/\//_}"
    if [ -d "$MODELS_DIR/$model_dir" ]; then
        return 0
    fi
    log_message "ERROR" "Model '$full_path' not found in $MODELS_DIR"
    log_message "INFO" "Use './openllm.sh list' to see available models"
    return 1
}

# Function to check if a model is running
is_model_running() {
    local full_path="$1"
    local model_dir="${full_path/\//_}"
    if [ -f "$MODELS_DIR/$model_dir.pid" ]; then
        local pid=$(cat "$MODELS_DIR/$model_dir.pid")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$MODELS_DIR/$model_dir.pid"
        fi
    fi
    return 1
}

# Function to run a model
run_model() {
    local model_name="$1"
    local gpu_indices="$2"
    local port="$3"
    local backend="$4"
    
    # Check if model exists
    if ! check_model_exists "$model_name"; then
        exit 1
    fi
    
    # Check if model is already running
    if is_model_running "$model_name"; then
        log_message "ERROR" "Model '$model_name' is already running"
        log_message "INFO" "To stop it, use './openllm.sh stop $model_name'"
        exit 1
    fi
    
    # Set CUDA_VISIBLE_DEVICES environment variable
    export CUDA_VISIBLE_DEVICES="$gpu_indices"
    
    log_message "INFO" "Starting model: $model_name"
    log_message "INFO" "GPU(s): $gpu_indices, Port: $port, Backend: $backend"
    
    # Run the model with specified backend
    nohup openllm start falcon-40b \
        --model-name "tiiuae/falcon-40b" \
        --model-path "$MODELS_DIR/$model_name" \
        --backend "$backend" \
        --device cuda \
        --gpu "$gpu_indices" \
        --port "$port" > "$MODELS_DIR/${model_name/\//_}.log" 2>&1 &
    
    # Store the PID and wait briefly to check if process started
    local pid=$!
    echo $pid > "$MODELS_DIR/${model_name/\//_}.pid"
    
    # Wait briefly to check if process is still running
    sleep 5
    if ! ps -p $pid > /dev/null 2>&1; then
        log_message "ERROR" "Process failed to start. Check logs:"
        tail -n 20 "$MODELS_DIR/${model_name/\//_}.log"
        rm -f "$MODELS_DIR/${model_name/\//_}.pid"
        exit 1
    fi
    
    log_message "SUCCESS" "Model '$model_name' started successfully"
    log_message "INFO" "API available at: http://localhost:$port/docs"
    log_message "INFO" "Log file: $MODELS_DIR/${model_name/\//_}.log"
}

# Function to stop a running model
stop_model() {
    local model_name="$1"
    
    # Check if model exists
    if ! check_model_exists "$model_name"; then
        exit 1
    fi
    
    # Check if model is running
    if ! is_model_running "$model_name"; then
        log_message "ERROR" "Model '$model_name' is not running"
        exit 1
    fi
    
    # Get the PID and kill the process
    local pid=$(get_model_pid "$model_name")
    if [ -n "$pid" ]; then
        log_message "INFO" "Stopping model: $model_name (PID: $pid)"
        kill "$pid"
        rm -f "$MODELS_DIR/$model_name.pid"
        log_message "SUCCESS" "Model '$model_name' stopped successfully"
    else
        log_message "ERROR" "Could not find process for model '$model_name'"
    fi
}

# Function to stop all running models
stop_all_models() {
    log_message "INFO" "Stopping all running models..."
    
    local found=0
    for model in "$MODELS_DIR"/*; do
        if [ -d "$model" ]; then
            model_name=$(basename "$model")
            if is_model_running "$model_name"; then
                stop_model "$model_name"
                found=1
            fi
        fi
    done
    
    if [ $found -eq 0 ]; then
        log_message "INFO" "No running models found"
    else
        log_message "SUCCESS" "All models stopped successfully"
    fi
}

# Function to handle run command and its arguments
handle_run_command() {
    if [ $# -lt 1 ]; then
        log_message "ERROR" "Model name required"
        usage
    fi
    
    model_name="$1"
    shift
    
    # Default values
    gpu_indices="$GPU_DEFAULT"
    port="$PORT_DEFAULT"
    backend="vllm"
    
    # Parse additional arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --gpu)
                if [ $# -lt 2 ]; then
                    log_message "ERROR" "--gpu option requires GPU indices"
                    usage
                fi
                gpu_indices="$2"
                shift 2
                ;;
            --port)
                if [ $# -lt 2 ]; then
                    log_message "ERROR" "--port option requires port number"
                    usage
                fi
                port="$2"
                shift 2
                ;;
            --backend)
                if [ $# -lt 2 ]; then
                    log_message "ERROR" "--backend option requires backend name"
                    usage
                fi
                backend="$2"
                shift 2
                ;;
            *)
                log_message "ERROR" "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    run_model "$model_name" "$gpu_indices" "$port" "$backend"
}

# Main script logic
# Main execution
main() {
    init_config
    
    if [ $# -lt 1 ]; then
        usage
    fi

    command="$1"
    shift

    case "$command" in
        pull)    [ $# -lt 1 ] && { log_message "ERROR" "Model name required"; usage; }; pull_model "$1" ;;
        list)    list_models ;;
        status)  show_status ;;
        remove)  [ $# -lt 1 ] && { log_message "ERROR" "Model name required"; usage; }; remove_model "$1" ;;
        run)     handle_run_command "$@" ;;
        stop)    [ $# -lt 1 ] && { log_message "ERROR" "Model name required"; usage; }; stop_model "$1" ;;
        stop_all) stop_all_models ;;
        *)       log_message "ERROR" "Unknown command: $command"; usage ;;
    esac
}

# Run the script
main "$@"

exit 0