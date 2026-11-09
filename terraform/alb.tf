# Opcion B: Application Load Balancer -> 2 instancias EC2 en dos zonas

data "aws_availability_zones" "disponibles" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "principal" {
  cidr_block           = "10.15.0.0/16"
  enable_dns_hostnames = true

  tags = { Name = "${var.prefijo}-vpc" }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id
}

resource "aws_subnet" "publica" {
  count                   = 2
  vpc_id                  = aws_vpc.principal.id
  cidr_block              = "10.15.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.disponibles.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.prefijo}-publica-${count.index + 1}" }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }
}

resource "aws_route_table_association" "publica" {
  count          = 2
  subnet_id      = aws_subnet.publica[count.index].id
  route_table_id = aws_route_table.publica.id
}

resource "aws_security_group" "alb" {
  name   = "${var.prefijo}-alb"
  vpc_id = aws_vpc.principal.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Las instancias solo aceptan trafico que llega desde el ALB
resource "aws_security_group" "instancias" {
  name   = "${var.prefijo}-instancias"
  vpc_id = aws_vpc.principal.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "catalogo" {
  count                  = 2
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.tipo_instancia
  subnet_id              = aws_subnet.publica[count.index].id
  vpc_security_group_ids = [aws_security_group.instancias.id]
  user_data              = file("${path.module}/src/instancia.sh")

  tags = { Name = "${var.prefijo}-catalogo-${count.index + 1}" }
}

resource "aws_lb" "alb" {
  name               = "${var.prefijo}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.publica[*].id
}

resource "aws_lb_target_group" "catalogo" {
  name     = "${var.prefijo}-catalogo"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.principal.id

  health_check {
    path                = "/salud"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "catalogo" {
  count            = 2
  target_group_arn = aws_lb_target_group.catalogo.arn
  target_id        = aws_instance.catalogo[count.index].id
  port             = 8080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = "{\"mensaje\":\"ruta no encontrada\"}"
      status_code  = "404"
    }
  }
}

# Regla por ruta: igual que la ruta GET /productos del API Gateway
resource "aws_lb_listener_rule" "productos" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalogo.arn
  }

  condition {
    path_pattern {
      values = ["/productos"]
    }
  }

  condition {
    http_request_method {
      values = ["GET"]
    }
  }
}
