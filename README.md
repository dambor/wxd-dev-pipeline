# Container Engine, Minikube, and Helm Installer

This repository contains scripts to automate the installation of Docker/Podman, Minikube, and Helm on different operating systems.

## Supported Operating Systems

- Linux (Ubuntu/Debian-based distributions)
- macOS
- Windows

## Prerequisites

### Linux
- Bash shell
- sudo privileges

### macOS
- Bash shell
- Homebrew (will be installed if not present)
- Docker Desktop (for Docker users) or Podman Desktop (for Podman users) will be installed by the script

### Windows
- PowerShell with administrator privileges
- Internet connection
- Docker Desktop (for Docker users) or Podman Desktop (for Podman users) will be installed by the script

## Container Engine Requirements

### Docker vs Docker Desktop
- **Linux**: Only requires Docker Engine (not Docker Desktop)
- **macOS and Windows**: Requires Docker Desktop, which includes Docker Engine and additional components needed for virtualization

### Podman vs Podman Desktop
- **Linux**: Only requires Podman CLI
- **macOS and Windows**: Requires Podman Desktop, which includes Podman CLI and additional components needed for virtualization

### Alternatives to Docker Desktop
Docker Desktop requires a paid subscription for use in larger organizations. If you prefer not to use Docker Desktop:

1. **Use Podman instead**:
   - Podman is a daemonless container engine that's compatible with Docker commands
   - The script offers Podman as an alternative to Docker

2. **Use Minikube with a different driver**:
   - On macOS: You can use the `hyperkit` or `virtualbox` driver
   - On Windows: You can use the `hyperv` or `virtualbox` driver
   - Modify the script to use these drivers instead of Docker

3. **Use Rancher Desktop**:
   - Rancher Desktop is an open-source alternative to Docker Desktop
   - It provides container management and Kubernetes in a single application
   - Install it manually before running the script and select "Skip (already installed)" for the container engine

## Installation Instructions

### Linux and macOS

1. Make the script executable:
   ```bash
   chmod +x install-tools.sh
   ```

2. Run the script:
   ```bash
   ./install-tools.sh
   ```

3. Follow the prompts to select your preferences.

4. After installation, load the environment variables:
   ```bash
   source minikube-env.sh
   ```

### Windows

1. Open PowerShell as Administrator.

2. Navigate to the directory containing the script.

3. Run the script:
   ```powershell
   .\install-tools.ps1
   ```

4. Follow the prompts to select your preferences.

5. After installation, load the environment variables:
   ```powershell
   . $env:USERPROFILE\minikube-env.ps1
   ```

## What Gets Installed

The script will install the following components based on your selections:

1. **Container Engine**:
   - Docker: Docker Engine (Linux), Docker Desktop (macOS/Windows)
   - Podman: Podman CLI (Linux), Podman Desktop (macOS/Windows)

2. **Minikube**:
   - Latest version of Minikube

3. **Helm** (optional):
   - Latest version of Helm

## Configuration Options

During installation, you can configure:

- Container engine (Docker or Podman)
- Minikube memory allocation (default: 4096MB)
- Minikube CPU allocation (default: 2 CPUs)
- Kubernetes version (default: v1.26.3)
- Whether to install Helm (default: yes)

## Environment Variables

The script creates environment variable configuration files:

- Linux/macOS: `minikube-env.sh`
- Windows: `minikube-env.ps1`

These files set up the necessary environment variables for working with Minikube and Kubernetes.

## Installing IBM Lakehouse

After setting up Minikube/Kubernetes/OpenShift and Helm, you can install IBM Lakehouse:

1. Add the Bitnami repository (required for PostgreSQL dependency):
   ```bash
   # This step is MANDATORY - the chart will not install without it
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   ```

   If you see an error like "no repository definition for https://charts.bitnami.com/bitnami", it means you need to run the commands above.

