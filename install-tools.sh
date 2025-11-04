#!/bin/bash

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONTAINER_ENGINE="docker"
MINIKUBE_MEMORY="4096"
MINIKUBE_CPUS="2"
MINIKUBE_DRIVER=""
INSTALL_HELM="yes"
KUBERNETES_VERSION="v1.26.3"

# Function to detect OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    echo -e "${BLUE}Detected Linux operating system${NC}"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    echo -e "${BLUE}Detected macOS operating system${NC}"
  elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
    echo -e "${BLUE}Detected Windows operating system${NC}"
  else
    echo -e "${RED}Unsupported operating system: $OSTYPE${NC}"
    exit 1
  fi
}

# Function to get user input
get_user_input() {
  echo -e "${YELLOW}Please provide the following information:${NC}"
  
  # Container engine selection
  echo -e "${BLUE}Which container engine would you like to install?${NC}"
  select engine in "Docker" "Podman" "Skip (already installed)"; do
    case $engine in
      "Docker")
        CONTAINER_ENGINE="docker"
        break
        ;;
      "Podman")
        CONTAINER_ENGINE="podman"
        break
        ;;
      "Skip (already installed)")
        CONTAINER_ENGINE="skip"
        break
        ;;
      *)
        echo -e "${RED}Invalid selection. Please try again.${NC}"
        ;;
    esac
  done
  
  # Minikube driver selection
  echo -e "${BLUE}Which driver would you like to use for Minikube?${NC}"
  
  # Available drivers depend on the OS
  if [[ "$OS" == "linux" ]]; then
    select driver in "Docker" "Podman" "KVM" "VirtualBox" "None (auto-detect)"; do
      case $driver in
        "Docker")
          MINIKUBE_DRIVER="docker"
          break
          ;;
        "Podman")
          MINIKUBE_DRIVER="podman"
          break
          ;;
        "KVM")
          MINIKUBE_DRIVER="kvm2"
          break
          ;;
        "VirtualBox")
          MINIKUBE_DRIVER="virtualbox"
          break
          ;;
        "None (auto-detect)")
          MINIKUBE_DRIVER=""
          break
          ;;
        *)
          echo -e "${RED}Invalid selection. Please try again.${NC}"
          ;;
      esac
    done
  elif [[ "$OS" == "macos" ]]; then
    select driver in "Docker" "Podman" "Hyperkit" "VirtualBox" "None (auto-detect)"; do
      case $driver in
        "Docker")
          MINIKUBE_DRIVER="docker"
          break
          ;;
        "Podman")
          MINIKUBE_DRIVER="podman"
          break
          ;;
        "Hyperkit")
          MINIKUBE_DRIVER="hyperkit"
          break
          ;;
        "VirtualBox")
          MINIKUBE_DRIVER="virtualbox"
          break
          ;;
        "None (auto-detect)")
          MINIKUBE_DRIVER=""
          break
          ;;
        *)
          echo -e "${RED}Invalid selection. Please try again.${NC}"
          ;;
      esac
    done
  elif [[ "$OS" == "windows" ]]; then
    select driver in "Docker" "Podman" "Hyper-V" "VirtualBox" "None (auto-detect)"; do
      case $driver in
        "Docker")
          MINIKUBE_DRIVER="docker"
          break
          ;;
        "Podman")
          MINIKUBE_DRIVER="podman"
          break
          ;;
        "Hyper-V")
          MINIKUBE_DRIVER="hyperv"
          break
          ;;
        "VirtualBox")
          MINIKUBE_DRIVER="virtualbox"
          break
          ;;
        "None (auto-detect)")
          MINIKUBE_DRIVER=""
          break
          ;;
        *)
          echo -e "${RED}Invalid selection. Please try again.${NC}"
          ;;
      esac
    done
  fi
  
  # Minikube configuration
  echo -e "${BLUE}Enter Minikube memory allocation in MB (default: 4096):${NC}"
  read -r input_memory
  if [[ -n "$input_memory" ]]; then
    MINIKUBE_MEMORY=$input_memory
  fi
  
  echo -e "${BLUE}Enter Minikube CPU allocation (default: 2):${NC}"
  read -r input_cpus
  if [[ -n "$input_cpus" ]]; then
    MINIKUBE_CPUS=$input_cpus
  fi
  
  # Kubernetes version
  echo -e "${BLUE}Enter Kubernetes version (default: v1.26.3):${NC}"
  read -r input_k8s_version
  if [[ -n "$input_k8s_version" ]]; then
    KUBERNETES_VERSION=$input_k8s_version
  fi
  
  # Helm installation
  echo -e "${BLUE}Install Helm? (yes/no, default: yes):${NC}"
  read -r input_helm
  if [[ -n "$input_helm" ]]; then
    INSTALL_HELM=$input_helm
  fi
}

