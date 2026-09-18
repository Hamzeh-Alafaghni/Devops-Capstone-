# Live deployment evidence

Status: live deployment verified on 2026-09-18; teardown verification pending.

## Account and resource preservation

- AWS account: `678419966897`; region: `us-east-1`.
- Repository: `Hamzeh-Alafaghni/Devops-Capstone-` (trailing hyphen required).
- Existing VPC `vpc-0b16400807d701b71` and its internet gateway are read-only data sources.
- Four new subnet ranges: `10.0.10.0/24` through `10.0.13.0/24`.
- Existing `k3s-workers-asg`, its workers, and `ecommerce-db` remain outside the new Terraform state.
- The existing database is in a different VPC and has not been changed or migrated.
- Bootstrap apply: 6 added, 0 changed, 0 destroyed.
- Application plan: 51 to add, 0 to change, 0 to destroy.
- Remote state: encrypted/versioned S3 with a DynamoDB lock table.

## Checks

- [x] Local Compose images, PostgreSQL, smoke and concurrency regressions.
- [x] Terraform validation and both mock-provider tests.
- [x] Workflow lint, Bash syntax and 12 Kubernetes schema checks.
- [x] GitHub variables and environment restrictions configured.
- [x] Application Terraform apply completed: 51 added, 0 changed, 0 destroyed.
- [x] SSM online; all three k3s nodes Ready, with metrics-server and Traefik running.
- [x] Self-hosted deployment runner registered and online; temporary registration token/grant removed.
- [x] Real main commit `a17f54b9c7f4e102f100fb9d520f0b197ee6cd18` passed CI, Terraform and CD.
- [x] Both ALB worker targets healthy; complete public application smoke test passed.
- [x] HPA scaled orders-service from 2 to 4 replicas at 13:31 UTC on 2026-09-18.
- [x] Actual terminal demo recorded; hourly credential maintenance installed and verified.
- [x] $20 monthly account-wide budget with email alerts at 80% and 100% configured.
- [ ] New application resources torn down; existing resources preserved.

Bootstrap state remains in `terraform/bootstrap/terraform.tfstate` and must not be committed.

## First pipeline run

Commit `03c3706` pushed to main.

- [CI](https://github.com/Hamzeh-Alafaghni/Devops-Capstone-/actions/runs/35200161692): failed at OIDC authentication (immutable subject mismatch; fixed in the next commit).
- [Terraform](https://github.com/Hamzeh-Alafaghni/Devops-Capstone-/actions/runs/35200161698): failed at OIDC authentication (immutable subject mismatch; fixed in the next commit).
- New control plane: `i-01c3cfe9f07d30dd2`.
- ALB: `http://marketly-alb-1467190685.us-east-1.elb.amazonaws.com`.

## Historical credential finding

A literal database password exists in commit `64e1d8a`, file
`terraform/modules/rds/main.tf`. Its value is deliberately omitted. Current RDS
uses a new AWS-managed password. Historical credentials should be treated as
exposed wherever reused. Removing public history requires a coordinated rewrite;
it has not been performed.

## Successful pipeline and live checks

- [CI: test, build, push](https://github.com/Hamzeh-Alafaghni/Devops-Capstone-/actions/runs/35200737033) — passed.
- [Terraform plan/apply](https://github.com/Hamzeh-Alafaghni/Devops-Capstone-/actions/runs/35200737082) — passed using OIDC.
- [Self-hosted CD](https://github.com/Hamzeh-Alafaghni/Devops-Capstone-/actions/runs/35200871016) — passed, all four deployments rolled out and health-checked.
- [Recorded terminal demo](evidence/demo.html), [raw asciicast](evidence/demo.cast), [HPA observations](evidence/hpa.txt).
- New control plane and two workers were Ready on k3s `v1.32.13+k3s1` with no public node IPs.
- ALB targets `i-021b5d1d1087cf73d` and `i-077e9f5116f49c5c2` both healthy on port 30080.
- Public smoke test covered registration/login, JWT authorization, catalog, authoritative prices, inventory, concurrent cancellation, refresh rotation, and logout.
- Maintenance timer successfully refreshed ECR and RDS credentials on 2026-09-18; next run scheduled hourly.
- Budget `marketly-monthly`: $20 USD/month, actual-spend notifications above 80% and 100%; recipient stored only in ignored local bootstrap settings and AWS.

## Load-test results and limits

The first external load test used 24 concurrent readers for 180 seconds:
7,310 successful requests and 12 failures. Its original error handling did not
classify those failures, so their exact cause cannot be established from that
run. Pod events show successful scaling with no restarts, and the sampled
orders-service logs contain no matching server errors. The load script now
reports failure types for follow-up diagnosis. This is a capstone capacity
demonstration, not a production reliability certification.

Observed CPU rose to 258% of requests against a 60% target; HPA requested four
replicas and all four became Ready. Idle CPU subsequently returned to 1%, with
the normal downscale stabilization window in effect.

Follow-up external test: 12 readers for 60 seconds, 725 successes and five
client `timeout` failures. The equivalent in-AWS NodePort/Traefik test completed
10,880 requests with zero failures in 60 seconds. During the external tests,
ALB metrics returned no target/ELB 5xx datapoints and maximum observed per-minute
p99 target response time was 0.2254 seconds. This supports an external-client or
network-path explanation; the exact cause of the external timeouts is not proven.
Raw results: [external](evidence/external-load.txt), [in-AWS](evidence/internal-load.txt).
