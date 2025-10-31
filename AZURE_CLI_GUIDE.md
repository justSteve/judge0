# Azure CLI Guide: Connecting to Your VM for Judge0 Deployment

This guide walks you through using Azure CLI to create, configure, and connect to your Azure VM for Judge0 deployment.

## Prerequisites

### 1. Install Azure CLI (if not already installed)

**On Windows:**
```powershell
# Using Windows Package Manager
winget install -e --id Microsoft.AzureCLI

# OR download the MSI installer from:
# https://aka.ms/installazurecliwindows
```

### 2. Login to Azure

```bash
az login
```

This will open a browser window for authentication. Once logged in, you'll see your subscription info.

### 3. Set Your Subscription (if you have multiple)

```bash
# List all subscriptions
az account list --output table

# Set the active subscription
az account set --subscription "Your-Subscription-Name"
```

## Part 1: Creating Your Azure VM for Judge0

### Step 1: Create a Resource Group

```bash
az group create --name ubuntuRG --location eastus2
```

**What this does**: Creates a container for all your Azure resources in the East US 2 region.

### Step 2: Create Ubuntu 22.04 VM (UPDATED for Judge0)

**Important**: Judge0 requires Ubuntu 22.04, not SUSE. Here's the corrected command:

```bash
az vm create \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --public-ip-sku Standard \
  --admin-username azureuser \
  --generate-ssh-keys
```

**What this does**:
- Creates VM named `uJudge0` in resource group `ubuntuRG`
- Uses Ubuntu 22.04 LTS (required for Judge0)
- Size: Standard_D2s_v3 (2 vCPUs, 8GB RAM - good for Judge0)
- Creates a public IP address
- Username: `azureuser`
- Generates SSH keys automatically (saved to `~/.ssh/`)

**Output**: You'll see JSON output including the VM's public IP address. Save this!

### Step 3: Configure Network Security Group for Judge0

Judge0 needs port 2358 open for API access:

```bash
# Open port 2358 for Judge0 API
az vm open-port \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --port 2358 \
  --priority 1001

# Open port 22 for SSH (usually already open)
az vm open-port \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --port 22 \
  --priority 1000
```

**What this does**: Adds inbound security rules to allow traffic on ports 22 (SSH) and 2358 (Judge0 API).

### Step 4: Get Your VM's IP Address

```bash
az vm list-ip-addresses \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --output table
```

**Output example**:
```
VirtualMachine    PublicIPAddresses    PrivateIPAddresses
----------------  -------------------  --------------------
uJudge0           20.123.45.67         10.0.0.4
```

**Save the Public IP address** - you'll need it for SSH connection!

## Part 2: Making Your First SSH Connection

### Method 1: Direct SSH Connection (Recommended)

Once the VM is created, connect using SSH:

```bash
# Replace <PUBLIC-IP> with your VM's public IP from Step 4
ssh azureuser@<PUBLIC-IP>
```

**Example**:
```bash
ssh azureuser@20.123.45.67
```

**First Connection**: You'll see a message like:
```
The authenticity of host '20.123.45.67 (20.123.45.67)' can't be established.
ECDSA key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter.

### Method 2: SSH via Azure CLI

Alternative method using Azure CLI:

```bash
az ssh vm \
  --resource-group ubuntuRG \
  --name uJudge0
```

This uses Azure to establish the SSH connection.

### Troubleshooting SSH Connection

If SSH connection fails:

1. **Check VM is running**:
```bash
az vm get-instance-view \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --query instanceView.statuses[1] \
  --output table
```

2. **Verify SSH port is open**:
```bash
az network nsg rule list \
  --resource-group ubuntuRG \
  --nsg-name uJudge0NSG \
  --output table
```

3. **Check SSH key location**:
```bash
# On Windows, keys are typically in:
ls ~/.ssh/
# Look for: id_rsa and id_rsa.pub
```

## Part 3: Transferring Judge0 Files to VM

### Option A: Using SCP (Secure Copy)

**From Windows PowerShell or Command Prompt**:

```bash
# Transfer entire judge0 directory
scp -r "C:\Users\steve\OneDrive\Code\myClaude\tooling\judge0" azureuser@<PUBLIC-IP>:~/

# Example:
scp -r "C:\Users\steve\OneDrive\Code\myClaude\tooling\judge0" azureuser@20.123.45.67:~/
```

**Transfer individual files**:
```bash
scp "C:\Users\steve\OneDrive\Code\myClaude\tooling\judge0\judge0.conf" azureuser@<PUBLIC-IP>:~/judge0/
```

### Option B: Using Git (Recommended)

If your code is in a Git repository:

**On Windows**:
```bash
cd C:\Users\steve\OneDrive\Code\myClaude\tooling\judge0
git add .
git commit -m "Configure Judge0 for Azure deployment"
git push
```

**On Azure VM** (after SSH connection):
```bash
# Clone your repository
git clone <your-repo-url>
cd judge0
```

### Option C: Using Azure CLI File Copy

```bash
# Upload a file
az vm run-command invoke \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --command-id RunShellScript \
  --scripts @deploy-azure.sh
```

## Part 4: Deploying Judge0 on the VM

Once connected via SSH and files are transferred:

```bash
# Navigate to judge0 directory
cd ~/judge0

# Make deployment script executable
chmod +x deploy-azure.sh

# Run deployment script
sudo ./deploy-azure.sh

# Reboot (required after GRUB update)
sudo reboot
```

Wait 1-2 minutes for VM to reboot, then reconnect:

```bash
ssh azureuser@<PUBLIC-IP>
```

Start Judge0:

```bash
cd ~/judge0

