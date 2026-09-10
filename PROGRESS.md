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

**Phase 1 — Terraform Foundation: IN PROGRESS (repo setup complete, Terraform files not yet started)**

Planning and architecture decisions are approved. No AWS infrastructure has been provisioned yet.

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

Terraform networking files not yet started.

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

*To be populated during Phase 1.*

### Security Groups

*To be populated during Phase 1.*

### IAM Roles / Instance Profiles

*To be populated during Phase 1.*

### EC2 Instances

*To be populated during Phase 2.*

### Secrets

Reused from Project 1; no new secrets planned.

## Known Issues

None.

Phase 1 has not started.

## Definition of Done

### Terraform

- [ ] Terraform files written.
- [ ] `terraform fmt` produces clean formatting.
- [ ] `terraform validate` succeeds.
- [ ] `terraform plan` reviewed with expected resources only.
- [ ] `terraform apply` provisions infrastructure successfully.
- [ ] AWS infrastructure matches Terraform state.

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
- [ ] Terraform provider/version constraints defined.
- [ ] `.terraform.lock.hcl` generated/committed when appropriate.
- [x] Initial commit pushed.

## Next Step

### Phase 1 — Terraform Foundation

**Resume here:** repo scaffolding is complete and pushed. Next up:

1. Terraform basics walkthrough (provider block, version pinning, plan/apply model) — first hands-on Terraform in this project.
2. Write Terraform networking files:
   - `main.tf`
   - `variables.tf`
   - `outputs.tf`
   - `security_groups.tf`
   - `iam.tf`
3. Run `terraform fmt`, `terraform validate`, and `terraform plan`.

**No `terraform apply` until the initial plan has been reviewed.**

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