# Function to install Docker on Linux
install_docker_linux() {
  echo -e "${GREEN}Installing Docker on Linux...${NC}"
  
  # Check if Docker is already installed
  if command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker is already installed. Skipping installation.${NC}"
    return
  fi
  
  # Update package lists
  sudo apt-get update
  
  # Install dependencies
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
  
  # Add Docker's official GPG key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  
  # Set up the stable repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Install Docker Engine
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  
  # Add user to the docker group
  sudo usermod -aG docker "$USER"
  
  echo -e "${GREEN}Docker has been installed successfully!${NC}"
  echo -e "${YELLOW}You may need to log out and log back in for group changes to take effect.${NC}"
}

# Function to install Podman on Linux
install_podman_linux() {
  echo -e "${GREEN}Installing Podman on Linux...${NC}"
  
  # Check if Podman is already installed
  if command -v podman &> /dev/null; then
    echo -e "${YELLOW}Podman is already installed. Skipping installation.${NC}"
    return
  fi
  
  # Update package lists
  sudo apt-get update
  
  # Install Podman
  sudo apt-get install -y podman
  
  echo -e "${GREEN}Podman has been installed successfully!${NC}"
}

# Function to install Docker on macOS
install_docker_macos() {
  echo -e "${GREEN}Installing Docker on macOS...${NC}"
  
  # Check if Docker is already installed
  if command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker is already installed. Skipping installation.${NC}"
    return
  fi
  
  # Check if Homebrew is installed
  if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew is not installed. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  
  # Install Docker Desktop
  brew install --cask docker
  
  echo -e "${GREEN}Docker has been installed successfully!${NC}"
  echo -e "${YELLOW}Please start Docker Desktop from your Applications folder.${NC}"
}

# Function to install Podman on macOS
install_podman_macos() {
  echo -e "${GREEN}Installing Podman on macOS...${NC}"
  
  # Check if Podman is already installed
  if command -v podman &> /dev/null; then
    echo -e "${YELLOW}Podman is already installed. Checking machine status...${NC}"
    
    # Check if Podman machine exists
    if podman machine list | grep -q "podman-machine-default"; then
      # Check if machine is running
      if ! podman machine list | grep -q "Currently running"; then
        echo -e "${YELLOW}Podman machine exists but is not running. Starting it now...${NC}"
        # Use retry logic for starting
        local max_attempts=3
        local attempt=1
        local success=false
        
        while [[ $attempt -le $max_attempts && $success == false ]]; do
          echo -e "${YELLOW}Attempt $attempt of $max_attempts to start Podman machine...${NC}"
          
          if podman machine start; then
            success=true
            echo -e "${GREEN}Podman machine started successfully.${NC}"
          else
            echo -e "${RED}Attempt $attempt failed. Retrying in 5 seconds...${NC}"
            sleep 5
            attempt=$((attempt + 1))
          fi
        done
        
        if [[ $success == false ]]; then
          echo -e "${RED}Failed to start Podman machine after $max_attempts attempts.${NC}"
          echo -e "${YELLOW}Attempting to reinitialize the Podman machine...${NC}"
          initialize_podman_machine
        fi
      else
        echo -e "${GREEN}Podman machine is already running.${NC}"
      fi
      
      # Check if we need to adjust Podman machine resources
      configure_podman_machine_resources
    else
      echo -e "${YELLOW}Initializing Podman machine with appropriate resources...${NC}"
      # Use our robust initialization function
      initialize_podman_machine
    fi
    
    return
  fi
  
  # Check if Homebrew is installed
  if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew is not installed. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  
  # Install Podman
  brew install podman
  
  # Initialize and start Podman machine with appropriate resources
  echo -e "${YELLOW}Initializing and starting Podman machine with appropriate resources...${NC}"
  initialize_podman_machine
  
  echo -e "${GREEN}Podman has been installed successfully!${NC}"
}

