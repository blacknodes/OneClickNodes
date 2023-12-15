#!/bin/bash

# Function to install prerequisites
install_prerequisites() {
    echo "Installing prerequisites: Docker, Docker Compose, Git, and Node.js..."

    # Install Node.js
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs

    # Install Docker
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh

    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Install Git
    sudo apt-get install -y git

    echo "Prerequisites installed."
}

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
    figlet "Subsquid Installation By BlackNodes" | lolcat
}


# Function to install Subsquid CLI and set up a Snapshot Squid
install_subsquid() {
    # ... (The content of the install_subsquid function)
# Install Subsquid CLI
npm install --global @subsquid/cli@latest

# Verify the installation
sqd --version

# Ask the user for a unique squid name
read -p "Enter a unique name for your squid: " squid_name

# Initialize the squid with the user-defined name
sqd init "$squid_name" -t https://github.com/subsquid-quests/snapshot-squid

# Change directory to the newly created squid folder
cd "$squid_name" || { echo "Failed to enter directory $squid_name"; exit 1; }

# Ask the user for the key and save it
echo "Please paste your snapshot.key content. It will be hidden as you paste:"
read -rs key_content
mkdir -p ./query-gateway/keys
echo "$key_content" > ./query-gateway/keys/snapshot.key
echo # New line for clean output after hidden input
# Prepare the squid
npm ci
sqd build
sqd migration:apply

# Start the squid
sqd run .

}

# Function to install Mirovia worker
install_mirovia_worker() {
    # ... (The content of the install_mirovia_worker function)
# Configuration
DATA_DIR="./blockdata" # The directory where the data will be stored

# Prompt for the user's private key
read -sp "Enter your wallet private key: " WALLET_PRIVATE_KEY
echo # Newline for clean output

# Create the blockdata directory for the setup
mkdir -p "${DATA_DIR}"
echo "Data directory '${DATA_DIR}' created."

# Save the run_worker.sh script
cat > run_worker.sh << 'EOF'
#!/usr/bin/env sh

docker compose --version >/dev/null || (echo "Docker compose not installed"; exit 1)

if [ ! -d "$1" ]
then
    echo "Provided data directory ($1) does not exist. Usage: $0 <DATA_DIR> <DOCKER_COMPOSE_ARGS>"
    exit 1
fi

# Get absolute path
DATA_DIR="$(cd "$(dirname -- "$1")" >/dev/null; pwd -P)/$(basename -- "$1")"
echo "Using data dir $DATA_DIR"
shift

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

cat <<EOF > docker-compose.yml
version: "3.8"

services:

  rpc_node:
    image: subsquid/rpc-node:0.1.6
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
    image: subsquid/p2p-worker:0.1.6
    environment:
      PROXY_ADDR: rpc_node:50051
      SCHEDULER_ID: 12D3KooWQER7HEpwsvqSzqzaiV36d3Bn6DZrnwEunnzS76pgZkMU
      LOGS_COLLECTOR_ID: 12D3KooWC3GvQVqnvPwWz23sTW8G8HVokMnox62A7mnL9wwaSujk
      AWS_ACCESS_KEY_ID: 66dfc7705583f6fd9520947ac10d7e9f
      AWS_SECRET_ACCESS_KEY: a68fdd7253232e30720a4c125f35a81bd495664a154b1643b5f5d4a4a5280a4f
      AWS_S3_ENDPOINT: https://7a28e49ec5f4a60c66f216392792ac38.r2.cloudflarestorage.com
      AWS_REGION: auto
      SENTRY_DSN: https://3d427b41736042ae85010ec2dc864f05@o1149243.ingest.sentry.io/4505589334081536
      RPC_URL: https://arbitrum-goerli.publicnode.com/
      MAX_GET_LOG_BLOCKS: 49000
    volumes:
      - ${DATA_DIR}:/app/data
    ports:
      - "${PROMETHEUS_PORT:-9090}:9090"
    user: "${USER_ID}:${GROUP_ID}"
    deploy:
      resources:
        limits:
          memory: 16G

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
}

# Clear the screen
clear

# Install prerequisites before proceeding
install_prerequisites

# Display the animated text right after installing prerequisites
display_text

# Main menu for user selection
echo "Choose an installation option:"
echo "1 - Deploy a Snapshot Squid"
echo "2 - Mirovia Worker Installation"
echo "3 - Install Both"
read -p "Enter your choice (1/2/3): " user_choice

# Handle the user's choice
case $user_choice in
    1)
        install_subsquid
        ;;
    2)
        install_mirovia_worker
        ;;
    3)
        install_subsquid
        install_mirovia_worker
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "Installation process complete."
