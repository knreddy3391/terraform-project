resource "azurerm_resource_group" "webapp_rg" {
  name     = var.rgname
  location = var.location
  tags = {
    "application" : "wehapp"
  }
}


resource "azurerm_virtual_network" "webapp_vnet" {
  name                = "webapp_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.webapp_rg.name
}

resource "azurerm_subnet" "webapp_subnet" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.webapp_rg.name
  virtual_network_name = azurerm_virtual_network.webapp_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_interface" "webapp_nic" {
  resource_group_name = azurerm_resource_group.webapp_rg.name
  name                = var.networkinterface
  location            = var.location
  ip_configuration {
    name                          = "webapp-nic"
    subnet_id                     = azurerm_subnet.webapp_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

resource "azurerm_virtual_machine" "webapp_machine" {
  name                  = var.webapp_name
  resource_group_name   = var.rgname
  location              = var.location
  network_interface_ids = [azurerm_network_interface.webapp_nic.id]
  vm_size               = "Standard_B1s"
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name = "mydisk"
    create_option     = "FromImage"
  }
  os_profile {
    computer_name  = var.webapp_name
    admin_username = "knreddy"
    admin_password = "Admin1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  connection {
    type           = "ssh"
    agent_identity = "ssh"
    user           = "knreddy"
    password       = "Admin1234!"
    host           = azurerm_public_ip.publicip.ip_address
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt install apache2 -y",
      "sudo systemctl enable --now apache2",
      "sudo echo hello world > /var/www/html/index.html",
    ]
  }
}
resource "azurerm_managed_disk" "mydisk" {
  name                 = "webapp-disk"
  location             = var.location
  resource_group_name  = azurerm_resource_group.webapp_rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "example" {
  managed_disk_id    = azurerm_managed_disk.mydisk.id
  virtual_machine_id = azurerm_virtual_machine.webapp_machine.id
  lun                = "10"
  caching            = "ReadWrite"
}


resource "azurerm_public_ip" "publicip" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.webapp_rg.name
  location            = var.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}
resource "azurerm_network_security_group" "webapp_nsg" {
  name                = "acceptanceTestSecurityGroup1"
  location            = var.location
  resource_group_name = azurerm_resource_group.webapp_rg.name

  security_rule {
    name                       = "ssh"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "http"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}
resource "azurerm_network_interface_security_group_association" "web_nsgattach" {
  network_interface_id      = azurerm_network_interface.webapp_nic.id
  network_security_group_id = azurerm_network_security_group.webapp_nsg.id
}
