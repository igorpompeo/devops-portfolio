output "vcn_id" {
  description = "OCID da VCN criada"
  value = oci_core_vcn.main.id
}

output "public_subnet_id" {
  description = "OCID da subnet pública (endpoint do OKE, load balancers)"
  value = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "OCID da subnet privada (worker nodes)"
  value = oci_core_subnet.private.id
}

output "oke_cluster_id" {
  description = "OCID do cluster OKE - necessário para gerar o kubeconfig via 'oci ce cluster create-kubeconfig'"
  value = oci_containerengine_cluster.portfolio_oke.id
}

output "oke_cluster_endpoint" {
  description = "Endpoint público da API do Kubernetes"
  value = oci_containerengine_cluster.portfolio_oke.endpoints[0].public_endpoint
}