# Live deployment evidence

Status: in progress on 2026-09-17. Do not treat pending items as completed.

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
- [ ] Real main commit passes CI, Terraform and CD.
- [ ] ALB target health and public application smoke test.
- [ ] HPA scales under measured request load.
- [ ] Demo evidence captured and new application resources torn down.

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
