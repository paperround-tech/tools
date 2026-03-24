#!/bin/bash

# Portal Database SSH Tunnels - Unix Shell Version
# SSM relay ports (no SSH key needed): Dev=5437, QA=5438, UAT=5439, Staging=5440, Production=5441
# SSH bastion ports:                   QA=5433,  UAT=5434, Staging=5435, Production=5436

# Configuration - Change this to your SSH key base name
SSH_KEY_BASE_NAME="bastion_key"  # Will use bastion_key_qa, bastion_key_uat, etc.
# Alternatively, use a single key for all environments:
# SSH_KEY_BASE_NAME="bastion_key_portal"  # Will use bastion_key_portal for all

# Helper function to get SSH key path
get_ssh_key_path() {
    local env=$1
    if [ "$SSH_KEY_BASE_NAME" = "bastion_key_portal" ]; then
        # Use single key for all environments
        echo "$HOME/.ssh/bastion_key_portal"
    else
        # Use environment-specific keys
        echo "$HOME/.ssh/${SSH_KEY_BASE_NAME}_${env}"
    fi
}

# Clear any existing aliases
unalias portal-qa-tunnel portal-uat-tunnel portal-staging-tunnel portal-production-tunnel portal-development-tunnel 2>/dev/null

# Start tunnel functions with background process tracking
# Clean up any existing SSH control sockets
cleanup_ssh_sockets() {
    rm -f ~/.ssh/*control* ~/.ssh/[0-9]* 2>/dev/null || true
}

# Development tunnel via SSM relay (DSY-124) — no SSH key or bastion IP required
portal-development-tunnel() {
    local relay_id
    relay_id=$(aws ssm get-parameter --region eu-west-2 \
        --name /infrastructure/development/ssm-relay/instance-id \
        --query 'Parameter.Value' --output text 2>/dev/null)
    if [ -z "$relay_id" ]; then
        echo "ERROR: Could not find SSM relay at /infrastructure/development/ssm-relay/instance-id"
        echo "Ensure DSY-124 networking stack is applied and aws sso login is active."
        return 1
    fi
    aws ssm start-session \
        --target "$relay_id" \
        --document-name PortForward-portal-development \
        --parameters '{"localPortNumber":["5437"]}' \
        --region eu-west-2 &
    echo $! > ~/.ssh/portal-development-tunnel.pid
    echo "Development tunnel started on port 5437 via SSM relay ${relay_id} (PID: $!)"
}

# UAT SSM tunnel (DSY-129) — no SSH key required, runs alongside existing portal-uat-tunnel
portal-uat-ssm-tunnel() {
    local relay_id
    relay_id=$(aws ssm get-parameter --region eu-west-2 \
        --name /infrastructure/uat/ssm-relay/instance-id \
        --query 'Parameter.Value' --output text 2>/dev/null)
    if [ -z "$relay_id" ]; then
        echo "ERROR: Could not find SSM relay at /infrastructure/uat/ssm-relay/instance-id"
        echo "Ensure DSY-129 networking stack is applied and aws sso login is active."
        return 1
    fi
    aws ssm start-session \
        --target "$relay_id" \
        --document-name PortForward-portal-uat \
        --parameters '{"localPortNumber":["5439"]}' \
        --region eu-west-2 &
    echo $! > ~/.ssh/portal-uat-ssm-tunnel.pid
    echo "UAT SSM tunnel started on port 5439 via SSM relay ${relay_id} (PID: $!)"
}

portal-qa-tunnel() {
    local keyfile=$(get_ssh_key_path "qa")
    ssh -N \
        -L 5433:portal-qa-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 \
        -o ExitOnForwardFailure=yes \
        ec2-user@35.179.170.3 \
        -i "$keyfile" & 
    echo $! > ~/.ssh/portal-qa-tunnel.pid
    echo "QA tunnel started on port 5433 (PID: $!)" 
}

portal-uat-tunnel() {
    local keyfile=$(get_ssh_key_path "uat")
    ssh -N \
        -L 5434:portal-uat-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 \
        -o ExitOnForwardFailure=yes \
        ec2-user@13.135.249.248 \
        -i "$keyfile" &
    echo $! > ~/.ssh/portal-uat-tunnel.pid
    echo "UAT tunnel started on port 5434 (PID: $!)"
}

portal-staging-tunnel() {
    local keyfile=$(get_ssh_key_path "staging")
    ssh -N \
        -L 5435:portal-staging-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 \
        -o ExitOnForwardFailure=yes \
        ec2-user@52.56.142.14 \
        -i "$keyfile" &
    echo $! > ~/.ssh/portal-staging-tunnel.pid
    echo "Staging tunnel started on port 5435 (PID: $!)"
}

portal-production-tunnel() {
    local keyfile=$(get_ssh_key_path "production")
    ssh -N \
        -L 5436:portal-production-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 \
        -o ExitOnForwardFailure=yes \
        ec2-user@18.170.58.57 \
        -i "$keyfile" &
    echo $! > ~/.ssh/portal-production-tunnel.pid
    echo "Production tunnel started on port 5436 (PID: $!)"
}

# Stop tunnel functions
portal-tunnel-stop() {
    local env=$1
    local pidfile=~/.ssh/portal-${env}-tunnel.pid
    # Map environment to port and host
    local port host
    case "$env" in
        development) port=5437; host="ssm" ;;
        qa)          port=5433; host="35.179.170.3" ;;
        uat)         port=5434; host="13.135.249.248" ;;
        staging)     port=5435; host="52.56.142.14" ;;
        production)  port=5436; host="18.170.58.57" ;;
        *) echo "Invalid environment: $env"; return 1 ;;
    esac
    if [[ -f "$pidfile" ]]; then
        pid=$(cat "$pidfile")
        if [ "$host" = "ssm" ]; then
            # SSM-based tunnel — kill by PID
            kill $pid 2>/dev/null || true
        else
            # SSH-based tunnel — kill by port and host
            for ssh_pid in $(pgrep -f "ssh.*-L ${port}:.*${host}"); do
                kill $ssh_pid 2>/dev/null || true
            done
            kill $pid 2>/dev/null || true
        fi
        rm "$pidfile"
        echo "${env} tunnel stopped"
    else
        echo "No tunnel PID file found for ${env}"
    fi
}

# Stop all tunnels
portal-tunnel-stop-all() {
    for env in development qa uat staging production; do
        portal-tunnel-stop $env
    done
}

# Start all tunnels
portal-tunnel-start-all() {
    echo "Starting all portal tunnels..."
    portal-development-tunnel
    portal-qa-tunnel
    portal-uat-tunnel
    portal-staging-tunnel
    portal-production-tunnel
    echo "All tunnels started. Use 'portal-tunnel-list' to verify status."
}

# List running tunnels
portal-tunnel-list() {
    echo "Running portal tunnels:"
    # Development (SSM-based)
    local dev_pidfile=~/.ssh/portal-development-tunnel.pid
    if [[ -f "$dev_pidfile" ]]; then
        local dev_pid; dev_pid=$(cat "$dev_pidfile")
        if kill -0 "$dev_pid" 2>/dev/null; then
            echo "development: running on port 5437 via SSM (PID: ${dev_pid})"
        else
            echo "development: process not found (stale PID file)"
            rm "$dev_pidfile"
        fi
    fi
    # SSH-based tunnels
    local port_map=(
        "qa:5433:35.179.170.3"
        "uat:5434:13.135.249.248"
        "staging:5435:52.56.142.14"
        "production:5436:18.170.58.57"
    )
    for entry in "${port_map[@]}"; do
        local env=${entry%%:*}
        local port=${entry#*:}; port=${port%%:*}
        local host=${entry##*:}
        local pidfile=~/.ssh/portal-${env}-tunnel.pid
        if [[ -f "$pidfile" ]]; then
            pid=$(cat "$pidfile")
            if pgrep -f "ssh.*-L ${port}:.*${host}" > /dev/null; then
                local proc_pid=$(pgrep -f "ssh.*-L ${port}:.*${host}" | head -n1)
                echo "${env}: running (PID: ${proc_pid})"
            else
                echo "${env}: process not found (stale PID file)"
                rm "$pidfile"
            fi
        fi
    done
}

# Help function
portal-tunnel-help() {
    cat << EOF
Portal SSH Tunnel Commands:
    portal-development-tunnel - Start Development tunnel on port 5437 (SSM relay, no SSH key)
    portal-uat-ssm-tunnel     - Start UAT SSM tunnel on port 5439 (SSM relay, no SSH key)
    portal-qa-tunnel          - Start QA tunnel on port 5433 (SSH bastion)
    portal-uat-tunnel         - Start UAT tunnel on port 5434 (SSH bastion)
    portal-staging-tunnel     - Start Staging tunnel on port 5435 (SSH bastion)
    portal-production-tunnel  - Start Production tunnel on port 5436 (SSH bastion)

    portal-tunnel-start-all   - Start all tunnels
    portal-tunnel-stop <env>  - Stop specific tunnel (development/qa/uat/staging/production)
    portal-tunnel-stop-all    - Stop all tunnels
    portal-tunnel-list        - Show tunnel status
    portal-tunnel-help        - Show this help

Configuration:
    SSH_KEY_BASE_NAME: $SSH_KEY_BASE_NAME
    
Example usage:
    portal-qa-tunnel
    portal-tunnel-list
    portal-tunnel-stop qa
EOF
}

echo "Portal SSH Tunnels loaded. Use 'portal-tunnel-help' for usage information."