# Function to configure Podman machine resources
configure_podman_machine_resources() {
  echo -e "${YELLOW}Checking Podman machine resources...${NC}"
  
  # Check if podman machine info works
  if ! podman machine info &>/dev/null; then
    echo -e "${RED}Cannot get Podman machine info. The machine may not be running properly.${NC}"
    echo -e "${YELLOW}Attempting to fix Podman machine...${NC}"
    initialize_podman_machine
    return
  fi
  
  # Get current Podman memory
  PODMAN_MEMORY=$(podman machine info | grep MemTotal | awk '{print $2}')
  PODMAN_MEMORY_MB=$((PODMAN_MEMORY / 1024 / 1024))
  
  # Check if Podman has enough memory for Minikube
  if [[ $PODMAN_MEMORY_MB -lt $((MINIKUBE_MEMORY + 200)) ]]; then
    echo -e "${YELLOW}Podman machine has only ${PODMAN_MEMORY_MB}MB memory but Minikube needs at least ${MINIKUBE_MEMORY}MB.${NC}"
    echo -e "${YELLOW}Would you like to recreate the Podman machine with more memory? (y/n)${NC}"
    read -r recreate_machine
    
    if [[ "$recreate_machine" == "y" ]]; then
      initialize_podman_machine
    else
      echo -e "${YELLOW}Continuing with current Podman machine. Minikube memory will be adjusted.${NC}"
    fi
  else
    echo -e "${GREEN}Podman machine has sufficient memory (${PODMAN_MEMORY_MB}MB).${NC}"
  fi
}

# Function to initialize or reinitialize Podman machine with retry logic
initialize_podman_machine() {
  # Stop and remove existing machine if it exists
  if podman machine list | grep -q "podman-machine-default"; then
    echo -e "${YELLOW}Stopping and removing current Podman machine...${NC}"
    podman machine stop podman-machine-default 2>/dev/null || true
    podman machine rm -f podman-machine-default 2>/dev/null || true
  fi
  
  echo -e "${YELLOW}Creating new Podman machine with ${MINIKUBE_MEMORY}MB memory...${NC}"
  
  # Try initialization with retry logic
  local max_attempts=3
  local attempt=1
  local success=false
  
  while [[ $attempt -le $max_attempts && $success == false ]]; do
    echo -e "${YELLOW}Attempt $attempt of $max_attempts to initialize Podman machine...${NC}"
    
    if podman machine init --memory=$((MINIKUBE_MEMORY + 500))m --cpus=$MINIKUBE_CPUS; then
      success=true
    else
      echo -e "${RED}Attempt $attempt failed. Retrying in 5 seconds...${NC}"
      sleep 5
      attempt=$((attempt + 1))
    fi
  done
  
  if [[ $success == false ]]; then
    echo -e "${RED}Failed to initialize Podman machine after $max_attempts attempts.${NC}"
    echo -e "${YELLOW}Trying with default settings...${NC}"
    podman machine init || {
      echo -e "${RED}Failed to initialize Podman machine with default settings.${NC}"
      echo -e "${RED}Please check your network connection and try again later.${NC}"
      exit 1
    }
  fi
  
  # Start the machine with retry logic
  echo -e "${YELLOW}Starting Podman machine...${NC}"
  attempt=1
  success=false
  
  while [[ $attempt -le $max_attempts && $success == false ]]; do
    echo -e "${YELLOW}Attempt $attempt of $max_attempts to start Podman machine...${NC}"
    
    if podman machine start; then
      success=true
      echo -e "${GREEN}Podman machine started successfully.${NC}"
    else
      echo -e "${RED}Attempt $attempt failed. Retrying in 5 seconds...${NC}"
      sleep 5
      attempt=$((attempt + 1))
    fi
  done
  
  if [[ $success == false ]]; then
    echo -e "${RED}Failed to start Podman machine after $max_attempts attempts.${NC}"
    echo -e "${RED}Please check your network connection and try again later.${NC}"
    exit 1
  fi
}

