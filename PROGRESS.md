# PROGRESS.md — iac-terraform-ansible (Project 2)

## Project

Infrastructure-as-Code implementation of the VProfile stack using Terraform (infrastructure provisioning) and Ansible (configuration management).

Automates the same VPC, EC2, IAM, and service configuration built manually in Project 1 (`aws-lift-and-shift`), replacing approximately 40 manual AWS CLI commands and userdata scripts with declarative, reproducible code.

## Portfolio Context

This is Project 2 of 5 planned portfolio projects.

Portfolio sequence:

- ✅ Project 1 — `aws-lift-and-shift` (CLOSED)
- 🟢 Project 2 — `iac-terraform-ansible` (CURRENT)
- Project 3 — `cicd-pipeline-vprofile`
- Project 4 — `aws-paas-migration`
- Project 5 — `k8s-gitops-vprofile`

The full roadmap and project rationale live in the master portfolio prompt. This file records only the implementation state of Project 2.

## Current Phase

**Phase 1 — Terraform Foundation: COMPLETE (infrastructure provisioned and verified 2026-09-12)**

**Phase 2 & 3 — Terraform EC2 Infrastructure, Apply & Verification: COMPLETE (2026-09-12)**

**SSM Connectivity — VERIFIED (2026-09-19):** SSM Session Manager confirmed working end-to-end to all 4 instances after resolving an AMI variant issue (see Known Issues). Ansible connectivity decision is now resolved: **SSM** is the confirmed connection method, using the AWS `community.aws` or `aws_ssm` Ansible connection plugin. Ready to proceed to Phase 4.

Originally planned as two separate phases (define resources, then apply/verify), but completed together in one continuous session — writing the 4 EC2 instance resources, running `terraform apply` (4 added, 0 changed, 0 destroyed), and verifying against live AWS state all happened without a gap between them, same as how Phase 1 was actually executed. Merged here to reflect actual project history rather than forcing an artificial split. Phase 4 (Ansible roles) requires resolving the Ansible connectivity decision (documented as open in Key Decisions) before role-writing begins.

## Project Baseline

Project 2 intentionally reproduces the **verified architecture from Project 1** before introducing Infrastructure-as-Code improvements.

The goal is feature parity first, automation second:

- Same networking architecture.
- Same IAM model.
- Same four application services.
- Same Secrets Manager integration.
- Same security group boundaries.

Architectural improvements (modules, remote state, ALB, Interface VPC Endpoints, Route 53, etc.) are treated as later enhancements rather than changing the baseline implementation.

## Key Decisions

### Infrastructure Decisions

- Terraform provisions AWS infrastructure.
- Ansible configures operating systems and application services.
- No userdata scripts for service installation; configuration happens through Ansible roles after instance creation.
- Local Terraform state (`terraform.tfstate`) for portfolio simplicity; S3 remote backend documented later as the production alternative.
- Flat Terraform files first; modular refactor deferred until fundamentals are complete.
- Project 1 EC2 instances will be terminated instead of imported into Terraform state.
- No ALB or Interface VPC Endpoints during Phase 1 scope.

### Security Decisions

- Reuse Project 1 Secrets Manager secrets:
  - `vprofile/db/admin-password`
  - `vprofile/rmq/test-password`
- No hardcoded credentials committed to the repository.
- Maintain the same least-privilege IAM model established in Project 1.

### Engineering Process Decisions

**Verification-first rule:**

> Nothing is marked COMPLETE until verified against live AWS state or successful tool output.

Implementation alone is not completion. Verification evidence is recorded before updating `PROGRESS.md`.

### Terraform Safety Decisions

