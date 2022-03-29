resource "azurerm_public_ip" "pip_k8s_worker" {
  count               = length(var.worker_nodes_config)
  name                = "pip-k8s-worker-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "cloudruler-k8s-worker-${count.index}"
}

resource "azurerm_network_interface" "nic_k8s_worker" {
  count                = length(var.worker_nodes_config)
  name                 = "nic-k8s-worker-${count.index}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal-${count.index}"
    subnet_id                     = azurerm_subnet.snet_main.id
    public_ip_address_id          = azurerm_public_ip.pip_k8s_worker[count.index].id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }
}

locals {
  worker_custom_data = base64gzip(templatefile("${var.resources_path}/cloud-config.yaml", {
    node_type      = "worker"
    admin_username = var.admin_username
    crio_version   = var.crio_version
    crio_os_version = var.crio_os_version
    certificates               = { for cert_name in var.certificate_names : cert_name => data.azurerm_key_vault_certificate.kv_certificate[cert_name].thumbprint }
    configs_kubeadm = base64gzip(templatefile("${var.resources_path}/configs/kubeadm-config.yaml", {
      node_type                    = "worker"
      bootstrap_token              = data.azurerm_key_vault_secret.kv_sc_bootstrap_token.value
      api_server_name              = var.api_server_name
      discovery_token_ca_cert_hash = data.azurerm_key_vault_secret.kv_sc_discovery_token_ca_cert_hash.value
      k8s_service_subnet           = var.k8s_service_subnet
      cluster_dns                  = var.cluster_dns
      pod_subnet_cidr              = var.pods_cidr
    }))
    configs_calico = base64gzip(templatefile("${var.resources_path}/configs/calico.yaml", {
      calico_ipv4pool_cidr         = var.pods_cidr
    }))
    # manifests_kube_addon_manager    = base64gzip(file("modules/kubeadm/resources/manifests/kube-addon-manager.yaml"))
    # addons_coredns = base64gzip(templatefile("modules/kubeadm/resources/addons/coredns.yaml", {
    #   cluster_dns = var.cluster_dns
    # }))
    # addons_kube_proxy          = base64gzip(file("modules/kubeadm/resources/addons/kube-proxy.yaml"))
  }))
}

resource "azurerm_linux_virtual_machine" "vm_k8s_worker" {
  count               = length(var.worker_nodes_config)
  name                = "vm-k8s-worker-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s"
  custom_data         = local.worker_custom_data
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_k8s_worker[count.index].id,
  ]
  admin_ssh_key {
    username   = var.admin_username
    public_key = data.azurerm_ssh_public_key.ssh_public_key.public_key
  }

  os_disk {
    name                 = "osdisk-k8s-worker-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_image_publisher.publisher
    offer     = var.vm_image_publisher.offer
    sku       = var.vm_image_publisher.sku
    version   = var.vm_image_publisher.version
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

resource "azurerm_application_security_group" "asg_k8s_workers" {
  name                = "asg-k8s-workers"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_interface_application_security_group_association" "asg_k8s_workers_nic_k8s_worker" {
  count                         = length(var.worker_nodes_config)
  network_interface_id          = azurerm_network_interface.nic_k8s_worker[count.index].id
  application_security_group_id = azurerm_application_security_group.asg_k8s_workers.id
}
