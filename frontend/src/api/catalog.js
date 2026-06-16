import { catalogClient, authHeader } from "./client.js";

export async function listProducts(params = {}) {
  // params: { q?, category?, sort?, page?, page_size? }
  const res = await catalogClient.get("/api/products", { params });
  return res.data; // { items, total, page, page_size, total_pages }
}

export async function getProduct(id) {
  const res = await catalogClient.get(`/api/products/${id}`);
  return res.data;
}

export async function listCategories() {
  const res = await catalogClient.get("/api/categories");
  return res.data; // string[]
}

export async function createProduct(token, payload) {
  const res = await catalogClient.post("/api/products", payload, {
    headers: authHeader(token),
  });
  return res.data;
}

export async function updateProduct(token, id, payload) {
  const res = await catalogClient.put(`/api/products/${id}`, payload, {
    headers: authHeader(token),
  });
  return res.data;
}

export async function deleteProduct(token, id) {
  const res = await catalogClient.delete(`/api/products/${id}`, {
    headers: authHeader(token),
  });
  return res.data;
}