# Function to install Docker on Windows
install_docker_windows() {
  echo -e "${GREEN}Installing Docker on Windows...${NC}"
  echo -e "${YELLOW}For Windows, we recommend installing Docker Desktop manually.${NC}"
  echo -e "${YELLOW}Please download Docker Desktop from: https://www.docker.com/products/docker-desktop${NC}"
  echo -e "${YELLOW}After installation, please restart this script and select 'Skip (already installed)' for the container engine.${NC}"
}

# Function to install Podman on Windows
install_podman_windows() {
  echo -e "${GREEN}Installing Podman on Windows...${NC}"
  echo -e "${YELLOW}For Windows, we recommend installing Podman Desktop manually.${NC}"
  echo -e "${YELLOW}Please download Podman Desktop from: https://podman-desktop.io/downloads${NC}"
  echo -e "${YELLOW}After installation, please restart this script and select 'Skip (already installed)' for the container engine.${NC}"
}

# Function to install Minikube
install_minikube() {
  echo -e "${GREEN}Installing Minikube...${NC}"
  
  # Check if Minikube is already installed
  if command -v minikube &> /dev/null; then
    echo -e "${YELLOW}Minikube is already installed. Skipping installation.${NC}"
    return
  fi
  
  case $OS in
    "linux")
      # Download Minikube binary
      curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
      sudo install minikube-linux-amd64 /usr/local/bin/minikube
      rm minikube-linux-amd64
      ;;
    "macos")
      # Install Minikube via Homebrew
      brew install minikube
      ;;
    "windows")
      echo -e "${YELLOW}For Windows, we recommend installing Minikube manually.${NC}"
      echo -e "${YELLOW}Please download Minikube from: https://minikube.sigs.k8s.io/docs/start/${NC}"
      echo -e "${YELLOW}After installation, please restart this script.${NC}"
      return
      ;;
  esac
  
  echo -e "${GREEN}Minikube has been installed successfully!${NC}"
}

# Function to install Helm
install_helm() {
  echo -e "${GREEN}Installing Helm...${NC}"
  
  # Check if Helm is already installed
  if command -v helm &> /dev/null; then
    echo -e "${YELLOW}Helm is already installed. Skipping installation.${NC}"
    return
  fi
  
  case $OS in
    "linux")
      # Download and install Helm
      curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
      chmod 700 get_helm.sh
      ./get_helm.sh
      rm get_helm.sh
      ;;
    "macos")
      # Install Helm via Homebrew
      brew install helm
      ;;
    "windows")
      echo -e "${YELLOW}For Windows, we recommend installing Helm manually.${NC}"
      echo -e "${YELLOW}Please download Helm from: https://helm.sh/docs/intro/install/${NC}"
      echo -e "${YELLOW}After installation, please restart this script.${NC}"
      return
      ;;
  esac
  
  echo -e "${GREEN}Helm has been installed successfully!${NC}"
}

