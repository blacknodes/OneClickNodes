#!/bin/bash

# Function to display the animated text
display_text() {
    # Install Ruby and RubyGems if not already installed
    if ! command -v gem &> /dev/null; then
        echo "RubyGems (gem) is not installed. Installing Ruby..."
        sudo apt-get update
        sudo apt-get install -y ruby-full || { echo "Failed to install Ruby"; exit 1; }
    fi

    # Install figlet if not already installed
    if ! command -v figlet &> /dev/null; then
        echo "Installing figlet..."
        sudo apt-get install -y figlet || { echo "Failed to install figlet"; exit 1; }
    fi

    # Install lolcat using gem if not already installed
    if ! command -v lolcat &> /dev/null; then
        echo "Installing lolcat..."
        sudo gem install lolcat || { echo "Failed to install lolcat"; exit 1; }
    fi

    # Display the animated text
    figlet "DORA Installation By BlackNodes" | lolcat
}

# Displaying the animated text
display_text

# Predefined Variables
PASSPHRASE="yourSecurePassphrase"  # Change this to your desired passphrase
WALLET_NAME="default_wallet"       # Change this if you want a different wallet name

# Update and Install Dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev expect -y

# Install Golang
ver="1.20.5"
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version

# Verifying Golang Installation
if ! command -v go &> /dev/null
then
    echo "Golang could not be installed"
    exit 1
fi

# Clone Dora Vota and Install
cd \$HOME
git clone https://github.com/DoraFactory/doravota.git
cd doravota
git checkout 0.2.0
make install

# Check if dorad is installed
if ! command -v dorad &> /dev/null
then
    echo "Dorad could not be installed"
    exit 1
fi

# Create Wallet with Expect
expect -c "
spawn dorad keys add $WALLET_NAME
expect \"Enter keyring passphrase:\"
send \"$PASSPHRASE\\r\"
expect \"Re-enter keyring passphrase:\"
send \"$PASSPHRASE\\r\"
expect eof
" > keys.json

# Set Validator Name
echo "Enter your Validator Name:"
read VALIDATOR_NAME
dorad init \$VALIDATOR_NAME --chain-id vota-vk
dorad config chain-id vota-vk

# Download Genesis and Addrbook Files
wget -O $HOME/.dora/config/genesis.json "https://raw.githubusercontent.com/blacknodes/DoraBlockchain/main/genesis.json"
wget -O $HOME/.dora/config/addrbook.json "https://raw.githubusercontent.com/blacknodes/DoraBlockchain/main/addrbook.json"

# Create a Service File
sudo tee /etc/systemd/system/dorad.service > /dev/null <<EOF
[Unit]
Description=dorad
After=network-online.target

[Service]
User=$USER
ExecStart=$(which dorad) start
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Start Dora Node as Service
sudo systemctl daemon-reload
sudo systemctl enable dorad
sudo systemctl restart dorad
