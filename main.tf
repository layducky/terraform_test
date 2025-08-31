# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 2. Virtual Network (VPC): place where subnet, NIC, VM… exist inside.
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-hello"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 3. Subnet: Là phân đoạn mạng nhỏ trong VNet (10.0.1.0/24), Nếu thiếu: NIC không có chỗ để attach → VM fail.
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-hello"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Public IP: Static IP để truy cập VM từ Internet. Nếu thiếu: VM chỉ có private IP trong VNet, unable to SSH or HTTP with Internet.
resource "azurerm_public_ip" "public_ip" {
  name                = "hello-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 5. Network Security Group: Firewall cho subnet/NIC. Nếu thiếu NSG/rules: VM vẫn chạy, nhưng từ ngoài bị chặn, bạn sẽ không SSH hay HTTP được.

# Association of NSG with NIC is recommended over Subnet. Nếu thiếu association: NSG tồn tại nhưng không áp dụng → mặc định sẽ block hết inbound.
resource "azurerm_network_security_group" "nsg" {
  name                = "hello-nsg"
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
  name                = "hello-nic"
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
  name                = "hello-vm"
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
apt-get install -y nginx
echo "<h1>Hello from Azure + Terraform</h1>" > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx
EOF
  )
}