# Function to start Minikube
start_minikube() {
  echo -e "${GREEN}Starting Minikube...${NC}"
  
  # If no driver was selected, determine the best one
  if [[ -z "$MINIKUBE_DRIVER" ]]; then
    echo -e "${YELLOW}No driver specified, auto-detecting...${NC}"
    
    # Try to detect the best driver based on what's available
    if command -v docker &> /dev/null; then
      MINIKUBE_DRIVER="docker"
      echo -e "${BLUE}Selected driver: docker${NC}"
    elif command -v podman &> /dev/null; then
      MINIKUBE_DRIVER="podman"
      echo -e "${BLUE}Selected driver: podman${NC}"
    elif [[ "$OS" == "linux" ]] && command -v virsh &> /dev/null; then
      MINIKUBE_DRIVER="kvm2"
      echo -e "${BLUE}Selected driver: kvm2${NC}"
    elif [[ "$OS" == "macos" ]] && command -v hyperkit &> /dev/null; then
      MINIKUBE_DRIVER="hyperkit"
      echo -e "${BLUE}Selected driver: hyperkit${NC}"
    elif command -v VBoxManage &> /dev/null; then
      MINIKUBE_DRIVER="virtualbox"
      echo -e "${BLUE}Selected driver: virtualbox${NC}"
    else
      echo -e "${RED}No suitable driver found for Minikube.${NC}"
      echo -e "${YELLOW}Please install Docker, Podman, VirtualBox, or another supported virtualization system.${NC}"
      exit 1
    fi
  fi
  
  # Install additional dependencies based on the selected driver
  case $MINIKUBE_DRIVER in
    "kvm2")
      if [[ "$OS" == "linux" ]]; then
        echo -e "${BLUE}Installing KVM dependencies...${NC}"
        sudo apt-get update
        sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
        sudo usermod -aG libvirt "$USER"
        sudo systemctl enable libvirtd
        sudo systemctl start libvirtd
      fi
      ;;
    "hyperkit")
      if [[ "$OS" == "macos" ]]; then
        echo -e "${BLUE}Installing hyperkit...${NC}"
        brew install hyperkit
      fi
      ;;
    "virtualbox")
      if [[ "$OS" == "linux" ]]; then
        echo -e "${BLUE}Installing VirtualBox...${NC}"
        sudo apt-get update
        sudo apt-get install -y virtualbox
      elif [[ "$OS" == "macos" ]]; then
        echo -e "${BLUE}Installing VirtualBox...${NC}"
        brew install --cask virtualbox
      fi
      ;;
    "podman")
      echo -e "${BLUE}Checking Podman configuration before starting Minikube...${NC}"
      if [[ "$OS" == "macos" ]]; then
        # Check if Podman machine exists and is running
        if podman machine list | grep -q "podman-machine-default"; then
          if ! podman machine list | grep -q "Currently running"; then
            echo -e "${YELLOW}Podman machine exists but is not running. Starting it now...${NC}"
            podman machine start
          else
            echo -e "${GREEN}Podman machine is already running.${NC}"
          fi
        else
          echo -e "${YELLOW}Initializing Podman machine...${NC}"
          podman machine init
          podman machine start
        fi
        
        # Verify Podman connection
        echo -e "${BLUE}Verifying Podman connection...${NC}"
        if ! podman version &>/dev/null; then
          echo -e "${RED}Failed to connect to Podman. Please check your Podman installation.${NC}"
          exit 1
        fi
      fi
      ;;
  esac
  
  # Start Minikube with the specified configuration
  echo -e "${BLUE}Starting Minikube with driver: $MINIKUBE_DRIVER${NC}"
  
  # For Podman driver, we need to ensure the machine is running and explicitly specify the driver
  if [[ "$MINIKUBE_DRIVER" == "podman" ]]; then
    # Ensure Podman machine is running
    if [[ "$OS" == "macos" ]]; then
      echo -e "${YELLOW}Ensuring Podman machine is running before starting Minikube...${NC}"
      if ! podman machine list | grep -q "Currently running"; then
        echo -e "${YELLOW}Starting Podman machine...${NC}"
        podman machine start
      fi
      
      # Check Podman machine memory and adjust if needed
      echo -e "${YELLOW}Checking Podman machine memory...${NC}"
      PODMAN_MEMORY=$(podman machine info | grep MemTotal | awk '{print $2}')
      PODMAN_MEMORY_MB=$((PODMAN_MEMORY / 1024 / 1024))
      
      if [[ $PODMAN_MEMORY_MB -lt $MINIKUBE_MEMORY ]]; then
        echo -e "${YELLOW}Podman machine has only ${PODMAN_MEMORY_MB}MB memory but ${MINIKUBE_MEMORY}MB was requested.${NC}"
        echo -e "${YELLOW}Adjusting Minikube memory to ${PODMAN_MEMORY_MB}MB...${NC}"
        # Leave some buffer for the system
        MINIKUBE_MEMORY=$((PODMAN_MEMORY_MB - 200))
        echo -e "${YELLOW}Setting Minikube memory to ${MINIKUBE_MEMORY}MB${NC}"
      fi
    fi
    
    # Set Podman as the default driver
    echo -e "${BLUE}Setting Podman as the default driver for Minikube...${NC}"
    minikube config set driver podman
    
    # Start Minikube with explicit Podman driver
    echo -e "${BLUE}Starting Minikube with explicit Podman driver...${NC}"
    minikube start \
      --driver=podman \
      --memory="$MINIKUBE_MEMORY" \
      --cpus="$MINIKUBE_CPUS" \
      --kubernetes-version="$KUBERNETES_VERSION" \
      --container-runtime=cri-o
  else
    # Start Minikube with the specified driver
    minikube start \
      --driver="$MINIKUBE_DRIVER" \
      --memory="$MINIKUBE_MEMORY" \
      --cpus="$MINIKUBE_CPUS" \
      --kubernetes-version="$KUBERNETES_VERSION"
  fi
  
  echo -e "${GREEN}Minikube has been started successfully!${NC}"
}

