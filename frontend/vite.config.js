import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// TODO (student): once each microservice is deployed (locally via Docker or
// in-cluster via Kubernetes), point VITE_AUTH_URL / VITE_CATALOG_URL /
// VITE_ORDERS_URL at the real addresses (see src/api/*.js + .env.example).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
  },
});
