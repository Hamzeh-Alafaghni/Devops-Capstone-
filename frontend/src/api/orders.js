import { ordersClient, authHeader } from "./client.js";

export async function createOrder(token, items) {
  const res = await ordersClient.post(
    "/api/orders",
    { items },
    { headers: authHeader(token) }
  );
  return res.data;
}

export async function listOrders(token) {
  const res = await ordersClient.get("/api/orders", {
    headers: authHeader(token),
  });
  return res.data;
}

export async function getOrder(token, id) {
  const res = await ordersClient.get(`/api/orders/${id}`, {
    headers: authHeader(token),
  });
  return res.data;
}

export async function cancelOrder(token, id) {
  const res = await ordersClient.patch(
    `/api/orders/${id}/cancel`,
    {},
    { headers: authHeader(token) }
  );
  return res.data;
}

export async function listAllOrders(token) {
  const res = await ordersClient.get("/api/orders/all", {
    headers: authHeader(token),
  });
  return res.data;
}

export async function updateOrderStatus(token, id, status) {
  const res = await ordersClient.patch(
    `/api/orders/${id}/status`,
    { status },
    { headers: authHeader(token) }
  );
  return res.data;
}
