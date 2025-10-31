# Judge0 Azure VM Deployment Guide

This guide walks you through deploying Judge0 to an Azure Linux VM from your Windows development environment.

## Prerequisites

### Azure VM Requirements
- **OS**: Ubuntu 22.04 LTS (recommended)
- **Minimum**: 2 vCPUs, 4GB RAM
- **Recommended**: 4 vCPUs, 8GB RAM (for better performance)
- **Storage**: 20GB minimum
- **Network**: Allow inbound traffic on port 2358

### On Your Azure VM
Create an Azure VM with Ubuntu 22.04 LTS and ensure you can SSH into it.

## Deployment Steps

### Step 1: Prepare Files on Windows (Already Done!)

The following files are already configured:
- ✅ `judge0.conf` - Configured with secure passwords
- ✅ `docker-compose.yml` - Ready to use
- ✅ `deploy-azure.sh` - Deployment script

### Step 2: Transfer Files to Azure VM

You have several options:

#### Option A: Using Git (Recommended)
```bash
# On your Windows machine
cd C:\Users\steve\OneDrive\Code\myClaude\tooling\judge0
git add .
git commit -m "Configure Judge0 for Azure deployment"
git push

# On your Azure VM
ssh your-username@your-vm-ip
git clone <your-repo-url>
cd judge0
```

#### Option B: Using SCP from Windows (PowerShell)
```powershell
# From Windows PowerShell
scp -r C:\Users\steve\OneDrive\Code\myClaude\tooling\judge0 username@your-vm-ip:/home/username/
```

#### Option C: Using WinSCP or FileZilla
Download WinSCP or FileZilla and transfer the entire `judge0` folder to your Azure VM.

### Step 3: Run the Deployment Script on Azure VM

SSH into your Azure VM and run:

```bash
# SSH into your VM
ssh your-username@your-vm-ip

# Navigate to the judge0 directory
cd ~/judge0  # adjust path if different

# Make the deployment script executable
chmod +x deploy-azure.sh

# Run the deployment script with sudo
sudo ./deploy-azure.sh
```

**Important**: The script will update GRUB settings. You **MUST reboot** after the script completes.

### Step 4: Reboot the VM

```bash
sudo reboot
```

Wait a minute for the VM to restart, then SSH back in.

### Step 5: Deploy Judge0 with Docker

```bash
# SSH back into your VM
ssh your-username@your-vm-ip

# Navigate to Judge0 directory
cd /opt/judge0  # or ~/judge0 depending on where you placed files

# Copy your files if using /opt/judge0
sudo cp ~/judge0/* /opt/judge0/

# Start database and Redis first
sudo docker compose up -d db redis

# Wait for them to initialize
sleep 10

# Start all services
sudo docker compose up -d

# Wait a moment for services to start
sleep 5

# Check that everything is running
sudo docker compose ps
```

### Step 6: Verify Deployment

1. **Check service status**:
```bash
sudo docker compose ps
```

You should see 4 services running:
- `server` (Judge0 API server)
- `worker` (Judge0 worker)
- `db` (PostgreSQL)
- `redis` (Redis)

2. **Check logs** (if needed):
```bash
sudo docker compose logs server
sudo docker compose logs worker
```

3. **Access Judge0 API**:
Open your browser and visit:
```
http://<YOUR-VM-PUBLIC-IP>:2358/docs
```

You should see the Judge0 API documentation.

4. **Test with a simple request**:
```bash
curl http://localhost:2358/languages
```

## Configuration Details

### Configured Passwords
The `judge0.conf` file has been configured with secure randomly-generated passwords for:
- Redis: `REDIS_PASSWORD` (already set)
- PostgreSQL: `POSTGRES_PASSWORD` (already set)

**Important**: Keep your `judge0.conf` file secure as it contains sensitive credentials.

### Ports
- **2358**: Judge0 API (HTTP)

### Azure Network Security Group
Make sure your Azure VM's Network Security Group allows inbound traffic on port 2358:

1. Go to Azure Portal → Your VM → Networking
2. Add inbound port rule:
   - Port: 2358
   - Protocol: TCP
   - Action: Allow

## Post-Deployment

### Accessing Judge0
- API Documentation: `http://<YOUR-VM-IP>:2358/docs`
- API Base URL: `http://<YOUR-VM-IP>:2358`

### Monitoring
Check logs:
```bash
cd /opt/judge0
sudo docker compose logs -f
```

### Stopping Services
```bash
sudo docker compose down
```

### Restarting Services
```bash
sudo docker compose restart
```

## Security Considerations

### 1. Enable HTTPS (Recommended for Production)
For production use, you should enable HTTPS. Judge0 provides docker-compose configurations with Let's Encrypt.

### 2. Authentication
Consider enabling authentication by setting these in `judge0.conf`:
```
AUTHN_HEADER=X-Auth-Token
AUTHN_TOKEN=<your-secret-token>
```

### 3. Firewall
Limit access to port 2358 to only trusted IP addresses in your Azure NSG.

### 4. Regular Updates
Keep Docker images updated:
```bash
sudo docker compose pull
sudo docker compose up -d
```

## Troubleshooting

### Services not starting
```bash
sudo docker compose logs
```

### Port already in use
```bash
sudo lsof -i :2358
```

### Out of memory
Increase your VM size in Azure Portal.

### Cannot connect to API
- Check Azure NSG allows port 2358
- Check firewall: `sudo ufw status`
- Verify services are running: `sudo docker compose ps`

## Next Steps

1. **Test the API**: Use the `/docs` endpoint to test submissions
2. **Set up monitoring**: Consider Azure Monitor or custom logging
3. **Configure backups**: Set up regular backups for the PostgreSQL database
4. **Optimize**: Adjust worker count and resource limits in `judge0.conf`

## Support

- [Judge0 GitHub](https://github.com/judge0/judge0)
- [Judge0 Discord](https://discord.gg/GRc3v6n)
- [Judge0 Documentation](https://ce.judge0.com)

## File Reference

Key files in this deployment:
- `docker-compose.yml` - Docker services configuration
- `judge0.conf` - Judge0 configuration (contains passwords)
- `deploy-azure.sh` - Azure VM setup script
- `AZURE_DEPLOYMENT.md` - This file
