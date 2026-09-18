# Marketly DevOps Capstone

A React storefront with Flask auth, catalog and orders services, PostgreSQL,
Docker Compose, and a self-managed k3s deployment on AWS EC2. The assignment
is preserved in [PROJECT_BRIEF.md](PROJECT_BRIEF.md) and [RUBRIC.md](RUBRIC.md).
This README describes the implemented configuration.

## Run locally

Requirements: Docker with Compose v2, Python 3 and OpenSSL. From the repository root:

```bash
./scripts/local.sh
python3 tests/smoke.py
```

Open <http://localhost:5173> and register a customer account. If that port is
occupied, use `FRONTEND_PORT=15173 ./scripts/local.sh`, then run the test with
`BASE_URL=http://localhost:15173 python3 tests/smoke.py`.

The helper generates random credentials in the ignored `.env` file. PostgreSQL
is reachable only inside the Compose network. All browser API calls go through
Nginx, so login cookies and SPA deep links work from the same origin. Backend
images run Gunicorn as an unprivileged user. All services use `DATABASE_URL`;
SQLite files are legacy examples and are not used or copied into images.

No admin or demo account is created by default. To create an admin on the first
startup, add a unique `ADMIN_SEED_PASSWORD` to `.env` and recreate auth-service.
The username defaults to `admin`. Changing the seed variable does not reset an
existing account's password. The frontend does not advertise shared passwords.

```bash
docker compose logs --tail=100
docker compose down        # keep PostgreSQL data
# docker compose down -v  # explicitly delete local test data
```

## Implemented architecture

See [the implementation diagram](docs/architecture-diagram.md).

- VPC: two public and two private subnets across two availability zones.
- Public ALB → port 30080 → Traefik → four ClusterIP services in `marketly`.
- Private k3s control plane (`t3.small`) and 2–4 ASG workers (`t3.micro`).
- Private PostgreSQL 15 RDS instance; RDS manages its password in Secrets Manager.
- A public NAT EC2 instance provides outbound connectivity; nodes use SSM, not SSH.
- Four immutable ECR repositories, with images tagged by the full Git commit SHA.
- GitHub OIDC roles separate image publishing, infrastructure reads and provisioning.
- S3 encrypted/versioned state and a DynamoDB lock table are bootstrapped separately.

Auth owns users/refresh tokens; catalog owns products; orders owns orders in one
database. Schema initialization is serialized with PostgreSQL advisory locks.
Product IDs and order IDs use `RETURNING`. Row locks protect concurrent stock
updates, cancellations and refresh-token rotation. Orders authenticate stock
changes with the shared signing secret; this endpoint must not trust routing
alone. The same secret is supplied to all three services.

## Local verification

```bash
./scripts/setup.sh
terraform fmt -check -recursive terraform
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
terraform -chdir=terraform test       # mock providers: no AWS calls/resources
kubectl kustomize k8s > /tmp/marketly.yaml
for script in scripts/*.sh; do bash -n "$script"; done
python3 tests/smoke.py               # requires running Compose stack
docker compose exec -T catalog-service python < tests/catalog.py
```

The smoke test checks SPA routing, registration/login, catalog, access controls,
checkout using catalog prices, inventory updates, concurrent cancellation,
refresh rotation and logout revocation. CI runs it against real PostgreSQL and
all four built containers. See [validation and remaining evidence](docs/VALIDATION.md).

## AWS setup (not performed by local validation)

1. Authenticate the intended AWS account using SSO or another temporary session.
   Check `aws sts get-caller-identity`. Run `scripts/setup.sh`. Budget for actual
   EC2, ALB, RDS, storage and public IPv4 charges; this deployment is not guaranteed
   free. The control plane uses 2 GiB of memory; worker capacity is intentionally
   modest for a capstone.
2. Bootstrap state once with your own unique bucket name:

   ```bash
   terraform -chdir=terraform/bootstrap init
   terraform -chdir=terraform/bootstrap apply \
     -var='state_bucket=YOUR-UNIQUE-STATE-BUCKET'
   ```

   Keep the bootstrap state securely; it is not checked into Git. The bucket and
   lock table have `prevent_destroy` and remain after application teardown.

   Bootstrap also creates the `marketly-monthly` account-wide cost budget
   (`monthly_budget_usd`, default `20`). Set `budget_alert_email` in an ignored
   bootstrap `terraform.tfvars` file to enable actual-spend email alerts at 80%
   and 100%. The budget sends notifications; it does not stop resources. Keep
   recipient addresses out of Git.
3. Copy `terraform/backend.hcl.example` to `terraform/backend.hcl` and
   `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`.
   Set matching state bucket, lock table and AWS region. The state key must be
   `<project>/terraform.tfstate` (default `marketly/terraform.tfstate`).
   The target repository is `Hamzeh-Alafaghni/Devops-Capstone-`.
   If this account already has GitHub's OIDC provider, set `oidc_provider_arn`
   to that ARN instead of creating a duplicate.
