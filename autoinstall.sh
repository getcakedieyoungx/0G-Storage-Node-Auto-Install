#!/bin/bash

# Function to display the menu
show_menu() {
    # Display logo
    curl -s https://raw.githubusercontent.com/getcakedieyoungx/Assister-Bot/refs/heads/main/logo.sh | bash

    # Personalized greeting
    
    echo "1. Install 0G Storage Node"
    echo "2. Start Node"
    echo "3. Stop Node"
    echo "4. Check Node Status"
    echo "5. Check Logs"
    echo "6. Uninstall Node"
    echo "7. Exit"
    echo "8. Update RPC Endpoint (default: https://evmrpc-testnet.0g.ai)"
    echo -e "\033[1;32m     (Don't be a clown, already too many of them)\033[0m"
}

# Function to install the 0G Storage Node
install_node() {
    set -e  # Stop script on first error
    cp ~/.bashrc ~/.bashrc.bak
    echo "Installing 0G Storage Node..."
    sudo apt-get update && sudo apt-get install -y clang cmake build-essential pkg-config libssl-dev curl git jq
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    
    cd $HOME
    latest_tag=$(curl -s https://api.github.com/repos/0glabs/0g-storage-node/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
    git clone -b "$latest_tag" https://github.com/0glabs/0g-storage-node.git || { echo "Failed to clone repository"; exit 1; }
    git clone https://github.com/0glabs/0g-storage-contracts.git || { echo "Failed to clone contracts repository"; exit 1; }
    
    cd 0g-storage-node || { echo "Directory not found"; exit 1; }
    mkdir -p run/log
    cargo build --release || { echo "Cargo build failed"; exit 1; }
    
    cd run || exit 1
    
    # Download the log_config file
    if [ ! -f "log_config" ]; then
        wget https://raw.githubusercontent.com/0glabs/0g-storage-node/main/log_config -O log_config
    fi

    if [ ! -f "config-testnet-turbo.toml" ]; then
        wget https://docs.0g.ai/config-testnet-turbo.toml -O config-testnet-turbo.toml
    fi
    
    cp config-testnet-turbo.toml config.toml
    sed -i 's|blockchain_rpc_endpoint = ""|blockchain_rpc_endpoint = "https://evmrpc-testnet.0g.ai"|' config.toml
    sed -i 's|log_sync_start_block_number = 0|log_sync_start_block_number = 940000|' config.toml
    
    printf '\033[34mEnter your private key: \033[0m' && read -s PRIVATE_KEY
    echo
    sed -i 's|^\s*#\?\s*miner_key\s*=.*|miner_key = "'"$PRIVATE_KEY"'"|' $HOME/0g-storage-node/run/config-testnet-turbo.toml && echo -e "\033[32mPrivate key has been successfully added to the config file.\033[0m"
    
    # Create .env file with default blockchain RPC endpoint
    cat <<EOF > $HOME/0g-storage-node/run/.env
ZGS_NODE__MINER_KEY=$PRIVATE_KEY
ZGS_NODE__BLOCKCHAIN_RPC_ENDPOINT=https://evmrpc-testnet.0g.ai
EOF

    # Add aliases
    echo "alias zgs-logs='tail -f \$HOME/0g-storage-node/run/log/zgs.log.\$(date +%F)'" >> ~/.bashrc
    echo "alias zgs='$HOME/0g-storage-node/run/zgs.sh'" >> ~/.bashrc
    export PATH=$HOME/0g-storage-node/run:$PATH
    chmod +x $HOME/0g-storage-node/run/zgs.sh
    source ~/.bashrc
    hash -r

    # Setup systemd service for start and stop
    echo "Setting up systemd service for ZGS Node..."
    sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config-testnet-turbo.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
}

# Function to start the node using systemd
start_node() {
    echo "Starting 0G Storage Node using systemd..."
    sudo systemctl start zgs
    sudo systemctl status zgs --no-pager
}

# Function to stop the node using systemd
stop_node() {
    echo "Stopping 0G Storage Node using systemd..."
    sudo systemctl stop zgs
    echo "Node stopped."
}

# Function to check logs
check_log() {
    echo "Checking 0G Storage Node log..."
    tail -f $HOME/0g-storage-node/run/log/zgs.log.$(date +%F)
}

# Function to uninstall the node
uninstall_node() {
    echo "Uninstalling 0G Storage Node..."
    cp ~/.bashrc.bak ~/.bashrc
    rm -rf $HOME/0g-storage-node $HOME/0g-storage-contracts
    sudo rm /etc/systemd/system/zgs.service
    sudo systemctl daemon-reload
    source ~/.bashrc
    hash -r
    echo "0G Storage Node successfully uninstalled."
}

# Function to check status
check_status() {
    echo "Checking Status 0G Storage Node..."
    sudo systemctl status zgs --no-pager
}

# Function to update RPC Endpoint
update_rpc() {
    echo "=== Updating RPC Endpoint to https://evmrpc-testnet.0g.ai ==="
    CONFIG_FILE="$HOME/0g-storage-node/run/config-testnet-turbo.toml"
    ENV_FILE="$HOME/0g-storage-node/run/.env"

    # Update config-testnet-turbo.toml
    if [ -f "$CONFIG_FILE" ]; then
        sed -i 's|^blockchain_rpc_endpoint = ".*"|blockchain_rpc_endpoint = "https://evmrpc-testnet.0g.ai"|' "$CONFIG_FILE"
        echo "Updated $CONFIG_FILE"
    else
        echo "File $CONFIG_FILE not found, skipping..."
    fi

    # Update .env
    if [ -f "$ENV_FILE" ]; then
        sed -i 's|^ZGS_NODE__BLOCKCHAIN_RPC_ENDPOINT=.*|ZGS_NODE__BLOCKCHAIN_RPC_ENDPOINT=https://evmrpc-testnet.0g.ai|' "$ENV_FILE"
        echo "Updated $ENV_FILE"
    else
        echo "File $ENV_FILE not found, skipping..."
    fi

    # Restart service
    echo "Restarting ZGS Node..."
    sudo systemctl restart zgs
    sudo systemctl status zgs --no-pager
    echo "=== RPC Endpoint update completed ==="
}

# Run menu
while true; do 
    show_menu
    read -p "Please enter your choice: " choice
    case $choice in
        1) install_node ;;
        2) start_node ;;
        3) stop_node ;;
        4) check_status ;;
        5) check_log ;;
        6) uninstall_node ;;
        7) echo "Exiting..."; exit 0 ;;
        8) update_rpc ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    read -p "Press Enter to continue..." </dev/tty
done
