output "url_api_gateway" {
  value = "${aws_apigatewayv2_api.api.api_endpoint}/productos"
}

output "url_alb" {
  value = "http://${aws_lb.alb.dns_name}/productos"
}

output "instancias" {
  value = aws_instance.catalogo[*].id
}
