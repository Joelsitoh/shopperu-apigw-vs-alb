const productos = [
  { id: 1, nombre: "Polo de algodon", precio: 39.9, stock: 25 },
  { id: 2, nombre: "Zapatillas urbanas", precio: 189.0, stock: 8 }
];

export const handler = async (event, context) => {
  return {
    statusCode: 200,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      origen: "api-gateway-lambda",
      atendidoPor: context.awsRequestId,
      productos
    })
  };
};
