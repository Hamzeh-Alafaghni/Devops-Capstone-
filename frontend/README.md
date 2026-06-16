# frontend

React (Vite) + Tailwind CSS single-page app: catalog browsing with search,
filtering, sorting and pagination; cart and checkout; login/register;
order history with cancellation; profile management; and an admin area
for managing products and order statuses. Talks directly to the three
backend microservices over their REST APIs — no server-side rendering, no
backend-for-frontend layer.

This app is fully built — there is no remaining frontend work for students.
The infrastructure to deploy it (Docker, Kubernetes, Terraform, CI/CD) is the
actual assignment; see the root `README.md` and `PROJECT_BRIEF.md`.

## Run standalone

```bash
npm install
cp .env.example .env   # adjust ports if your services run elsewhere
npm run dev
```

Opens on `http://localhost:5173`. Requires all three backend services running
(see services/*/README.md) — auth on :5001, catalog on :5002, orders on :5003.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `VITE_AUTH_URL` | `http://localhost:5001` | Base URL for auth-service |
| `VITE_CATALOG_URL` | `http://localhost:5002` | Base URL for catalog-service |
| `VITE_ORDERS_URL` | `http://localhost:5003` | Base URL for orders-service |

When deploying behind Kubernetes Services/Ingress, these get pointed at the
in-cluster or externally-routed URLs instead — that wiring is part of the
infrastructure assignment, not something this app needs to know about.

## Structure

```
src/
  api/
    client.js        shared axios instance config
    auth.js           register, login, me, updateProfile, changePassword
    catalog.js        listProducts, getProduct, listCategories, create/update/deleteProduct (admin)
    orders.js         createOrder, listOrders, getOrder, cancelOrder, listAllOrders/updateOrderStatus (admin)
  context/
    AuthContext.jsx   JWT + user object (incl. role), persisted to localStorage, revalidated on load
    CartContext.jsx   cart persisted to localStorage, quantity capped at product stock
  components/
    Navbar, ProtectedRoute, AdminRoute, ProductCard, StatusBadge,
    Skeletons, EmptyState, Pagination
  pages/
    Catalog, ProductDetail, Cart, Orders, Profile, Login, Register, NotFound
    admin/AdminProducts, admin/AdminOrders
```

## Build for production

```bash
npm run build
```

Outputs static files to `dist/` — this is what the frontend Dockerfile
(currently empty, a student task) should build and serve, typically via Nginx.
