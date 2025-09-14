# Deploy Azure VM with Moodle LMS using Terraform

This project uses **Terraform** and **Azure CLI** to deploy an Ubuntu Linux VM on Microsoft Azure with **Moodle LMS** automatically installed via Docker.

The VM will be created inside a Resource Group, with Virtual Network, Subnet, Public IP, and NSG (Firewall) configured. Once deployed, the VM automatically clones the MoodleLMS_App repository and starts Moodle using Docker Compose.

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
├── main.tf          # Azure resources definition (RG, VNet, Subnet, NSG, VM...)
├── providers.tf     # Terraform provider configuration
├── variables.tf     # Input variables (location, username, ssh key...)
├── outputs.tf       # Output values (public IP)
├── terraform.tfvars # Variable values (optional)
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
   
   After 3-5 minutes, Terraform will output the **Public IP Address** of the VM.

4. **Wait for Moodle to start**
   
   The VM needs additional 2-3 minutes to:
   - Install Docker and Docker Compose
   - Clone the MoodleLMS_App repository
   - Start Moodle containers

---

## Access the VM and Moodle

### SSH Access
```bash
ssh azureuser@<PUBLIC_IP>
```

### Moodle Web Access
- Open browser: `http://<PUBLIC_IP>`
- You should see the **Moodle LMS** login/setup page

### Available Scripts on VM

After SSH-ing into the VM, you can use these scripts:

1. **Start/Restart Moodle**
   ```bash
   ./start-moodle.sh
   ```

2. **Check Moodle Status**
   ```bash
   ./check-moodle.sh
   ```
   This shows:
   - Docker container status
   - Container logs (last 20 lines)
   - System resources usage
   - Access URL

3. **Manual Docker Commands**
   ```bash
   cd ~/MoodleLMS_App
   
   # View containers
   docker-compose ps
   
   # View logs
   docker-compose logs -f
   
   # Stop Moodle
   docker-compose down
   
   # Start Moodle
   docker-compose up -d
   ```

---

## Troubleshooting

### Check VM Setup Status
```bash
ssh azureuser@<PUBLIC_IP>
sudo tail -f /var/log/vm-setup.log
```

### Check Moodle Startup Logs
```bash
ssh azureuser@<PUBLIC_IP>
sudo tail -f /var/log/moodle-startup.log
```

### If Moodle is not accessible:
1. Wait 5-10 minutes after VM creation
2. Check container status: `./check-moodle.sh`
3. Restart Moodle: `./start-moodle.sh`
4. Check firewall rules in Azure NSG (port 80 should be open)

---

## Cleanup

When you no longer need the resources:
```bash
terraform destroy -auto-approve
```
This will delete all Azure resources created by Terraform.

---

## Notes

- Default region is `Southeast Asia`. You can change it in `variables.tf`.
- Default VM size is `Standard_B1s` (free-tier eligible in some subscriptions).
- Make sure your `~/.ssh/id_rsa.pub` file exists and matches the `ssh_public_key` variable.
- The VM automatically clones from: `https://github.com/layducky/MoodleLMS_App.git`
- Moodle runs directly on port 80 (no reverse proxy needed)
- First-time Moodle setup may require additional configuration through the web interface

---

## Architecture

```
Internet → Azure Public IP → NSG (Firewall) → VM → Docker → Moodle LMS
                    ↓
              Port 80 (HTTP)
              Port 22 (SSH)
```