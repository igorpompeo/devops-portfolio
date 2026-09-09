# =============================================================================
# VCN
# =============================================================================
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "devops-portfolio-vcn"
  dns_label      = "portfoliovcn"
}

# =============================================================================
# Gateways — cada um resolve um tipo de tráfego diferente
# =============================================================================

# Internet Gateway: tráfego bidirecional para a subnet pública
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devops-portfolio-igw"
  enabled        = true
}

# NAT Gateway: tráfego de SAÍDA apenas, para a subnet privada
resource "oci_core_nat_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devops-portfolio-nat"
}

# Service Gateway: acesso privado a serviços OCI (registry, object storage)
# sem passar pela internet pública
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devops-portfolio-svc-gw"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

# =============================================================================
# Route Tables
# =============================================================================

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "private-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.main.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.main.id
  }
}

# =============================================================================
# Security Lists
# Regras mínimas para o OKE funcionar — endpoint público, comunicação
# control plane <-> workers, e workers <-> internet de saída.
# =============================================================================

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "public-subnet-seclist"

  # Kubernetes API endpoint (kubectl/argocd falam com o cluster nessa porta)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
    description = "Kubernetes API endpoint"
  }

  # Tráfego interno da própria VCN (control plane <-> workers)
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
    description = "Tráfego interno da VCN"
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Saída liberada"
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "private-subnet-seclist"

  # Tráfego interno da própria VCN (workers entre si, e vindos do control plane)
  ingress_security_rules {
    protocol    = "all"
    source      = "10.0.0.0/16"
    description = "Tráfego interno da VCN"
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Saída liberada (via NAT/Service Gateway)"
  }
}

# =============================================================================
# Subnets
# =============================================================================

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.0.0.0/24"
  display_name               = "public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "private-subnet"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true
}

# =============================================================================
# OKE
# =============================================================================

data "oci_identity_availability_domain" "ad1" {
  compartment_id = var.tenancy_ocid   # atenção: tenancy_ocid, não compartment_ocid
  ad_number      = 1
}

resource "oci_containerengine_cluster" "portfolio_oke" {
  compartment_id             = var.compartment_ocid
  kubernetes_version         = "v1.34.10" 
  name                       = "devops-portfolio-oke"
  vcn_id                     = oci_core_vcn.main.id

  endpoint_config {
    is_public_ip_enabled     = true
    subnet_id                = oci_core_subnet.public.id
  }

  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY" # tipo de rede por não ter necessidade de escalonamento (apenas estudo)
  }
}

resource "oci_containerengine_node_pool" "portfolio_oke_pool" {
  cluster_id                 = oci_containerengine_cluster.portfolio_oke.id
  compartment_id             = var.compartment_ocid
  kubernetes_version         = "v1.34.10"
  name                       = "portfolio-node-pool"
  node_shape                 = "VM.Standard.A1.Flex"

  node_source_details {
    image_id    = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa7ruim65pzodjcirutykxzlxw7vbitcbijmy5pbhnyfpjrj3pmspa"
    source_type = "IMAGE"
  }

  node_shape_config {
    ocpus                    = 1 # metade do teto Always Free (4 OCPUS total)
    memory_in_gbs            = 6 # metade do teto Always Free (24GB total)
  }

  node_config_details {
    size                     = 1 # 1 node para começar

    placement_configs {
      availability_domain    = data.oci_identity_availability_domain.ad1.name
      subnet_id              = oci_core_subnet.private.id
    }
  }
}