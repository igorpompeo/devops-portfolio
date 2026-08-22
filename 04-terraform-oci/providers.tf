terraform {
  required_providers {
    oci = {
        source = "oracle/oci"
        version = "~> 6.0"
    }
  }
}

# Reaproveita as credenciais já configuradas pelo 'oci setup config'
# (~/.oci/config) - evita duplicar OCID/fingerprint/chave privada aqui
# no código. Nada de secret no repositório
provider "oci" {
  config_file_profile = "DEFAULT"
}