# Start database and Redis first
sudo docker compose up -d db redis

# Wait 10 seconds
sleep 10

# Start all services
sudo docker compose up -d

# Check status
sudo docker compose ps
```

## Part 5: VM Management Commands

### Start the VM
```bash
az vm start --resource-group ubuntuRG --name uJudge0
```

### Stop the VM (deallocates - saves money)
```bash
az vm deallocate --resource-group ubuntuRG --name uJudge0
```

### Restart the VM
```bash
az vm restart --resource-group ubuntuRG --name uJudge0
```

### Get VM Status
```bash
az vm get-instance-view \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --query instanceView.statuses \
  --output table
```

### Delete the VM (keeps resource group)
```bash
az vm delete \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --yes \
  --no-wait
```

### Delete Everything (VM + Resource Group)
```bash
az group delete --name ubuntuRG --yes --no-wait
```

## Part 6: Verifying Judge0 Deployment

### From Your Local Machine

**Check if Judge0 API is accessible**:
```bash
# Test connection
curl http://<PUBLIC-IP>:2358/languages

# Example:
curl http://20.123.45.67:2358/languages
```

**Access API documentation in browser**:
```
http://<PUBLIC-IP>:2358/docs
```

### From the VM (via SSH)

```bash
# Check Docker containers
sudo docker compose ps

# View logs
sudo docker compose logs server
sudo docker compose logs worker

# Test locally
curl http://localhost:2358/languages
```

## Part 7: Common Tasks

### View VM Details
```bash
az vm show \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --output table
```

### Resize VM (if need more power)
```bash
# List available sizes
az vm list-sizes --location eastus2 --output table

# Resize VM
az vm resize \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --size Standard_D4s_v3
```

### Update Judge0 (pull latest images)
```bash
# SSH into VM first
ssh azureuser@<PUBLIC-IP>

# Navigate to judge0 directory
cd ~/judge0

# Pull latest images
sudo docker compose pull

# Restart with new images
sudo docker compose down
sudo docker compose up -d db redis
sleep 10
sudo docker compose up -d
```

### View Judge0 Logs in Real-Time
```bash
# SSH into VM
ssh azureuser@<PUBLIC-IP>

# Follow logs
cd ~/judge0
sudo docker compose logs -f
```

## Quick Reference: Your Commands

Based on your `vmUtils.txt`, here's a quick reference:

```bash
# Create resource group
az group create --name ubuntuRG --location eastus2

# Create VM (UPDATED for Ubuntu 22.04)
az vm create \
  --resource-group ubuntuRG \
  --name uJudge0 \
  --image Ubuntu2204 \
  --size Standard_D2s_v3 \
  --public-ip-sku Standard \
  --admin-username azureuser \
  --generate-ssh-keys

# Open Judge0 port
az vm open-port --resource-group ubuntuRG --name uJudge0 --port 2358 --priority 1001

# Get IP address
az vm list-ip-addresses --resource-group ubuntuRG --name uJudge0 --output table

# Connect via SSH
ssh azureuser@<PUBLIC-IP>

# Transfer files
scp -r "C:\Users\steve\OneDrive\Code\myClaude\tooling\judge0" azureuser@<PUBLIC-IP>:~/

# Start VM
az vm start --resource-group ubuntuRG --name uJudge0

# Stop VM
az vm deallocate --resource-group ubuntuRG --name uJudge0

# Delete VM
az vm delete --resource-group ubuntuRG --name uJudge0 --yes --no-wait

# Delete resource group
az group delete --name ubuntuRG --yes --no-wait
```

## Security Best Practices

### 1. Use SSH Key Authentication (Already Configured)
The `--generate-ssh-keys` flag creates secure SSH keys automatically.

### 2. Limit SSH Access by IP (Optional)
```bash
az network nsg rule update \
  --resource-group ubuntuRG \
  --nsg-name uJudge0NSG \
  --name default-allow-ssh \
  --source-address-prefixes <YOUR-IP-ADDRESS>
```

### 3. Keep VM Updated
```bash
# After SSH connection
sudo apt update
sudo apt upgrade -y
```

### 4. Monitor Costs
```bash
# View cost analysis
az consumption usage list --output table
```

## Troubleshooting

### Can't connect via SSH
1. Check VM is running: `az vm get-instance-view --resource-group ubuntuRG --name uJudge0`
2. Check IP address: `az vm list-ip-addresses --resource-group ubuntuRG --name uJudge0 --output table`
3. Verify SSH port is open: `az network nsg rule list --resource-group ubuntuRG --nsg-name uJudge0NSG --output table`

### Port 2358 not accessible
1. Check NSG rules: `az network nsg rule list --resource-group ubuntuRG --nsg-name uJudge0NSG --output table`
2. Check Docker: `ssh azureuser@<IP> 'sudo docker compose ps'`
3. Check firewall on VM: `ssh azureuser@<IP> 'sudo ufw status'`

### Out of disk space
```bash
# Check disk usage
ssh azureuser@<IP> 'df -h'

# Clean Docker
ssh azureuser@<IP> 'sudo docker system prune -a'
```

## Next Steps

1. ✅ Create Azure VM with Ubuntu 22.04
2. ✅ Open required ports (22, 2358)
3. ✅ Connect via SSH
4. ✅ Transfer Judge0 files
5. ✅ Run deployment script
6. ✅ Reboot VM
7. ✅ Deploy Judge0 with Docker Compose
8. ✅ Access Judge0 API at `http://<PUBLIC-IP>:2358/docs`

## Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Azure VM SSH Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys)
- [Judge0 Documentation](https://ce.judge0.com)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
