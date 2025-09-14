# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 2. Virtual Network (VPC): place where subnet, NIC, VM… exist inside.
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-moodle"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 3. Subnet: Là phân đoạn mạng nhỏ trong VNet (10.0.1.0/24), Nếu thiếu: NIC không có chỗ để attach → VM fail.
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-moodle"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Public IP: Static IP để truy cập VM từ Internet. Nếu thiếu: VM chỉ có private IP trong VNet, unable to SSH or HTTP with Internet.
resource "azurerm_public_ip" "public_ip" {
  name                = "moodle-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 5. Network Security Group: Firewall cho subnet/NIC. Nếu thiếu NSG/rules: VM vẫn chạy, nhưng từ ngoài bị chặn, bạn sẽ không SSH hay HTTP được.

# Association of NSG with NIC is recommended over Subnet. Nếu thiếu association: NSG tồn tại nhưng không áp dụng → mặc định sẽ block hết inbound.
resource "azurerm_network_security_group" "nsg" {
  name                = "moodle-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "http" {
  name                        = "HTTP"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 6. NIC: Network Interface = card mạng cho VM. Nếu thiếu: VM không thể kết nối mạng → fail khi tạo
resource "azurerm_network_interface" "nic" {
  name                = "moodle-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# 7. VM: 
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "moodle-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(<<EOF
#!/bin/bash
apt-get update -y

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Add user to docker group
usermod -aG docker ${var.admin_username}

# Install git
apt-get install -y git

# Clone the MoodleLMS repo
cd /home/${var.admin_username}
git clone https://github.com/layducky/MoodleLMS_App.git
chown -R ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/MoodleLMS_App

# Create a simple script to start Moodle
cat > /home/${var.admin_username}/start-moodle.sh << 'SCRIPT_EOF'
#!/bin/bash
cd /home/${var.admin_username}/MoodleLMS_App

if [ -f "docker-compose.yml" ]; then
    echo "Starting Moodle with Docker Compose..."
    docker-compose up -d
    
    echo "Moodle is starting up..."
    echo "Access Moodle at: http://$(curl -s ifconfig.me)"
    echo "Checking container status..."
    docker-compose ps
else
    echo "docker-compose.yml not found!"
fi
SCRIPT_EOF

chmod +x /home/${var.admin_username}/start-moodle.sh
chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/start-moodle.sh

# Create status check script
cat > /home/${var.admin_username}/check-moodle.sh << 'CHECK_EOF'
#!/bin/bash
cd /home/${var.admin_username}/MoodleLMS_App
echo "=== Docker Container Status ==="
docker-compose ps
echo ""
echo "=== Container Logs (last 20 lines) ==="
docker-compose logs --tail=20
echo ""
echo "=== System Resources ==="
free -h
df -h
echo ""
echo "=== Access URL ==="
echo "Moodle URL: http://$(curl -s ifconfig.me)"
CHECK_EOF

chmod +x /home/${var.admin_username}/check-moodle.sh
chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/check-moodle.sh

# Log setup completion
echo "VM Setup completed at $(date)" >> /var/log/vm-setup.log

# Auto-start Moodle after system is ready
sleep 30
su - ${var.admin_username} -c "/home/${var.admin_username}/start-moodle.sh" >> /var/log/moodle-startup.log 2>&1

echo "Moodle startup initiated at $(date)" >> /var/log/vm-setup.log
EOF
  )
}
