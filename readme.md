# Deploy Azure VM with Terraform

This project uses **Terraform** and **Azure CLI** to deploy an Ubuntu Linux VM on Microsoft Azure.  
The VM will be created inside a Resource Group, with Virtual Network, Subnet, Public IP, and NSG (Firewall) configured.  
Once deployed, the VM automatically installs **Nginx** and serves a sample "Hello" page.

---

## Prerequisites

1. **Login to Azure**
   ```bash
   az login
   ```
   This will open a browser for authentication.

2. **Set the correct subscription**
   ```bash
   az account set --subscription "<SUBSCRIPTION_ID>"
   ```

3. **Generate SSH Key** (if not already available)
   ```bash
   ssh-keygen -t rsa -b 4096
   ```
   By default, the key will be stored at `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`.

---

## Project Structure

```
.
├── main.tf       # Azure resources definition (RG, VNet, Subnet, NSG, VM...)
├── providers.tf  # Terraform provider configuration
├── variables.tf  # Input variables (location, username, ssh key...)
├── outputs.tf    # Output values (public IP)
```

---

## How to Deploy

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Preview deployment plan**
   ```bash
   terraform plan
   ```

3. **Apply deployment**
   ```bash
   terraform apply -auto-approve
   ```

   After a few minutes, Terraform will output the **Public IP Address** of the VM.

---

## Access the VM

- **SSH into VM**
  ```bash
  ssh azureuser@<PUBLIC_IP>
  ```

- **Check Nginx in browser**
  - Open: `http://<PUBLIC_IP>`  
  - You should see:  
    ```
    Hello from Azure + Terraform
    ```

---

## Cleanup

When you no longer need the resources:

```bash
terraform destroy -auto-approve
```

This will delete all Azure resources created by Terraform.

---

## Notes

- Default region is `East Asia`. You can change it in `variables.tf`.
- Default VM size is `Standard_B1s` (free-tier eligible in some subscriptions).
- Make sure your `~/.ssh/id_rsa.pub` file exists and matches the `ssh_public_key` variable.
```