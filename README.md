# Terraform Deployment for Tyk Stack with Enterprise Portal

This repository contains Terraform configurations to deploy the **Tyk Stack**, including the **Enterprise Portal**, using Helm charts. The configuration is set up to run with **Docker Desktop** as the Kubernetes provider, allowing easy local testing and development.

## Prerequisites

Before starting, ensure the following tools and setups are configured on your local machine:

- **Terraform**: [Download and install Terraform](https://www.terraform.io/downloads) for your OS.
- **Helm**: [Install Helm](https://helm.sh/docs/intro/install/) to manage Kubernetes applications.
- **Docker Desktop**: Ensure Docker Desktop is installed, with the **Kubernetes** feature enabled. This setup uses Docker Desktop’s Kubernetes cluster as the provider.
- **Tyk License**: Update Tyk dashboard and EDP license in the values.yaml file.

## Getting Started

### 1. Clone the Repository
Clone this repository to your local machine:

```bash
git clone https://github.com/mhuaco/Tyk-Terraform-EDP.git

cd Tyk-Terraform-EDP
```

### 2. Initialize Terraform

Run the following command to initialize the Terraform workspace. This will download the necessary provider plugins and set up the working directory for Terraform.

```bash
terraform init
```

### 3. Update values.yaml file with Tyk-dashboard and EDP license

### 4. Apply the Configuration
Use the following command to deploy the Tyk Stack and Enterprise Portal:

```bash
terraform apply
```

### 5. Verify the Deployment
You can check the status of your Tyk deployment by running:

```bash

kubectl get pods -n tyk
```

# Bringing Down the Infrastructure
To bring down the deployed Tyk infrastructure, use the following command:

```bash

terraform destroy
```
***Warning: terraform destroy will delete all infrastructure and associated data. Be sure to back up any important data before proceeding.***

You will be prompted to confirm this action. Type yes to proceed.
