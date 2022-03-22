resource "azurerm_public_ip" "pip_k8s_master" {
  count               = length(var.master_nodes_config)
  name                = "pip-k8s-master-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  allocation_method   = "Dynamic"
  domain_name_label   = "cloudruler-k8s-master-${count.index}"
}

resource "azurerm_network_interface" "nic_k8s_master" {
  count                = length(var.master_nodes_config)
  name                 = "nic-k8s-master-${count.index}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal-${count.index}"
    subnet_id                     = azurerm_subnet.snet_main.id
    public_ip_address_id          = azurerm_public_ip.pip_k8s_master[count.index].id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

locals {
  master_custom_data = base64gzip(templatefile(var.master_custom_data_template, {
    node_type      = "master"
    admin_username = var.admin_username
    vnet_cidr      = var.vnet_cidr
    crio_version   = var.crio_version
    crio_os_version = var.crio_os_version
    certificates   = { for cert_name in var.certificate_names : cert_name => data.azurerm_key_vault_certificate.kv_certificate[cert_name].thumbprint }
    configs_kubeadm = base64gzip(templatefile("modules/kubeadm/resources/configs/kubeadm-config.yaml", {
      node_type                    = "master"
      bootstrap_token              = data.azurerm_key_vault_secret.kv_sc_bootstrap_token.value
      api_server_name              = var.api_server_name
      discovery_token_ca_cert_hash = data.azurerm_key_vault_secret.kv_sc_discovery_token_ca_cert_hash.value
      subnet_cidr                  = var.subnet_cidr
      k8s_service_subnet           = var.k8s_service_subnet
      cluster_dns                  = var.cluster_dns
    }))
    manifests_kube_addon_manager    = base64gzip(file("modules/kubeadm/resources/manifests/kube-addon-manager.yaml"))
    addons_coredns = base64gzip(templatefile("modules/kubeadm/resources/addons/coredns.yaml", {
      cluster_dns = var.cluster_dns
    }))
    addons_kube_proxy          = base64gzip(file("modules/kubeadm/resources/addons/kube-proxy.yaml"))
  }))
}

resource "azurerm_linux_virtual_machine" "vm_k8s_master" {
  count               = length(var.master_nodes_config)
  name                = "vm-k8s-master-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s"
  custom_data         = local.master_custom_data
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_k8s_master[count.index].id,
  ]
  admin_ssh_key {
    username   = var.admin_username
    public_key = data.azurerm_ssh_public_key.ssh_public_key.public_key
  }

  os_disk {
    name                 = "osdisk-k8s-master-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS" #Eventually upgrade to 19.04 or 19_20-daily-gen2
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  secret {
    key_vault_id = data.azurerm_key_vault.kv.id
    dynamic "certificate" {
      for_each = var.certificate_names
      iterator = certificate_name
      content {
        url = data.azurerm_key_vault_certificate.kv_certificate[certificate_name.value].secret_id
      }
    }
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

resource "azurerm_application_security_group" "asg_k8s_masters" {
  name                = "asg-k8s-masters"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# resource "azurerm_network_interface_application_security_group_association" "asg_k8s_masters_nic_k8s_master" {
#   count                         = length(var.master_nodes_config)
#   network_interface_id          = azurerm_network_interface.nic_k8s_master[count.index].id
#   application_security_group_id = azurerm_application_security_group.asg_k8s_masters.id
# }

resource "azurerm_lb_backend_address_pool" "lbe_bep_k8s_master" {
  name            = "lbe-bep-k8s-master"
  loadbalancer_id = azurerm_lb.lbe_k8s.id
}

# resource "azurerm_network_interface_backend_address_pool_association" "lb_bep_k8s_nic_master" {
#   count                   = length(var.master_nodes_config)
#   network_interface_id    = azurerm_network_interface.nic_k8s_master[count.index].id
#   ip_configuration_name   = "internal-${count.index}"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id
# }

resource "azurerm_lb_nat_rule" "lb_nat_k8s_master" {
  count                          = length(var.master_nodes_config)
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "nat-ssh-master-${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = count.index + 1
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.lbe_k8s.frontend_ip_configuration[0].name
}

# resource "azurerm_network_interface_nat_rule_association" "nic_k8s_master_lb_nat_k8s_master" {
#   count                 = length(var.master_nodes_config)
#   network_interface_id  = azurerm_network_interface.nic_k8s_master[count.index].id
#   ip_configuration_name = "internal-${count.index}"
#   nat_rule_id           = azurerm_lb_nat_rule.lb_nat_k8s_master[count.index].id
# }

resource "azurerm_lb_outbound_rule" "lbe_out_rule_k8s_master" {
  resource_group_name     = var.resource_group_name
  loadbalancer_id         = azurerm_lb.lbe_k8s.id
  name                    = "lbe-master-rule"
  protocol                = "Tcp"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id

  frontend_ip_configuration {
    name = azurerm_lb.lbe_k8s.frontend_ip_configuration[0].name
  }
}

resource "azurerm_lb_rule" "lbe_k8s_api_rule" {
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "lbe-k8s-api-rule"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = azurerm_lb.lbe_k8s.frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id
  probe_id                       = azurerm_lb_probe.lbe_prb_k8s.id
  disable_outbound_snat          = true
}
