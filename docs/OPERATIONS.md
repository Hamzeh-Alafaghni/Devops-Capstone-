# Deployment and operations

## Control-plane runner

Use SSM to connect; do not expose port 6443 or SSH to the internet. On the instance:

```bash
sudo cloud-init status --wait
sudo k3s kubectl get nodes
sudo dnf install -y git libicu
sudo useradd --create-home runner
sudo install -d -m 700 -o runner -g runner /home/runner/.kube
sudo install -m 600 -o runner -g runner /etc/rancher/k3s/k3s.yaml /home/runner/.kube/config
```

From GitHub repository **Settings → Actions → Runners → New self-hosted runner**,
select Linux x64 and follow the current download, checksum and registration
commands as user `runner`, in `/home/runner/actions-runner`. Add label `marketly`.
Install/start its service with `sudo ./svc.sh install runner` and
`sudo ./svc.sh start`. Registration tokens are short-lived; never commit them or
put them in EC2 user-data. Refresh the kubeconfig copy after a cluster replacement.

For repeatable installation, `scripts/install-runner.sh` performs the same setup
and verifies the official Linux x64 runner archive against `RUNNER_SHA256`.
Supply `AWS_REGION`, `GITHUB_REPOSITORY`, `RUNNER_VERSION`, `RUNNER_SHA256`, and
`RUNNER_TOKEN_PARAMETER`. Store a freshly generated GitHub runner registration
token in that SSM SecureString and temporarily grant only the control-plane role
`ssm:GetParameter` on its exact ARN. Run the script as root through SSM, then
delete the parameter and temporary IAM policy. No GitHub personal token is
installed on the instance. An existing registration is never overwritten.

