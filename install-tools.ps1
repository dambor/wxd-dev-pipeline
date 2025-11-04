# PowerShell script to install Docker/Podman, Minikube, and Helm on Windows

# Default values
$ContainerEngine = "docker"
$MinikubeDriver = ""
$MinikubeMemory = "4096"
$MinikubeCPUs = "2"
$InstallHelm = "yes"
$KubernetesVersion = "v1.26.3"

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Host "This script requires administrator privileges. Please run PowerShell as administrator." -ForegroundColor Red
    exit 1
}

# Function to get user input
function Get-UserInput {
    Write-Host "Please provide the following information:" -ForegroundColor Yellow
    
    # Container engine selection
    Write-Host "Which container engine would you like to install?" -ForegroundColor Cyan
    Write-Host "1. Docker Desktop"
    Write-Host "2. Podman Desktop"
    Write-Host "3. Skip (already installed)"
    
    $engineChoice = Read-Host "Enter your choice (1-3)"
    
    switch ($engineChoice) {
        "1" { $script:ContainerEngine = "docker" }
        "2" { $script:ContainerEngine = "podman" }
        "3" { $script:ContainerEngine = "skip" }
        default {
            Write-Host "Invalid selection. Defaulting to Docker." -ForegroundColor Red
            $script:ContainerEngine = "docker"
        }
    }
    
    # Minikube driver selection
    Write-Host "Which driver would you like to use for Minikube?" -ForegroundColor Cyan
    Write-Host "1. Docker"
    Write-Host "2. Podman"
    Write-Host "3. Hyper-V"
    Write-Host "4. VirtualBox"
    Write-Host "5. None (auto-detect)"
    
    $driverChoice = Read-Host "Enter your choice (1-5)"
    
    switch ($driverChoice) {
        "1" { $script:MinikubeDriver = "docker" }
        "2" { $script:MinikubeDriver = "podman" }
        "3" { $script:MinikubeDriver = "hyperv" }
        "4" { $script:MinikubeDriver = "virtualbox" }
        "5" { $script:MinikubeDriver = "" }
        default {
            Write-Host "Invalid selection. Will auto-detect driver." -ForegroundColor Yellow
            $script:MinikubeDriver = ""
        }
    }
    
    # Minikube configuration
    $inputMemory = Read-Host "Enter Minikube memory allocation in MB (default: 4096)"
    if ($inputMemory) {
        $script:MinikubeMemory = $inputMemory
    }
    
    $inputCPUs = Read-Host "Enter Minikube CPU allocation (default: 2)"
    if ($inputCPUs) {
        $script:MinikubeCPUs = $inputCPUs
    }
    
    # Kubernetes version
    $inputK8sVersion = Read-Host "Enter Kubernetes version (default: v1.26.3)"
    if ($inputK8sVersion) {
        $script:KubernetesVersion = $inputK8sVersion
    }
    
    # Helm installation
    $inputHelm = Read-Host "Install Helm? (yes/no, default: yes)"
    if ($inputHelm) {
        $script:InstallHelm = $inputHelm.ToLower()
    }
}

# Function to install Chocolatey
function Install-Chocolatey {
    Write-Host "Installing Chocolatey package manager..." -ForegroundColor Green
    
    # Check if Chocolatey is already installed
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Chocolatey is already installed. Skipping installation." -ForegroundColor Yellow
        return
    }
    
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    Write-Host "Chocolatey has been installed successfully!" -ForegroundColor Green
}

# Function to install Docker Desktop
function Install-DockerDesktop {
    Write-Host "Installing Docker Desktop..." -ForegroundColor Green
    
    # Check if Docker is already installed
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "Docker is already installed. Skipping installation." -ForegroundColor Yellow
        return
    }
    
    # Install Docker Desktop using Chocolatey
    choco install docker-desktop -y
    
    Write-Host "Docker Desktop has been installed successfully!" -ForegroundColor Green
    Write-Host "Please restart your computer to complete the Docker installation." -ForegroundColor Yellow
}

# Function to install Podman Desktop
function Install-PodmanDesktop {
    Write-Host "Installing Podman Desktop..." -ForegroundColor Green
    
    # Check if Podman is already installed
    if (Get-Command podman -ErrorAction SilentlyContinue) {
        Write-Host "Podman is already installed. Skipping installation." -ForegroundColor Yellow
        return
    }
    
    # Install Podman Desktop using Chocolatey
    choco install podman-desktop -y
    
    Write-Host "Podman Desktop has been installed successfully!" -ForegroundColor Green
}

# Function to install Minikube
function Install-Minikube {
    Write-Host "Installing Minikube..." -ForegroundColor Green
    
    # Check if Minikube is already installed
    if (Get-Command minikube -ErrorAction SilentlyContinue) {
        Write-Host "Minikube is already installed. Skipping installation." -ForegroundColor Yellow
        return
    }
    
    # Install Minikube using Chocolatey
    choco install minikube -y
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    Write-Host "Minikube has been installed successfully!" -ForegroundColor Green
}

