# SubsquidOneClickNode
This is the OneClickNode Installation Script for Subsquid Validator
# setup.sh Script
```
#!/bin/bash

# Clear the screen
clear

# Install Ruby and RubyGems if not already installed
if ! command -v gem &> /dev/null; then
    echo "RubyGems (gem) is not installed. Installing Ruby..."
    sudo apt-get update
    sudo apt-get install -y ruby-full
fi

# Check for figlet and lolcat, install if they don't exist
if ! command -v figlet &> /dev/null; then
    echo "Installing figlet..."
    sudo apt-get install figlet -y
fi

if ! command -v lolcat &> /dev/null; then
    echo "Installing lolcat..."
    sudo gem install lolcat
fi

# Display animated text
figlet "Subsquid Installation By BlackNodes" | lolcat


# Configuration
DATA_DIR="./blockdata" # The directory where the data will be stored

# Prompt for the user's private key
read -sp "Enter your wallet private key: " WALLET_PRIVATE_KEY
echo # Newline for clean output

# Install Docker if it's not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce
fi

# Install Docker Compose if it's not already installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create the blockdata directory for the setup
mkdir -p "${DATA_DIR}"
echo "Data directory '${DATA_DIR}' created."

# Save the run_worker.sh script
cat > run_worker.sh << 'EOF'
#!/usr/bin/env sh
docker compose --version >/dev/null || (echo "Docker compose not installed"; exit 1)

if [ ! -d "$1" ]; then
    echo "Provided data directory ($1) does not exist. Usage: $0 <DATA_DIR> <DOCKER_COMPOSE_ARGS>"
    exit 1
fi

# Get absolute path
DATA_DIR="$(cd "$(dirname -- "$1")" >/dev/null; pwd -P)/$(basename -- "$1")"
echo "Using data dir $DATA_DIR"
shift

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

cat <<EOFCOMPOSE > docker-compose.yml
version: "3.8"

services:

  rpc_node:
    image: subsquid/rpc-node:mirovia
    environment:
      P2P_LISTEN_ADDR: /ip4/0.0.0.0/tcp/${LISTEN_PORT:-12345}
      RPC_LISTEN_ADDR: 0.0.0.0:50051
      BOOT_NODES: >
        12D3KooWSRvKpvNbsrGbLXGFZV7GYdcrYNh4W2nipwHHMYikzV58 /dns4/testnet.subsquid.io/tcp/22345,
        12D3KooWQC9tPzj2ShLn39RFHS5SGbvbP2pEd7bJ61kSW2LwxGSB /dns4/testnet.subsquid.io/tcp/22346
      KEY_PATH: /app/data/key
    volumes:
      - ./:/app/data
    user: "${USER_ID}:${GROUP_ID}"
    ports:
      - "${LISTEN_PORT:-12345}:${LISTEN_PORT:-12345}"

  worker:
    depends_on:
      rpc_node:
        condition: service_healthy
    image: subsquid/p2p-worker:mirovia
    environment:
      PROXY_ADDR: rpc_node:50051
      SCHEDULER_ID: 12D3KooWQER7HEpwsvqSzqzaiV36d3Bn6DZrnwEunnzS76pgZkMU
      AWS_ACCESS_KEY_ID: 66dfc7705583f6fd9520947ac10d7e9f
      AWS_SECRET_ACCESS_KEY: a68fdd7253232e30720a4c125f35a81bd495664a154b1643b5f5d4a4a5280a4f
      AWS_S3_ENDPOINT: https://7a28e49ec5f4a60c66f216392792ac38.r2.cloudflarestorage.com
      AWS_REGION: auto
      SENTRY_DSN: https://3d427b41736042ae85010ec2dc864f05@o1149243.ingest.sentry.io/4505589334081536
    volumes:
      - ${DATA_DIR}:/app/data
    user: "${USER_ID}:${GROUP_ID}"
EOFCOMPOSE

exec docker compose "$@"
EOF

# Make the run_worker.sh script executable
chmod +x run_worker.sh
echo "run_worker.sh script created and made executable."

# Generate the key file (the user will handle the peer ID manually)
docker run --rm subsquid/rpc-node:mirovia keygen > key
echo "Key file generated."

# The user should manually copy the peer ID from the output

# Ask the user to enter the peer ID
read -p "Enter your peer ID: " PEER_ID

# Register the peer ID on chain
docker run --rm subsquid/worker-registration:mirovia "${PEER_ID}" "${WALLET_PRIVATE_KEY}"
echo "Peer ID registered on chain."

# Run the node
./run_worker.sh "${DATA_DIR}" up -d
echo "Validator node setup initiated."

echo "Validator node setup complete."
```
# Save The Above Script As setup.sh
```
sudo nano setup.sh
```
# Giving Permission To The File
```
sudo chmod +x setup.sh
```
# Running The Script
```
./setup.sh
```
## Press Enter on all the interfaces and paste your `private key` and `peer_id` accordingly where it is needed.
### If you pasted right details then the Node will be up successfully.
