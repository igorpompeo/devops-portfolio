variable "compartment_ocid" {
  description = "OCID do compartment dedicado pro projeto (criado manualmente no console - ver README, seção Decisões técnicas)"
  type        = string
}

variable "region" {
  description = "Região OCI onde os recursos serão criados"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "tenancy_ocid" {
  description = "OCID da tenancy OCI (raiz da conta) - necessário para data sources que não aceitam compartment_id de um subcompartment"
  type        = string
}