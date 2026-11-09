variable "aws_region" {
  description = "Region de AWS de la prueba"
  type        = string
  default     = "us-east-2"
}

variable "prefijo" {
  description = "Prefijo de los recursos"
  type        = string
  default     = "lab15-shopperu"
}

variable "tipo_instancia" {
  description = "Tipo de las instancias detras del ALB"
  type        = string
  default     = "t3.micro"
}