# Function to set up environment variables
setup_environment() {
  echo -e "${GREEN}Setting up environment variables...${NC}"
  
  # Create a file with environment variables
  cat > minikube-env.sh << EOF
#!/bin/bash

# Minikube environment variables
export MINIKUBE_HOME="$HOME/.minikube"
export KUBECONFIG="$HOME/.kube/config"
export KUBE_CONFIG_PATH="$HOME/.kube/config"

# Set Docker/Podman environment variables
if command -v minikube &> /dev/null; then
  eval \$(minikube docker-env)
fi

# Path to Minikube binary
if [[ -d "/usr/local/bin" ]]; then
  export PATH="/usr/local/bin:\$PATH"
fi

echo "Kubernetes environment variables have been set."
EOF
  
  chmod +x minikube-env.sh
  
  echo -e "${GREEN}Environment variables have been set up successfully!${NC}"
  echo -e "${YELLOW}To load the environment variables, run: source minikube-env.sh${NC}"
}

# Main function
main() {
  echo -e "${BLUE}=========================================${NC}"
  echo -e "${BLUE}  Container Engine & Minikube Installer  ${NC}"
  echo -e "${BLUE}=========================================${NC}"
  
  # Detect the operating system
  detect_os
  
  # Get user input
  get_user_input
  
  # Install the selected container engine
  if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
    case $OS in
      "linux")
        install_docker_linux
        ;;
      "macos")
        install_docker_macos
        ;;
      "windows")
        install_docker_windows
        ;;
    esac
  elif [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    case $OS in
      "linux")
        install_podman_linux
        ;;
      "macos")
        install_podman_macos
        ;;
      "windows")
        install_podman_windows
        ;;
    esac
  fi
  
  # Install Minikube
  install_minikube
  
  # Install Helm if requested
  if [[ "$INSTALL_HELM" == "yes" ]]; then
    install_helm
  fi
  
  # Start Minikube
  start_minikube
  
  # Set up environment variables
  setup_environment
  
  echo -e "${GREEN}Installation completed successfully!${NC}"
  echo -e "${YELLOW}To start using Minikube, run: source minikube-env.sh${NC}"
}

# Run the main function
main

# Made with Bob
