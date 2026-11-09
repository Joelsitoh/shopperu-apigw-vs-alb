# ShopPeru - API Gateway vs Application Load Balancer

Laboratorio 15 del curso Infraestructura como Codigo (Grupo 15).

Compara las dos formas de exponer la ruta `GET /productos` del catalogo de ShopPeru:

- Opcion A: Amazon API Gateway (HTTP API) con una Lambda en Node.js.
- Opcion B: Application Load Balancer con dos instancias EC2 en dos zonas de disponibilidad.

Ambas se crean con Terraform (`terraform/`) y se prueban con la misma carga (`prueba/carga.py`).

```sh
terraform -chdir=terraform init
terraform -chdir=terraform apply
python3 prueba/carga.py <url_api_gateway> <url_alb>
terraform -chdir=terraform destroy
```