The deployment runner has cluster-admin access and its instance profile can read
application credentials. Restrict which workflows may target it; never run
untrusted PR jobs there. The CD workflow accepts only successful same-repository
push builds from main. Protect main and review workflow changes. See
[GitHub's runner security guidance](https://docs.github.com/en/actions/concepts/security/compromised-runners).

## Keep registry/database credentials current

ECR tokens expire. Without the maintenance timer, scaling or replacing a pod can
fail with `ImagePullBackOff` after a quiet period. RDS also rotates its managed
password. Copy a reviewed checkout to the instance and install the maintained
scripts, then create a root-owned configuration file with **non-secret** outputs:

```bash
sudo install -d -m 755 /usr/local/lib/marketly
sudo install -m 755 scripts/refresh-ecr.sh scripts/sync-secrets.py /usr/local/lib/marketly/
sudo install -m 644 scripts/systemd/marketly-maintenance.* /etc/systemd/system/
sudoedit /etc/marketly.env
```

Contents (replace each value with Terraform outputs):

```text
AWS_REGION=us-east-1
ECR_REGISTRY=ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
DATABASE_HOST=YOUR-RDS-ENDPOINT
DATABASE_SECRET_ARN=YOUR-RDS-SECRET-ARN
```

After the first deployment has created the namespace and deployments:

```bash
sudo chmod 600 /etc/marketly.env
sudo systemctl daemon-reload
sudo systemctl enable --now marketly-maintenance.timer
sudo systemctl start marketly-maintenance.service
sudo journalctl -u marketly-maintenance.service --no-pager
```

Credentials flow through stdin into Kubernetes Secrets and never appear as
command-line arguments. The shared signing key is generated once and preserved.
Do not delete `app-secrets` during normal deployment. A key rotation invalidates
existing access tokens; coordinate all three services when doing it deliberately.
Update `/etc/marketly.env` and GitHub variables after replacing RDS or changing
region/account. Review and reinstall these scripts after updating the checkout.

## Health and scaling

```bash
kubectl -n marketly get pods,svc,ingress,hpa
kubectl -n kube-system get svc traefik
./scripts/healthcheck.sh
kubectl -n marketly top pods
kubectl -n marketly describe hpa orders-service
```

Traefik should be a NodePort service with web port `30080`. The ALB forwards to
that port and checks `/health`, routed to the frontend. All backends also have
independent `/health` probes. Check `kubectl logs` and AWS target health if the
ALB returns 503. K3s includes metrics-server; resolve missing metrics before
attempting an HPA demonstration.

For a load demonstration, run concurrent requests to `/api/orders` using a test
customer's bearer token. Watch `kubectl -n marketly get hpa,pods -w` and
`kubectl -n marketly top pods`. CPU use must exceed the configured 60% target
long enough to trigger scaling; a low request count may not do so. Record the
observed replica changes and return to idle. HPA changes pod count only; the
worker ASG has a fixed desired capacity of two and no cluster autoscaler.
Four replicas may require more worker capacity; adjust the ASG/instance sizing
in Terraform before attempting larger loads.

`BASE_URL=http://YOUR-ALB DURATION_SECONDS=180 CONCURRENCY=24 python3
scripts/load-test.py` creates one unique test customer and sends authenticated
read requests for a bounded period. It prints request totals without tokens and
places no orders. Record HPA/current replica observations separately; successful
requests alone do not prove scaling. Allow the HPA's downscale stabilization
window to elapse after the load ends.

## Deployment and rollback

`IMAGE_TAG` must be a full 40-character commit SHA present in all four ECR
repositories. The script renders images into a temporary copy of the manifests,
creates/refreshes runtime secrets and checks every Deployment in `marketly`.
It never rewrites checked-in YAML with environment-specific values.

Rollback all components together by rerunning `scripts/deploy-k8s.sh` with a
previously tested SHA and the same environment variables. This rolls back images,
not database contents; schema changes require their own rollback plan.

## Debugging the PostgreSQL migration

The starting code imported `psycopg2` but still called SQLite's connection-level
`execute`, `executemany`, `lastrowid` and `PRAGMA table_info`. Startup failed before
any service could become healthy. The repaired code uses psycopg2 cursors through
a small connection adapter, PostgreSQL `RETURNING`, and serialized schema setup.
The regression test then caught a response-shape mismatch in its own profile
assertion, which was corrected against the existing API contract.

A separate configuration fault set `CATALOG_URL` while the code reads
`CATALOG_SERVICE_URL`; fixing that restored order-to-catalog calls in containers.
The end-to-end test now checks both the returned order and the changed inventory.

## Debugging GitHub OIDC

The first live pipeline reached AWS authentication but failed with
`Not authorized to perform sts:AssumeRoleWithWebIdentity`. The repository's
OIDC API reported immutable subjects containing owner/repository IDs, while
Terraform trusted the older name-only subjects. Set `github_oidc_subject_prefix`
and repository variable `OIDC_SUBJECT_PREFIX` from the API's `sub_claim_prefix`.
The fix preserves exact branch/environment restrictions. Mock tests cover both
formats. See [GitHub's OIDC reference](https://docs.github.com/en/actions/reference/security/oidc).

## Limitations to explain in a demo

The application uses one RDS database/account, with table ownership by convention.
It does not migrate historical data from the old SQLite fixture files. Authentication
rate limits remain per process. Catalog reservations are atomic, but a process
crash between catalog updates and order commit can require inventory reconciliation;
compensation is best-effort rather than a distributed transaction. Cancellation
and refresh-token locks prevent ordinary concurrent double use, but do not provide
crash recovery across services. The ALB is HTTP for this lab; configure an ACM
certificate, HTTPS listener, DNS and secure cookies before handling real users.

## Teardown

Export any data needed for the demo, stop/remove the GitHub runner registration,
then run `scripts/teardown.sh` using a bootstrap identity. RDS and repository data
are intentionally disposable. The IAM CI provisioning role does not own the
account-wide OIDC provider lifecycle; use the bootstrap identity for final destroy.
The protected state bucket/table remain for audit and must be explicitly cleaned
up separately when no longer needed. Verify the EC2, ASG, RDS, ALB and NAT instance
are gone; capture the destroy output as submission evidence.