# Function to install Helm
function Install-HelmChart {
    Write-Host "Installing Helm..." -ForegroundColor Green
    
    # Check if Helm is already installed
    if (Get-Command helm -ErrorAction SilentlyContinue) {
        Write-Host "Helm is already installed. Skipping installation." -ForegroundColor Yellow
        return
    }
    
    # Install Helm using Chocolatey
    choco install kubernetes-helm -y
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    Write-Host "Helm has been installed successfully!" -ForegroundColor Green
}

# Function to start Minikube
function Start-MinikubeCluster {
    Write-Host "Starting Minikube..." -ForegroundColor Green
    
    # If no driver was selected, determine the best one
    if (-not $MinikubeDriver) {
        Write-Host "No driver specified, auto-detecting..." -ForegroundColor Yellow
        
        # Try to detect the best driver based on what's available
        if (Get-Command docker -ErrorAction SilentlyContinue) {
            $MinikubeDriver = "docker"
            Write-Host "Selected driver: docker" -ForegroundColor Cyan
        } elseif (Get-Command podman -ErrorAction SilentlyContinue) {
            $MinikubeDriver = "podman"
            Write-Host "Selected driver: podman" -ForegroundColor Cyan
        } elseif ((Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online).State -eq 'Enabled') {
            $MinikubeDriver = "hyperv"
            Write-Host "Selected driver: hyperv" -ForegroundColor Cyan
        } elseif (Get-Command VBoxManage -ErrorAction SilentlyContinue) {
            $MinikubeDriver = "virtualbox"
            Write-Host "Selected driver: virtualbox" -ForegroundColor Cyan
        } else {
            Write-Host "No suitable driver found for Minikube." -ForegroundColor Red
            Write-Host "Please install Docker, Podman, Hyper-V, or VirtualBox." -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Install additional dependencies based on the selected driver
    switch ($MinikubeDriver) {
        "hyperv" {
            Write-Host "Checking Hyper-V status..." -ForegroundColor Cyan
            $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
            if ($hyperv.State -ne 'Enabled') {
                Write-Host "Hyper-V is not enabled. Enabling Hyper-V..." -ForegroundColor Yellow
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
                Write-Host "Hyper-V has been enabled. Please restart your computer and run this script again." -ForegroundColor Yellow
                exit 0
            }
        }
        "virtualbox" {
            Write-Host "Checking VirtualBox installation..." -ForegroundColor Cyan
            if (-not (Get-Command VBoxManage -ErrorAction SilentlyContinue)) {
                Write-Host "VirtualBox is not installed. Installing VirtualBox..." -ForegroundColor Yellow
                choco install virtualbox -y
            }
        }
    }
    
    # Start Minikube with the specified configuration
    Write-Host "Starting Minikube with driver: $MinikubeDriver" -ForegroundColor Cyan
    minikube start --driver=$MinikubeDriver --memory=$MinikubeMemory --cpus=$MinikubeCPUs --kubernetes-version=$KubernetesVersion
    
    Write-Host "Minikube has been started successfully!" -ForegroundColor Green
}

# Function to set up environment variables
function Set-EnvironmentVariables {
    Write-Host "Setting up environment variables..." -ForegroundColor Green
    
    # Set environment variables
    [Environment]::SetEnvironmentVariable("MINIKUBE_HOME", "$env:USERPROFILE\.minikube", "User")
    [Environment]::SetEnvironmentVariable("KUBECONFIG", "$env:USERPROFILE\.kube\config", "User")
    
    # Create a PowerShell profile script to set up the environment
    $profileContent = @"
# Minikube environment variables
`$env:MINIKUBE_HOME = "`$env:USERPROFILE\.minikube"
`$env:KUBECONFIG = "`$env:USERPROFILE\.kube\config"

# Set Docker/Podman environment variables
if (Get-Command minikube -ErrorAction SilentlyContinue) {
    & minikube docker-env | Invoke-Expression
}

Write-Host "Kubernetes environment variables have been set." -ForegroundColor Green
"@
    
    # Save the profile script
    $profilePath = "$env:USERPROFILE\minikube-env.ps1"
    $profileContent | Out-File -FilePath $profilePath -Encoding utf8
    
    Write-Host "Environment variables have been set up successfully!" -ForegroundColor Green
    Write-Host "To load the environment variables, run: . $profilePath" -ForegroundColor Yellow
}

# Main function
function Main {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Container Engine & Minikube Installer  " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # Get user input
    Get-UserInput
    
    # Install Chocolatey
    Install-Chocolatey
    
    # Install the selected container engine
    if ($ContainerEngine -eq "docker") {
        Install-DockerDesktop
    } elseif ($ContainerEngine -eq "podman") {
        Install-PodmanDesktop
    }
    
    # Install Minikube
    Install-Minikube
    
    # Install Helm if requested
    if ($InstallHelm -eq "yes") {
        Install-HelmChart
    }
    
    # Start Minikube
    Start-MinikubeCluster
    
    # Set up environment variables
    Set-EnvironmentVariables
    
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "To start using Minikube, run: . $env:USERPROFILE\minikube-env.ps1" -ForegroundColor Yellow
}

# Run the main function
Main

# Made with Bob
