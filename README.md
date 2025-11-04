# WXD Helm Chart

This Helm chart deploys WXD (watsonx Data) on Kubernetes/OpenShift.

## Prerequisites

- Kubernetes 1.20+ or OpenShift 4.6+
- Helm 3.0+
- kubectl or oc CLI

## Installation

### 1. Update secret values

```bash
# Copy template and update with real values
cp values-secret.yaml values-secret-real.yaml
# Edit with your actual secrets
vim values-secret-real.yaml
```

### 2. Deploy with Helm

```bash
helm install wxd . \
  -f values.yaml \
  -f values-secret-real.yaml \
  --namespace wxd \
  --create-namespace
```

### 3. On OpenShift (From Git)

In OpenShift UI:
1. Developer → +Add
2. From Git
3. Enter this repo URL
4. Select branch: main
5. Click Create

## Configuration

Edit `values.yaml` for non-sensitive configurations:
- Image version
- Resource limits
- Replica count
- Storage size

Edit `values-secret.yaml` for sensitive data:
- Database credentials
- Admin password
- API keys
- TLS certificates

**WARNING**: Never commit `values-secret.yaml` to git. Use OpenShift Secrets instead.

## Upgrading

```bash
helm upgrade wxd . \
  -f values.yaml \
  -f values-secret-real.yaml \
  --namespace wxd
```

## Uninstalling

```bash
helm uninstall wxd -n wxd
```

## Access

After deployment:
- Console UI: https://wxd.apps.your-domain
- MinIO: https://minio.apps.your-domain:9001
- MDS Thrift: https://mds-thrift.apps.your-domain

## Troubleshooting

```bash
# Check pods
oc get pods -n wxd

# View logs
oc logs -n wxd deployment/wxd

# Describe deployment
oc describe deployment wxd -n wxd
```
