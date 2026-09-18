# Local implementation evidence

Local validation repeated on 2026-09-17. The checks below passed against the
isolated `marketly-check` Compose project. Live deployment work is tracked in
`docs/LIVE_EVIDENCE.md`; this table alone is not proof of an AWS deployment.

| Check | Result |
| --- | --- |
| Four Docker images, including Vite production build | Passed |
| Compose PostgreSQL readiness and backend startup | Passed |
| Nginx same-origin APIs and SPA deep links | Passed |
| Registration/login, profile, JWT authorization | Passed |
| Catalog browsing/categories and price-authoritative checkout | Passed |
| Concurrent cancellation restores inventory once | Passed |
| Refresh-token rotation rejects replay; logout revokes tokens | Passed |
| Admin product create/update/delete using PostgreSQL `RETURNING` | Passed |
| Two concurrent reservations for one item yield one success | Passed |
| Terraform root and state-bootstrap provider validation | Passed |
| Terraform mock-provider application across all eight modules | Passed; 2 test runs (fresh network and existing VPC) |
| Terraform recursive formatting | Passed |
| GitHub Actions actionlint: workflow syntax and expressions | Passed |
| Bash syntax and Kustomize rendering | Passed |
| Kubernetes schema validation | 12 valid resources, no errors |

Reproduction:

```bash
FRONTEND_PORT=15173 COMPOSE_PROJECT_NAME=marketly-check ./scripts/local.sh
BASE_URL=http://localhost:15173 python3 tests/smoke.py
docker compose -p marketly-check exec -T catalog-service python < tests/catalog.py
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
terraform -chdir=terraform test
```

For standard port/project settings, omit the two environment overrides and
`-p marketly-check`. The local test stack uses its own named PostgreSQL volume;
other Docker projects are not modified.

## Live submission evidence

The AWS apply, SSM/k3s readiness, ALB application flow, main-commit CI/CD, HPA
scale-up and recorded demo are now verified. See [LIVE_EVIDENCE.md](LIVE_EVIDENCE.md)
for run links, measured load results and teardown status.

Commit history and a recorded live demo cannot be substituted with local tests.
See [OPERATIONS.md](OPERATIONS.md) for execution, debugging and teardown steps.
