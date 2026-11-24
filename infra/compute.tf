# Servidor da aplicação: EC2 com Amazon Linux 2023 que instala o Docker e sobe a API a partir da imagem publicada no GHCR.

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"] # só a AMI padrão (o curinga pegava variantes ECS/Neuron)
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = var.instance_profile

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    image    = var.image
    app_port = var.app_port
  })

  metadata_options {
    http_tokens = "required" # exige IMDSv2, mais seguro contra roubo de credenciais
  }

  root_block_device {
    volume_size = 8
    encrypted   = true
  }

  tags = { Name = "${var.project_name}-app" }
}