4. Provision using your bootstrap identity (the GitHub roles do not exist yet):

   ```bash
   terraform -chdir=terraform init -backend-config=backend.hcl
   terraform -chdir=terraform plan
   terraform -chdir=terraform apply
   terraform -chdir=terraform output
   ```

5. Open an SSM session to `control_plane_id`. Wait for cloud-init to finish and
   inspect `sudo k3s kubectl get nodes`. Install the self-hosted runner and
   credential maintenance timer using [the operations runbook](docs/OPERATIONS.md).
6. Configure the GitHub variables below, then push a reviewed commit to `main`.
   CI tests/builds/pushes; Terraform applies; CD waits for both, deploys the exact
   tested SHA, and verifies all rollouts and backend health.

| GitHub repository variable | Value |
| --- | --- |
| `AWS_REGION` | selected region |
| `PROJECT` | `marketly` |
| `STATE_BUCKET`, `STATE_LOCK_TABLE` | bootstrap names |
| `CI_ROLE_ARN` | Terraform `ci_role_arn` output |
| `TERRAFORM_ROLE_ARN` | `terraform_role_arn` output |
| `PLAN_ROLE_ARN` | `plan_role_arn` output |
| `OIDC_SUBJECT_PREFIX` | repository OIDC `sub_claim_prefix`, when immutable subjects are enabled |
| `ECR_REGISTRY` | `ecr_registry` output |
| `DATABASE_HOST` | `database_host` output |
| `DATABASE_SECRET_ARN` | `database_secret_arn` output |
| `EXISTING_VPC_ID` | optional VPC to reuse without owning or deleting it |
| `SUBNET_OFFSET` | first unused subnet index; default `0`, reserve four consecutive ranges |

Create GitHub environments `terraform-plan` and `terraform-apply`. Restrict
`terraform-apply` to `main`; require review for `terraform-plan` before running
untrusted changes with access to private state. Fork PRs receive local validation
only. No static AWS keys or database passwords are needed in GitHub secrets.
The provisioning role is powerful within its selected region and project IAM
names; only trusted maintainers should approve infrastructure workflows.

For an existing OIDC provider, also set repository variable `OIDC_PROVIDER_ARN`
to its ARN. All workflows should use the same project, region and state settings.

Check `gh api repos/OWNER/REPOSITORY/actions/oidc/customization/sub`. When
`use_immutable_subject` is true, copy its `sub_claim_prefix` into local
`github_oidc_subject_prefix` and GitHub variable `OIDC_SUBJECT_PREFIX`.
These subjects include immutable owner/repository IDs; a legacy `repo:owner/name`
trust condition will reject them. Empty/default settings support legacy subjects.

If the VPC quota is full, set `existing_vpc_id` and `subnet_offset` in local
Terraform variables and the matching GitHub variables above. Terraform creates
four new subnets and separate route tables/security groups, while the existing
VPC and internet gateway remain data sources. Select unused ranges and ensure
DNS support/hostnames are enabled. Existing subnets, workers and databases are
not imported into this state and are not deleted by its teardown. The default
configuration still provisions a new VPC and gateway for a fresh account.

For manual deployment, set `AWS_REGION`, `IMAGE_TAG` (a tested full commit SHA),
and `PROJECT`. `scripts/deploy.sh` applies Terraform and invokes deployment;
it requires an already-working kubeconfig through an SSM tunnel or on the
control plane. On the runner, `scripts/deploy-k8s.sh` needs the registry/database
variables above and performs only Kubernetes deployment.

## Operations and scope

Run `scripts/healthcheck.sh` against the cluster and check `kubectl -n marketly
get hpa`. Use [the runbook](docs/OPERATIONS.md) to demonstrate scaling, verify
ALB target health and roll back. When finished, use `scripts/teardown.sh`; it
requires typing `destroy` and Terraform's own approval. It deletes the RDS
instance without a final snapshot and force-deletes ECR repositories.
Export any required data first.

This is a capstone baseline: a single control plane/NAT, HTTP ALB, process-local
login throttling and best-effort compensation between catalog and orders.
RDS transport uses TLS (`sslmode=require`); production should use certificate
verification, separate least-privilege database users, HTTPS with secure cookies,
and durable/idempotent order workflows. Password rotation is synchronized by the
maintenance timer; pods restart when the stored connection URL changes.

Installed dependencies, generated frontend builds, legacy SQLite databases and
local Terraform variables are no longer tracked. Local copies are preserved;
fresh builds run `npm ci` from the lockfile. Historical commits are unchanged.