- Terraform state remains local for this portfolio project and is excluded from Git.
- Review `terraform plan` before every apply.
- Review and explicitly approve destructive changes before `terraform destroy`.
- Pin Terraform provider versions and commit `.terraform.lock.hcl` when appropriate.
- Record the Terraform version used by the project.
- Terraform version verified via `terraform -version`: **v1.16.1** (upgraded from v1.15.7, installed via Chocolatey).
- AWS provider pinned to `~> 5.31.0` in `terraform/versions.tf`; verified via `terraform init` (initially mis-pinned as `~> 5.31`, which pulled v5.100.0 — corrected to three-segment constraint, re-verified at v5.31.0).
- AWS provider pinned to `~> 5.31.0` in `terraform/versions.tf`; verified via `terraform init` (initially mis-pinned as `~> 5.31`, which pulled v5.100.0 — corrected to three-segment constraint, re-verified at v5.31.0).

### Terraform / Ansible Boundary

Terraform owns infrastructure:

- VPC
- subnets
- routing
- security groups
- IAM
- EC2

Ansible owns post-boot configuration:

- packages
- service configuration
- application configuration
- service startup
- idempotent changes

No duplicated ownership unless a documented reason exists.

### Ansible Connectivity

Before implementing roles, choose and document the connection method used to reach private EC2 instances.

The connection method must fit the approved AWS architecture and must not introduce public SSH access merely for convenience.

## Completed Work

- GitHub repository `iac-terraform-ansible` created via `gh repo create` (private).
- `gh` CLI installed and authenticated (`winpty gh auth login` required — MinTTY has no PTY support).
- Repository cloned and located at `G:\Tutorial Folder\DevOpsTutorials\DevOps Project\iac-terraform-ansible`.
- Directory structure created: `terraform/`, `ansible/`, `docs/`.
- `.gitignore` written (Terraform state/vars, secrets/keys, Ansible retry files, OS junk — `.terraform.lock.hcl` intentionally NOT ignored).
- Initial commit `d4f4a03` pushed to `origin/master` — verified via `git log --oneline` and GitHub.

`terraform/versions.tf` and `.terraform.lock.hcl` written, verified, committed (`1b3e3e2`). Remaining networking files (`main.tf`, `variables.tf`, `outputs.tf`, `security_groups.tf`, `iam.tf`) not yet started.

- `terraform plan` run from `terraform/` (first attempt failed from repo root — no config files found there). Output: 17 to add, 0 to change, 0 to destroy — matches approved architecture exactly.
- `terraform apply` executed and completed successfully: 17 added, 0 changed, 0 destroyed.
- Live AWS state spot-verified against Terraform output: VPC (`vpc-0b7f81bc3fae90299`), public subnet 1a (`subnet-0b2832c32f46fe494`), and `vprofile-app-sg` (`sg-0936af3af55dc2f2b`, ingress correctly scoped to ALB security group as source, not CIDR) all confirmed matching.

## Implementation Phases

| Phase | Focus | Deliverables |
|-------|-------|-------------|
| Phase 1 | Terraform networking & IAM | VPC, subnets, route tables, Internet Gateway, security groups, IAM roles, successful `terraform validate` and `terraform plan`. |
| Phase 2 | Terraform EC2 infrastructure | MariaDB, Memcached, RabbitMQ, Tomcat instances defined in Terraform. |
| Phase 3 | Terraform apply & verification | Infrastructure created, AWS state verified against Terraform state. |
| Phase 4 | Ansible roles | Roles for MariaDB, Memcached, RabbitMQ, and Tomcat. |
| Phase 5 | Ansible execution & idempotency | Successful playbook execution and zero-change second run verification. |
| Phase 6 | Reproducibility & documentation | Destroy → recreate → verify test, README, architecture, decisions, incidents, and course coverage documentation. |

## Resource Reference

*Populated as Terraform provisions resources.*

### Networking

