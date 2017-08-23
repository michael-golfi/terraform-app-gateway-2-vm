provider "azurerm" {
    subscription_id = "${var.subscription_id}"
    client_id       = "${var.client_id}"
    client_secret   = "${var.client_secret}"
    tenant_id       = "${var.tenant_id}"
} 

resource "azurerm_resource_group" "rg" {
    name     = "${var.resource_group}"
    location = "${var.location}"
}

resource "azurerm_virtual_network" "vnet" {
    name                = "${var.virtual_network_name}"
    location            = "${azurerm_resource_group.rg.location}"
    address_space       = ["${var.address_space}"]
    resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "subnet" {
    name                 = "${azurerm_resource_group.rg.name}-subnet"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    address_prefix       = "${var.subnet_prefix}"
}

resource "azurerm_subnet" "subnet2" {
    name                 = "${azurerm_resource_group.rg.name}-subnet2"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    address_prefix       = "${var.subnet2_prefix}"
}

resource "azurerm_public_ip" "pip" {
    name                         = "${azurerm_resource_group.rg.name}-ip"
    location                     = "${azurerm_resource_group.rg.location}"
    resource_group_name          = "${azurerm_resource_group.rg.name}"
    public_ip_address_allocation = "Dynamic"
}

resource "azurerm_application_gateway" "network" {
    name                = "${azurerm_virtual_network.vnet.name}"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    sku {
        name           = "Standard_Small"
        tier           = "Standard"
        capacity       = 2
    }
    gateway_ip_configuration {
        name         = "${azurerm_virtual_network.vnet.name}-gwip-cfg"
        subnet_id    = "${azurerm_virtual_network.vnet.id}/subnets/${azurerm_subnet.subnet.name}"
    }
    frontend_port {
        name         = "${azurerm_virtual_network.vnet.name}-feport"
        port         = 80
    }
    frontend_ip_configuration {
        name         = "${azurerm_virtual_network.vnet.name}-feip"  
        public_ip_address_id = "${azurerm_public_ip.pip.id}"
    }
    backend_address_pool = [{
        name = "${azurerm_virtual_network.vnet.name}-beap"
        ip_address_list = ["${element(azurerm_network_interface.nic.*.private_ip_address, count.index)}"] 
    },
    {
        name = "${azurerm_virtual_network.vnet.name}-beap2"
        ip_address_list = ["${element(azurerm_network_interface.nic2.*.private_ip_address, count.index)}"] 
    }]
    backend_http_settings {
        name                  = "${azurerm_virtual_network.vnet.name}-be-htst"
        cookie_based_affinity = "Disabled"
        port                  = 80
        protocol              = "Http"
        request_timeout        = 1
    }
    http_listener {
        name                                  = "${azurerm_virtual_network.vnet.name}-httplstn"
        frontend_ip_configuration_name        = "${azurerm_virtual_network.vnet.name}-feip"
        frontend_port_name                    = "${azurerm_virtual_network.vnet.name}-feport"
        protocol                              = "Http"
    }
    request_routing_rule {
            name                       = "${azurerm_virtual_network.vnet.name}-rqrt"
            rule_type                  = "Basic"
            http_listener_name         = "${azurerm_virtual_network.vnet.name}-httplstn"
            backend_address_pool_name  = "${azurerm_virtual_network.vnet.name}-beap"
            backend_http_settings_name = "${azurerm_virtual_network.vnet.name}-be-htst"
    }
    url_path_map = [{
            name                       = "${azurerm_virtual_network.vnet.name}-path-map"
            default_backend_address_pool_name  = "${azurerm_virtual_network.vnet.name}-beap"
            default_backend_http_settings_name = "${azurerm_virtual_network.vnet.name}-be-htst"
            path_rule = [{
                    name = "VM1"
                    paths = ["/vm1"]
                    backend_address_pool_name  = "${azurerm_virtual_network.vnet.name}-beap"
                    backend_http_settings_name = "${azurerm_virtual_network.vnet.name}-be-htst"
                },
                {
                    name = "VM2"
                    paths = ["/vm2"]
                    backend_address_pool_name  = "${azurerm_virtual_network.vnet.name}-beap2"
                    backend_http_settings_name = "${azurerm_virtual_network.vnet.name}-be-htst"
                }]
    }]
}

resource "azurerm_network_interface" "nic" {
    name                = "${azurerm_resource_group.rg.name}-nic"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    ip_configuration {
        name                          = "${azurerm_resource_group.rg.name}-ipconfig"
        subnet_id                     = "${azurerm_subnet.subnet.id}"
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_network_interface" "nic2" {
    name                = "${azurerm_resource_group.rg.name}-nic2"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    ip_configuration {
        name                          = "${azurerm_resource_group.rg.name}-ipconfig"
        subnet_id                     = "${azurerm_subnet.subnet2.id}"
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_storage_account" "stor" {
    name                = "${var.dns_name}stor"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    account_type        = "${var.storage_account_type}"
}

resource "azurerm_managed_disk" "datadisk" {
    name                 = "${var.hostname}-datadisk"
    location             = "${azurerm_resource_group.rg.location}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    storage_account_type = "Standard_LRS"
    create_option        = "Empty"
    disk_size_gb         = "60"
}

resource "azurerm_managed_disk" "datadisk2" {
    name                 = "${var.hostname}-datadisk2"
    location             = "${azurerm_resource_group.rg.location}"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    storage_account_type = "Standard_LRS"
    create_option        = "Empty"
    disk_size_gb         = "60"
}

#
# Subnet VM
#
resource "azurerm_virtual_machine" "vm" { 
    name                  = "${azurerm_resource_group.rg.name}-vm"
    location              = "${azurerm_resource_group.rg.location}"
    resource_group_name   = "${azurerm_resource_group.rg.name}"
    vm_size               = "${var.vm_size}"
    network_interface_ids = ["${azurerm_network_interface.nic.id}"]

    connection {
        type                = "ssh"
        bastion_host        = "${azurerm_public_ip.bastion_pip.fqdn}"
        bastion_user        = "${var.username}"
        bastion_private_key = "${file(var.private_key_path)}"
        host                = "${element(azurerm_network_interface.nic.*.private_ip_address, count.index)}"
        user                = "${var.username}"
        private_key         = "${file(var.private_key_path)}"
    }

    storage_image_reference {
        publisher = "${var.image_publisher}"
        offer     = "${var.image_offer}"
        sku       = "${var.image_sku}"
        version   = "${var.image_version}"
    }

    storage_os_disk {
        name              = "${var.hostname}-osdisk"
        managed_disk_type = "Standard_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }

    storage_data_disk {
        name              = "${var.hostname}-datadisk"
        managed_disk_id   = "${azurerm_managed_disk.datadisk.id}"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "60"
        create_option     = "Attach"
        lun               = 0
    }

    os_profile {
        computer_name  = "${var.hostname}"
        admin_username = "${var.username}"
        admin_password = "${var.password}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.username}/.ssh/authorized_keys"
            key_data = "${file(var.public_key_path)}"
        }
    }

    boot_diagnostics {
        enabled     = true
        storage_uri = "${azurerm_storage_account.stor.primary_blob_endpoint}"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo apt-get update && sudo apt-get install nginx -y",
            "sudo curl https://raw.githubusercontent.com/michael-golfi/terraform-app-gateway-2-vm/master/assets/vm1.html > /var/www/html/index.nginx-debian.html",
            "sudo curl https://raw.githubusercontent.com/michael-golfi/terraform-app-gateway-2-vm/master/assets/nginx1.conf > /etc/nginx/sites-enabled/default",
            "nginx -s reload",
        ]
    }
}


#
# Subnet VM
#
resource "azurerm_virtual_machine" "vm2" { 
    name                  = "${azurerm_resource_group.rg.name}-vm-2"
    location              = "${azurerm_resource_group.rg.location}"
    resource_group_name   = "${azurerm_resource_group.rg.name}"
    vm_size               = "${var.vm_size}"
    network_interface_ids = ["${azurerm_network_interface.nic2.id}"]

    connection {
        type                = "ssh"
        bastion_host        = "${azurerm_public_ip.bastion_pip.fqdn}"
        bastion_user        = "${var.username}"
        bastion_private_key = "${file(var.private_key_path)}"
        host                = "${element(azurerm_network_interface.nic2.*.private_ip_address, count.index)}"
        user                = "${var.username}"
        private_key         = "${file(var.private_key_path)}"
    }

    storage_image_reference {
        publisher = "${var.image_publisher}"
        offer     = "${var.image_offer}"
        sku       = "${var.image_sku}"
        version   = "${var.image_version}"
    }

    storage_os_disk {
        name              = "${var.hostname}-osdisk2"
        managed_disk_type = "Standard_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }

    storage_data_disk {
        name              = "${var.hostname}-datadisk2"
        managed_disk_id   = "${azurerm_managed_disk.datadisk.id}"
        managed_disk_type = "Standard_LRS"
        disk_size_gb      = "60"
        create_option     = "Attach"
        lun               = 0
    }

    os_profile {
        computer_name  = "${var.hostname}"
        admin_username = "${var.username}"
        admin_password = "${var.password}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.username}/.ssh/authorized_keys"
            key_data = "${file(var.public_key_path)}"
        }
    }

    boot_diagnostics {
        enabled     = true
        storage_uri = "${azurerm_storage_account.stor.primary_blob_endpoint}"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo apt-get update && sudo apt-get install nginx -y",
            "sudo curl https://raw.githubusercontent.com/michael-golfi/terraform-app-gateway-2-vm/master/assets/vm2.html > /var/www/html/index.nginx-debian.html",
            "sudo curl https://raw.githubusercontent.com/michael-golfi/terraform-app-gateway-2-vm/master/assets/nginx2.conf > /etc/nginx/sites-enabled/default",
            "nginx -s reload",
        ]
    }
}

#
# Bastion Host
#
resource "azurerm_public_ip" "bastion_pip" {
    name                         = "${azurerm_resource_group.rg.name}-bastion-pip"
    resource_group_name          = "${azurerm_resource_group.rg.name}"
    location                     = "${azurerm_resource_group.rg.location}"
    public_ip_address_allocation = "Static"
    domain_name_label            = "${azurerm_resource_group.rg.name}-bastion"
}

resource "azurerm_network_security_group" "bastion_nsg" {
    name                = "${azurerm_resource_group.rg.name}-bastion-nsg"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    security_rule {
        name                       = "allow_SSH_in_all"
        description                = "Allow SSH in from all locations"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "bastion_nic" {
    name                      = "${azurerm_resource_group.rg.name}-bastion-nic"
    location                  = "${azurerm_resource_group.rg.location}"
    resource_group_name       = "${azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.bastion_nsg.id}"

    ip_configuration = [{
        name                          = "${azurerm_resource_group.rg.name}-bastion-ipconfig"
        subnet_id                     = "${azurerm_subnet.subnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.bastion_pip.id}"
    },
    {
        name                          = "${azurerm_resource_group.rg.name}-bastion-ipconfig2"
        subnet_id                     = "${azurerm_subnet.subnet2.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.bastion_pip.id}"
    }]
}

resource "azurerm_virtual_machine" "bastion" {
    name                  = "${azurerm_resource_group.rg.name}-bastion"
    location              = "${azurerm_resource_group.rg.location}"
    resource_group_name   = "${azurerm_resource_group.rg.name}"
    vm_size               = "${var.vm_size}"
    network_interface_ids = ["${azurerm_network_interface.bastion_nic.id}"]
    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

    os_profile {
        computer_name  = "${var.hostname}-bastion"
        admin_username = "${var.username}"
        admin_password = "${var.password}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/${var.username}/.ssh/authorized_keys"
            key_data = "${file(var.public_key_path)}"
        }
    }

    storage_image_reference {
        publisher = "${var.image_publisher}"
        offer     = "${var.image_offer}"
        sku       = "${var.image_sku}"
        version   = "${var.image_version}"
    }

    storage_os_disk {
        name              = "${var.hostname}-bastion-osdisk"
        managed_disk_type = "Standard_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }
}