output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "IP público da instância"
  value       = aws_instance.app.public_ip
}

output "api_url" {
  description = "URL do endpoint de saúde da API"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}/health"
}
