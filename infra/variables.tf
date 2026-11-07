variable "aws_region" {
  description = "Região da AWS onde a infraestrutura será criada"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo usado no nome de todos os recursos"
  type        = string
  default     = "devops-na-pratica"
}

variable "environment" {
  description = "Ambiente de implantação (dev, staging ou prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser dev, staging ou prod."
  }
}

variable "vpc_cidr" {
  description = "Faixa de IPs (CIDR) da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Faixa de IPs (CIDR) da sub-rede pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "Tipo da instância EC2 (t3.micro está no nível gratuito)"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Porta TCP em que a API escuta"
  type        = number
  default     = 3000
}

variable "allowed_cidr" {
  description = "Faixa de IPs autorizada a acessar a API"
  type        = string
  default     = "0.0.0.0/0"
}

variable "repo_url" {
  description = "URL do repositório Git clonado pela instância na inicialização"
  type        = string
  default     = "https://github.com/by-wagner/devops-na-pratica.git"
}
