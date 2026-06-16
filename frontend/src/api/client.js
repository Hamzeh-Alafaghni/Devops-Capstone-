import axios from "axios";

// Each microservice has its own base URL. They default to localhost ports
// for running the services standalone (see each service's README). When the
// app is containerized or deployed to Kubernetes, set VITE_AUTH_URL /
// VITE_CATALOG_URL / VITE_ORDERS_URL (see .env.example) to point at the
// real addresses.
export const AUTH_URL = import.meta.env.VITE_AUTH_URL || "http://localhost:5001";
export const CATALOG_URL = import.meta.env.VITE_CATALOG_URL || "http://localhost:5002";
export const ORDERS_URL = import.meta.env.VITE_ORDERS_URL || "http://localhost:5003";

export function authHeader(token) {
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export const authClient = axios.create({ baseURL: AUTH_URL });
export const catalogClient = axios.create({ baseURL: CATALOG_URL });
export const ordersClient = axios.create({ baseURL: ORDERS_URL });