2. Create the namespace (if it doesn't exist):
   ```bash
   kubectl create namespace spark
   ```

3. Update the values.yaml file with your credentials:
   ```bash
   # Edit the values.yaml file to set your credentials
   # Replace the placeholder values for PostgreSQL passwords and Docker registry credentials
   ```

4. Set the appropriate security context settings based on your environment:
   - For Kubernetes/Minikube:
     ```bash
     # Edit values.yaml and set
     securityContext:
       enableOpenShiftSettings: false
     ```
   - For OpenShift:
     ```bash
     # Edit values.yaml and set
     securityContext:
       enableOpenShiftSettings: true
     ```

5. For OpenShift environments, patch the default service account to use the correct pull secrets:
   ```bash
   # Add pull secrets to the default service account
   kubectl patch serviceaccount default -n spark -p '{"imagePullSecrets": [{"name": "docker-pull-secret"}, {"name": "icr-pull"}, {"name": "jfrog-pull"}]}'
   ```

6. Install or upgrade the chart:
   
   For a new installation:
   ```bash
   helm install wxd . --namespace spark
   ```

   For upgrading an existing installation:
   ```bash
   helm upgrade wxd . --namespace spark
   ```

   Alternatively, you can use the `--create-namespace` flag to have Helm create the namespace for you:
   ```bash
   helm install wxd . --namespace spark --create-namespace
   ```

   If you encounter errors about pull secrets already existing, you can set the useExisting flag:
   ```bash
   helm install wxd . --namespace spark --set imagePullSecrets.dockerPullSecret.useExisting=true --set imagePullSecrets.icrPull.useExisting=true --set imagePullSecrets.jfrogPull.useExisting=true
   ```

   You can also override values during installation or upgrade:
   ```bash
   helm install wxd . --namespace spark --set postgresql.auth.password=mypassword --set wxdPostgresql.auth.password=myotherpassword
   # or for upgrade
   helm upgrade wxd . --namespace spark --set postgresql.auth.password=mypassword --set wxdPostgresql.auth.password=myotherpassword
   ```

   For OpenShift, you can set the security context settings during installation or upgrade:
   ```bash
   helm install wxd . --namespace spark --set securityContext.enableOpenShiftSettings=true
   # or for upgrade
   helm upgrade wxd . --namespace spark --set securityContext.enableOpenShiftSettings=true
   ```

   If you encounter storage issues in OpenShift with the error "no persistent volumes available for this claim and no storage class is set", you have two options:

   ### Option 1: Use the built-in custom storage class
   The chart includes a custom storage class that can be configured for your specific cloud provider:

   ```bash
   # For OpenShift on AWS
   helm install wxd . --namespace spark --set storage.provisioner=kubernetes.io/aws-ebs --set storage.parameters.type=gp2
   
   # For OpenShift on Azure
   helm install wxd . --namespace spark --set storage.provisioner=kubernetes.io/azure-disk --set storage.parameters.storageaccounttype=Premium_LRS --set storage.parameters.kind=Managed
   
   # For OpenShift on GCP
   helm install wxd . --namespace spark --set storage.provisioner=kubernetes.io/gce-pd --set storage.parameters.type=pd-standard
   
   # For OpenShift Container Storage
   helm install wxd . --namespace spark --set storage.provisioner=openshift-storage.rbd.csi.ceph.com --set storage.parameters.clusterID=openshift-storage --set storage.parameters.pool=ocs-storagecluster-cephblockpool
   ```

   ### Option 2: Specify an existing storage class
   If you prefer to use an existing storage class in your cluster:

   ```bash
   # For OpenShift on AWS
   helm install wxd . --namespace spark --set global.postgresql.primary.persistence.storageClass=gp2 --set global.wxdPostgresql.persistence.storageClass=gp2
   
   # For OpenShift on Azure
   helm install wxd . --namespace spark --set global.postgresql.primary.persistence.storageClass=managed-premium --set global.wxdPostgresql.persistence.storageClass=managed-premium
   
   # For OpenShift on GCP
   helm install wxd . --namespace spark --set global.postgresql.primary.persistence.storageClass=standard --set global.wxdPostgresql.persistence.storageClass=standard
   
   # For OpenShift Container Storage
   helm install wxd . --namespace spark --set global.postgresql.primary.persistence.storageClass=ocs-storagecluster-ceph-rbd --set global.wxdPostgresql.persistence.storageClass=ocs-storagecluster-ceph-rbd
   ```

   To find available storage classes in your OpenShift cluster:
   ```bash
   # Using kubectl
   kubectl get storageclass

   # Using oc (OpenShift CLI)
   oc get storageclass
   ```

   You can also combine install and upgrade into a single command with the `--install` flag:
   ```bash
   helm upgrade --install wxd . --namespace spark
   ```

7. To uninstall the chart:
   ```bash
   helm uninstall wxd -n spark
   ```

The chart includes the following dependencies:
- PostgreSQL databases required by IBM Lakehouse
- Docker pull secrets configuration
- Service account configuration

All these dependencies are managed automatically by the Helm chart.

## OpenShift-Specific Considerations

When deploying on OpenShift, keep the following in mind:

1. **Security Context Constraints**:
   - The chart uses conditional security context settings based on the `securityContext.enableOpenShiftSettings` value
   - When set to `true`, the pods will use user IDs compatible with OpenShift's security context constraints

2. **Routes vs Ingress**:
   - OpenShift uses Routes instead of Ingress for external access
   - The certificate generation includes DNS names for both Kubernetes services and OpenShift routes

3. **Image Pull Secrets**:
   - Make sure your image pull secrets are properly configured for OpenShift
   - The chart includes templates for creating pull secrets automatically

4. **CA Bundles**:
   - The certificate generation job checks multiple paths for CA bundles to support both Kubernetes and OpenShift environments

5. **Storage Classes**:
   - OpenShift requires specific storage classes for persistent volumes
   - The chart includes a custom storage class (`wxd-storage-class`) that can be configured for different cloud providers
   - You can configure the storage class using the `storage.*` parameters in values.yaml
   - Common OpenShift storage provisioners:
     - AWS: `kubernetes.io/aws-ebs`
     - Azure: `kubernetes.io/azure-disk`
     - GCP: `kubernetes.io/gce-pd`
     - OpenShift Container Storage: `openshift-storage.rbd.csi.ceph.com`

## Troubleshooting

### Linux

- If you encounter permission issues, make sure you have sudo privileges.
- For Docker installation issues, check if your distribution is supported.

### macOS

- If Homebrew installation fails, check your internet connection.
- For Docker Desktop, you may need to start it manually from the Applications folder.

### Windows

- Make sure you're running PowerShell as Administrator.
- If Chocolatey installation fails, check your internet connection.
- For Docker Desktop, you may need to restart your computer after installation.

### Prerequisites Installation

- If you encounter issues with the prerequisites installation, check the following:
  - Make sure Helm is installed and working correctly
  - Verify that kubectl can connect to your Kubernetes cluster
  - Check if the namespace already exists
  - Ensure you have internet access to pull the required images

## License

This project is licensed under the MIT License - see the LICENSE file for details.