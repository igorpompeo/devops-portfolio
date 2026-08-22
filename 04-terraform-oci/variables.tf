variable "compartment_ocid" {
  description = "OCID do compartment dedicado pro projeto (criado manualmente no console - ver README, seção Decisões técnicas)"
  type        = string
}

variable "region" {
  description = "Região OCI onde os recursos serão criados"
  type        = string
  default     = "eu-frankfurt-1"
}