- VPC: `vpc-0b7f81bc3fae90299` (`172.20.0.0/16`)
- Public subnet 1a: `subnet-0b2832c32f46fe494` (`172.20.1.0/24`, us-east-1a)
- Public subnet 1b: `subnet-01551ca8aef1df0b4` (`172.20.2.0/24`, us-east-1b)
- Private subnet 1a: `subnet-09325f3c8dd077c24` (`172.20.3.0/24`, us-east-1a)
- Private route table: `rtb-0714706243c1f3494` (explicit association added Session 9; the private subnet had been relying on the VPC's default main route table with no explicit association since Phase 1)

### Security Groups

- `vprofile-alb-sg` — `sg-04f2f2d83159f5e1c`
- `vprofile-app-sg` — `sg-0936af3af55dc2f2b`
- `vprofile-db-sg` — `sg-0939ef1bb0fa7d572`
- `vprofile-mc-sg` — `sg-0a83f618b4a023ee5`
- `vprofile-ssm-ep-sg` — `sg-095cb993f3dfc8a34`
- `vprofile-rmq-sg` — `sg-0b8768c70645d442c`

### IAM Roles / Instance Profiles

- Role: `vprofile-ec2-role`
- Instance profile: `vprofile-ec2-instance-profile`
- Inline policy: `vprofile-secrets-access` (scoped to 2 Secrets Manager ARNs)
- Attached managed policy: `AmazonSSMManagedInstanceCore`

### EC2 Instances

- App tier (Tomcat): `i-07cd82896ef307617` (`t3.micro`, `172.20.3.33`, private subnet)
- DB tier (MariaDB): `i-00fad7b130b62fb64` (`t3.micro`, `172.20.3.56`, private subnet)
- Cache tier (Memcached): `i-0adafe2d23aa927fa` (`t3.micro`, `172.20.3.237`, private subnet)
- MQ tier (RabbitMQ): `i-0e3142d8be4ef6eee` (`t3.micro`, `172.20.3.106`, private subnet)

AMI: Amazon Linux 2023 **standard** variant (resolved dynamically via `data.aws_ami`, pinned per-instance via `lifecycle.ignore_changes`). Filter tightened to `al2023-ami-2023.*-x86_64` — see Known Issues for why the original `al2023-ami-*-x86_64` filter was insufficient. Instance IDs above are the third generation of these instances (recreated twice during Session 9 SSM troubleshooting).

### Secrets

Reused from Project 1; no new secrets planned.

## Known Issues

- Documentation miscount: this file previously stated Phase 1 would produce 13 resources; itemized breakdown actually sums to 17, matching `terraform plan`/`apply` output exactly. No config issue — corrected here.
- Cross-project naming collision: Project 1 (`aws-lift-and-shift`) and Project 2 reuse identical `Name` tags (e.g. `vprofile-app-sg`). An un-scoped tag-only AWS CLI query returned Project 1's SG instead of Project 2's. Fix: always scope security-group/resource lookups by VPC ID, not tag name alone, in this project.
- **Resolved 2026-09-12:** Project 1's documented "Existing AWS Project State" (master prompt) undercounted its security groups. Live AWS confirms 11 SGs in `vpc-0e686e7841a60b687` (not 9, not the 5 originally listed): `vprofile-alb-sg`, `vprofile-app-sg`, `vprofile-db-sg`, `vprofile-mc-sg`, `vprofile-ssm-ep-sg`, `vprofile-rmq-sg` (`sg-0ba3baa7a8a231777`), `vprofile-rmq-builder-sg`, `vprofile-ami-builder-sg`, `vprofile-secretsmgr-ep-sg`, `vprofile-ec2api-ep-sg`, `default`. Since `rmq-sg` was never in the master prompt's list, Project 2 never reproduced it. Fixed by adding `vprofile-rmq-sg` (`sg-0b8768c70645d442c`) to Project 2 directly, plus the corresponding `ssm_ep` ingress rule and a matching `mc`-tier `ssm_ep` rule that was also found missing during this fix (see NOTES.md Session 7).
- Unidentified VPC `vpc-0a0efac60df5e3724` found in the account (contains `docker-sg`, `sonar-sg`, no running instances). Origin unconfirmed as of this session. Not part of Project 1 or Project 2 scope. No cost impact (no instances, no NAT, no EIPs, no Interface endpoints found anywhere in the account during this session's cost audit).
- **Resolved 2026-09-19:** SSM Session Manager could not reach any of the 4 EC2 instances (`describe-instance-information` returned empty, `start-session` failed with `TargetNotConnected`) despite correct IAM role, security groups, and NACLs. Root cause: the `data.aws_ami` filter (`al2023-ami-*-x86_64`) matched both the standard and **minimal** AL2023 AMI variants; `most_recent = true` selected the minimal variant, which does not ship with the SSM agent pre-installed — unlike the standard variant. Fixed by tightening the filter to `al2023-ami-2023.*-x86_64`, which excludes the minimal variant's `al2023-ami-minimal-...` naming pattern, then forcing instance recreation via `terraform apply -replace` (required because `lifecycle.ignore_changes = [ami]` otherwise suppresses AMI updates on existing instances). Verified via `describe-instance-information` (all 4 instances `Online`) and a live `aws ssm start-session` to the DB instance.
- **Related, corrected during the same investigation:** the private subnet had no explicit route table association (falling back to the VPC's default main route table) since Phase 1. Fixed by adding an explicit `aws_route_table.private` + association. This was applied as a precautionary fix during troubleshooting but was **not the actual root cause** — the VPC's automatic local route already covered traffic to the endpoint ENIs regardless of explicit table content. Kept as a correct, explicit configuration going forward rather than relying on default/implicit routing.

## Definition of Done

### Terraform

- [x] Terraform files written.
- [x] `terraform fmt` produces clean formatting.
- [x] `terraform validate` succeeds.
- [x] `terraform plan` reviewed with expected resources only.
- [x] `terraform apply` provisions infrastructure successfully.
- [x] AWS infrastructure matches Terraform state.

### Ansible

- [ ] Roles created for Tomcat, MariaDB, Memcached, RabbitMQ.
- [ ] Inventory configured.
- [ ] Playbook executes successfully.
- [ ] Second execution is idempotent (zero changes).

### Verification

- [ ] All four services healthy.
- [ ] Application reachable.
- [ ] Destroy → recreate → verify reproducibility test completed.

### Documentation

- [ ] `README.md`
- [ ] `architecture.md`
- [ ] `decisions.md`
- [ ] `incidents.md`
- [ ] `course-coverage.md`
- [ ] `PROGRESS.md` finalized.

### Repository

- [ ] Clean Conventional Commit history.
- [ ] No secrets committed.
- [ ] `.terraform/`, Terraform state, and sensitive generated files excluded.
- [ ] End-to-end reproducible workflow with minimal manual steps.
- [ ] Final repository hygiene/cleanup checkpoint completed.

## Repository Status

- [x] GitHub repository `iac-terraform-ansible` created.
- [x] Local repository initialized.
- [x] Directory structure created (`terraform/`, `ansible/`, `docs/`).
- [x] `.gitignore` configured.
- [x] Terraform provider/version constraints defined.
- [x] `.terraform.lock.hcl` generated/committed.
- [x] Initial commit pushed.

## Next Step

### Phase 4 — Ansible Roles

Phase 2 & 3 complete and verified. Before writing Ansible roles: resolve the open Ansible Connectivity decision (see Key Decisions) — instances are private with no public IP or SSH access, so connectivity must go through the existing SSM infrastructure (SSM VPC endpoints + `ssm_ep` security group, both already provisioned) or an equivalent method that doesn't introduce public exposure.

## Assumptions

- Project 1 (`aws-lift-and-shift`) is fully completed and archived.
- AWS CLI configured for IAM user `gitops-terraform`.
- AWS Region: `us-east-1`.
- AWS Account: `747336059892`.
- Terraform installed locally — **verified**, v1.16.1 (see Key Decisions).
- Ansible installed locally.
- Git Bash is the primary shell environment.

## Notes

See `NOTES.md` for chronological study notes and session checkpoints.
