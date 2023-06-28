#Create resource group
resource "azurerm_resource_group" "anne_terraform_rg" {
   name = "anne-ks8terra-rg"
  location = var.location
}

#Create virtual network
resource "azurerm_virtual_network" "anne_terraform_network" {
   name                = "anne_ks8_vnet"
   address_space       = ["10.0.0.0/16"]
   location            = azurerm_resource_group.anne_terraform_rg.location
   resource_group_name = azurerm_resource_group.anne_terraform_rg.name
 }

#Create virtual subnet
 resource "azurerm_subnet" "anne_terraform_subnet" {
   name                 = "anne_ks8_subnet"
   resource_group_name  = azurerm_resource_group.anne_terraform_rg.name
   virtual_network_name = azurerm_virtual_network.anne_terraform_network.name
   address_prefixes     = ["10.0.2.0/24"]
 }

 # Create Network Security Group and rule
resource "azurerm_network_security_group" "anne_ks8_nsg" {
  name                = "anne_ks8_nsg"
  location            = azurerm_resource_group.anne_terraform_rg.location
  resource_group_name = azurerm_resource_group.anne_terraform_rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
       name = "https"
       priority = 200
       direction = "Inbound"
       access = "Allow"
       protocol = "Tcp"
       source_port_range = "*"
       destination_port_range = "443"
       source_address_prefix = "*"
       destination_address_prefix = "*"

  }

  security_rule {
       name = "http"
       priority = 100
       direction = "Inbound"
       access = "Allow"
       protocol = "Tcp"
       source_port_range = "*"
       destination_port_range = "80"
       source_address_prefix = "*"
       destination_address_prefix = "*"
  }

  security_rule {
       name = "all"
       priority = 400
       direction = "Inbound"
       access = "Allow"
       protocol = "*"
       source_port_range = "*"
       destination_port_range = "*"
       source_address_prefix = "10.0.0.0/16"
       destination_address_prefix = "VirtualNetwork"
   }
  }

 #Create Private Network Interfaces
resource "azurerm_network_interface" "anne_ks8_ni" {
  count               = 3
  name                = "anne_ks8_ni-${count.index}"
  location            = azurerm_resource_group.anne_terraform_rg.location
  resource_group_name = azurerm_resource_group.anne_terraform_rg.name

  ip_configuration {
    name                          = "anne_ks8_ipconfig"
    subnet_id                     = azurerm_subnet.anne_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.anne_ks8_publicip["${count.index}"].id
   }
   depends_on = [azurerm_resource_group.anne_terraform_rg]
 }

# Create public IPs
resource "azurerm_public_ip" "anne_ks8_publicip" {
  count               = 3
  name                = "anne_ks8_public_ip-${count.index}"
  location            = azurerm_resource_group.anne_terraform_rg.location
  resource_group_name = azurerm_resource_group.anne_terraform_rg.name
  allocation_method   = "Dynamic"
}

#Create 1 master
resource "azurerm_linux_virtual_machine" "anne_terraformmaster_vm" {
   name                  = "anne_mastervm"
   location              = azurerm_resource_group.anne_terraform_rg.location
   resource_group_name   = azurerm_resource_group.anne_terraform_rg.name
   size                  = "Standard_D2ds_v4"
   computer_name                   = "kub-manager" 
   admin_username                  = "azureuser"
   admin_password                  = "kingpin42330@" 
   disable_password_authentication = false   
   network_interface_ids = [
     azurerm_network_interface.anne_ks8_ni["${2}"].id
     ]

   os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

   source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [azurerm_resource_group.anne_terraform_rg]
}

#Create 2 workers
 resource "azurerm_linux_virtual_machine" "anne_terraformworker_vm" {
    count                 = 2
    name                  = "anne_worker${count.index}"
    location              = azurerm_resource_group.anne_terraform_rg.location
    resource_group_name   = azurerm_resource_group.anne_terraform_rg.name
    size                  = "Standard_D2ds_v4"
    computer_name                   = "kub-manager" 
    admin_username                  = "azureuser"
    admin_password                  = "kingpin42330@" 
    disable_password_authentication = false 
    network_interface_ids = [
     azurerm_network_interface.anne_ks8_ni["${count.index}"].id
    ]

    source_image_reference  {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }

    os_disk {
      name = "OSdisk${count.index}"
      caching = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }
}

