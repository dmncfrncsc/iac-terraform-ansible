# PROGRESS.md — iac-terraform-ansible (Project 2)

## Project

Infrastructure-as-Code implementation of the VProfile stack using Terraform (infrastructure provisioning) and Ansible (configuration management).

Automates the same VPC, EC2, IAM, and service configuration built manually in Project 1 (`aws-lift-and-shift`), replacing approximately 40 manual AWS CLI commands and userdata scripts with declarative, reproducible code.

## Portfolio Context

This is Project 2 of 5 planned portfolio projects.

Portfolio sequence:

- ✅ Project 1 — `aws-lift-and-shift` (CLOSED)
- Project 2 — `iac-terraform-ansible` (CURRENT)
- Project 3 — `cicd-pipeline-vprofile`
- Project 4 — `aws-paas-migration`
- Project 5 — `k8s-gitops-vprofile`

The full roadmap and project rationale live in the master portfolio prompt. This file records only the implementation state of Project 2.

## Current Phase

**Phase 1–3 — Terraform Foundation, EC2, Apply & Verification: COMPLETE.**

**Phase 4 — Ansible Roles: functionally complete and verified.** All 4 roles have completed successful live runs. The `tomcat` role now matches the verified live state (Tomcat 10, correct paths), and the `jdbc.password`/`rabbitmq.password` mismatch is fixed via a templated `application.properties` rendered from real Secrets Manager values at deploy time — replacing the WAR's baked-in `admin123`/`test` defaults, following the same "write real credentials at boot, don't edit compiled defaults" pattern Project 1 used.

**Phase 5 — Ansible execution & idempotency: COMPLETE.** A full second run across all 4 hosts returned `changed=0, failed=0` for every host (`mariadb01` and `rabbitmq01` each with one correctly-skipped task). Getting there required finding and fixing three real idempotency bugs this session — see Key Decisions and Known Issues.

**Phase 6 — Reproducibility & Documentation: IN PROGRESS.** Full `terraform destroy` (35 destroyed) → `terraform apply` (35 added) cycle completed successfully from a blank state — including repeating the RabbitMQ temporary-NAT-Gateway bootstrap (confirmed necessary again, same as Session 14; NAT resources added, used, destroyed, and removed from code, `terraform plan` confirmed `No changes` afterward). The subsequent backend TCP connectivity failure (3306/11211/5672 from `tomcat01`) is **RESOLVED** — root cause was three hardcoded Route 53 A records (`db01`/`mc01`/`rmq01`) that still pointed at the *previous* rebuild's private IPs; a fresh instance doesn't reuse its old IP, so DNS was silently stale. Fixed by referencing `aws_instance.<name>.private_ip` instead of literal strings, verified via `terraform plan` (3 changed, 0 added/destroyed), `apply`, and live TCP reachability tests from `tomcat01` (all 3 ports succeed). Commit `e6af0b3`. A full second playbook run across all 4 hosts post-fix confirmed `changed=0, failed=0` on every host (`mariadb01`/`rabbitmq01` each with the expected 1 skip, same guarded tasks as Session 18) — idempotency holds on a genuinely rebuilt environment, not just the original. The `README.md` has now been drafted from the verified project state and adopted by the user. Remaining Phase 6 work: refresh the stale Resource Reference table from the latest rebuild values, create `docs/architecture.md`, `docs/decisions.md`, `docs/incidents.md`, and `docs/course-coverage.md`, then complete the final repository hygiene checkpoint.

## Project Baseline

Project 2 intentionally reproduces the **verified architecture from Project 1** before introducing Infrastructure-as-Code improvements.

The goal is feature parity first, automation second:

- Same networking architecture.
- Same IAM model.
- Same four application services.
- Same Secrets Manager integration.
- Same security group boundaries.

Architectural improvements (modules, remote state, ALB, Interface VPC Endpoints, Route 53 was added in Session 15–16 as a course-taught exception) are otherwise treated as later enhancements rather than changing the baseline implementation.

## Key Decisions

### Infrastructure Decisions

- Terraform provisions AWS infrastructure.
- Ansible configures operating systems and application services.
- No userdata scripts for service installation; configuration happens through Ansible roles after instance creation.
- Local Terraform state (`terraform.tfstate`) for portfolio simplicity; S3 remote backend documented later as the production alternative.
- Flat Terraform files first; modular refactor deferred until fundamentals are complete.
- Project 1 EC2 instances will be terminated instead of imported into Terraform state.
- No ALB or Interface VPC Endpoints during Phase 1 scope.
- S3 Gateway VPC Endpoint (`aws_vpc_endpoint.s3`) added in Phase 4 — required for Ansible's `aws_ssm` connection plugin, which relays file transfers through S3. Free (Gateway type), associated with the private route table only.
- RabbitMQ is installed via Ansible from the official RabbitMQ/Cloudsmith dnf repositories (not a golden AMI, unlike Project 1).
- Any Python package a role needs that isn't available via `dnf` follows the S3-hosted-wheel pattern rather than reaching PyPI directly.
- A temporary NAT Gateway is the accepted pattern for one-time bootstrap installs with a real, non-trivial dependency chain, torn down and removed from code immediately after use.
- **Tomcat version corrected from 9 to 10** — verified against official Tomcat/Spring documentation. Fixed manually on the live instance in Session 15, and the Ansible role brought into line with that fix this session (commit `90b1179`).
- **Private Route 53 hosted zone (`vprofile.internal`) added for internal service DNS**, paired with a VPC DHCP option set (`domain_name = vprofile.internal`) so bare hostnames actually resolve — the zone alone wasn't sufficient without the DHCP fix (Session 16).
- **Application credentials are rendered at deploy time from a Jinja2 template, not left as the WAR's baked-in defaults.** The WAR ships `jdbc.password=admin123` and `rabbitmq.password=test` — confirmed (via Project 1's own `PROGRESS.md`) to be the reference app's original Vagrant-era defaults, the same `admin123` Project 1's `mysql.sh` originally hardcoded before its own Secrets Manager migration. Project 1's own architecture never edited these baked-in values — it dynamically wrote a fresh `application.properties` at boot using real fetched secrets. This session replicates that same pattern via Ansible: a `templates/application.properties.j2` file (owned by the `tomcat` role) with `jdbc.password`/`rabbitmq.password` parameterized, rendered via `amazon.aws.secretsmanager_secret` lookups (`vprofile/db/app-password`, `vprofile/rmq/test-password`) and deployed to the Tomcat-exploded `webapps/vprofile/WEB-INF/classes/` path (not the `.war` archive itself, which Tomcat doesn't re-read), with `mode: '0640'` since the file now contains a live database password. A `wait_for` task polls for the exploded directory to exist first, since Tomcat only creates it a few seconds after service start.
- **Three Ansible idempotency bugs found and fixed via a real second full-playbook run, not assumed from a single successful pass:**
  - `mariadb`'s root-password task lacked `login_password`/`login_user`, letting MariaDB's `mysql_user` module silently switch root off `unix_socket` auth after the first run — fixed by adding both alongside the existing `login_unix_socket`, restoring `check_implicit_admin` to a genuine fallback.
  - `mariadb`'s schema-import task (`state: import`) re-ran the schema's `DROP TABLE`/`CREATE TABLE`/`INSERT` statements unconditionally on every run — a real data-loss risk, not just wasted work. Fixed with a new read-only precondition check (`information_schema.tables` row count) gating the import behind `when:`.
  - `rabbitmq`'s GPG-key-import task (`rpm_key` with a URL `key:`) always re-fetched the key from `github.com`, with no network path since the temporary NAT Gateway (Session 14) was torn down — timed out on this run. Confirmed the key was already genuinely present, then guarded the fetch behind a new `rpm -q gpg-pubkey | grep` precondition check.

### Security Decisions

- Reuse Project 1 Secrets Manager secrets:
  - `vprofile/db/admin-password`
  - `vprofile/rmq/test-password`
- Dedicated `vprofile/db/app-password` secret created in Project 2 for the least-privilege `admin` MariaDB app user (separate from root).
- No hardcoded credentials committed to the repository.
- `application.properties` on the live instance is now `mode: 0640`, owned `tomcat:tomcat` — verified this session that a non-privileged SSM session user (`ssm-user`) genuinely cannot read it without `--become`, confirming the permission actually restricts access rather than being cosmetic.
- Maintain the same least-privilege IAM model established in Project 1.

### Engineering Process Decisions

**Verification-first rule:**

> Nothing is marked COMPLETE until verified against live AWS state or successful tool output.

**Git identity is environment-specific, reinforced this session:** WSL's Git had no configured identity (never used for commits before), causing a failed commit attempt mid-session. Per Session 13's existing working agreement, all `git` commands run in Git Bash only — this was a one-off slip, not a policy change, and the fix was switching shells, not configuring a second Git identity in WSL.

**`git commit --amend` used once this session, safely** — the initial `tomcat10` fix commit was staged and committed before the new template folder was added, understating what the commit actually contained. Since the commit was still local/unpushed (confirmed via `git status` showing "ahead of origin by N commits" before amending), amending it to include the template folder and an accurate message was safe — this is different from rewriting already-pushed/shared history, which this project's hygiene rules avoid.

### Terraform Safety Decisions

- Terraform state remains local for this portfolio project and is excluded from Git.
- Review `terraform plan` before every apply.
- Review and explicitly approve destructive changes before `terraform destroy`.
- Pin Terraform provider versions and commit `.terraform.lock.hcl` when appropriate.
- Terraform version verified via `terraform -version`: **v1.16.1**.
- AWS provider pinned to `~> 5.31.0` in `terraform/versions.tf`.
- `terraform/ec2.tf` periodically shows as "modified" under WSL's Git but not Git Bash's — confirmed this session (via `git diff --stat`: 80 insertions/80 deletions, identical content) to be a CRLF/LF line-ending artifact from cross-environment editing, not a real change. Left uncommitted deliberately; to be normalized during the eventual Repository Hygiene Checkpoint, not chased mid-session.

### Terraform / Ansible Boundary

Terraform owns infrastructure: VPC, subnets, routing, security groups, IAM, EC2.
Ansible owns post-boot configuration: packages, service configuration, application configuration, service startup, idempotent changes.

### Ansible Connectivity

Connection method: **SSM**, via the `community.aws`/`amazon.aws` `aws_ssm` Ansible connection plugin. Confirmed working end-to-end since Session 11.

## Completed Work

- GitHub repository `iac-terraform-ansible` created, cloned, Phase 1–3 Terraform written/applied/verified.
- All 4 EC2 instances provisioned and SSM-verified reachable.
- WSL2 + pipx Ansible control node fully set up; `aws_ssm` connectivity verified end-to-end.
- All 4 Ansible roles (`tomcat`, `mariadb`, `memcached`, `rabbitmq`) written, all completed successful live runs at least once.
- Tomcat 404 root-caused and fixed (Jakarta/Servlet namespace mismatch, Tomcat 9 → 10).
- Private Route 53 zone + DHCP option set added for internal DNS; DNS and backend TCP reachability (3306/11211/5672) verified from `tomcat01`.
- **This session:**
  - `mariadb`/`rabbitmq` Secrets Manager lookup-namespace fix committed (`f096304`).
  - Route 53 + DHCP option set Terraform additions committed (`ef2e2b7`).
  - `tomcat` role reconciled to install `tomcat10` (matching the verified manual fix), plus new tasks rendering `application.properties` from a Jinja2 template with real `jdbc.password`/`rabbitmq.password` values fetched from Secrets Manager — committed together (`90b1179`), verified via a scoped `--limit tomcat01` playbook run (`changed=2`, `failed=0`), `systemctl is-active` → `active`, `curl` → `200`, and the rendered file's real password confirmed via an `ansible ... -b` (`--become`) ad-hoc read.
  - `terraform/ec2.tf`'s apparent diff identified as a harmless CRLF artifact, deliberately left uncommitted.
- **This session (Session 20):**
  - Root-caused post-rebuild backend connectivity failure to 3 hardcoded Route 53 A records; fixed by referencing `aws_instance.<name>.private_ip`, verified via `terraform plan`/`apply` and live TCP checks, committed and pushed (`e6af0b3`).
  - Full second playbook run across all 4 hosts post-fix: `changed=0, failed=0` confirmed, closing out the Phase 6 reproducibility test.
  - `PROGRESS.md`/`NOTES.md` updated to reflect both (`8749a04`).
- README.md drafted from the verified project state, cross-referenced against the project notes and master prompt, and adopted by the user.

## Implementation Phases

| Phase | Focus | Deliverables | Status |
|-------|-------|-------------|--------|
| Phase 1 | Terraform networking & IAM | VPC, subnets, route tables, IGW, SGs, IAM roles | COMPLETE |
| Phase 2 | Terraform EC2 infrastructure | MariaDB, Memcached, RabbitMQ, Tomcat instances | COMPLETE |
| Phase 3 | Terraform apply & verification | Infrastructure created, state verified | COMPLETE |
| Phase 4 | Ansible roles | Roles for all 4 services | **COMPLETE** — all 4 verified running; Tomcat 404 and credential-mismatch both fixed and verified |
| Phase 5 | Ansible execution & idempotency | Successful run + zero-change second run | **COMPLETE** — full 4-host second run verified `changed=0, failed=0`, three idempotency bugs found and fixed this session |
| Phase 6 | Reproducibility & documentation | Destroy → recreate → verify, README, supporting docs | **IN PROGRESS** — reproducibility and README complete; supporting docs and final hygiene remain |

## Resource Reference

### Networking

- VPC: `vpc-08bd435f56891523a` (`172.20.0.0/16`)
- Public subnet 1a: `subnet-0c9bbb90999b99dca` (`172.20.1.0/24`, us-east-1a)
- Public subnet 1b: `subnet-0169a70a3bc05097e` (`172.20.2.0/24`, us-east-1b)
- Private subnet 1a: `subnet-0812a6b32b9949a73` (`172.20.3.0/24`, us-east-1a)
- Private route table: `rtb-05b10770ce329090f`
- S3 Gateway VPC Endpoint: `vpce-02cfb0a1860f904f5`
- VPC DHCP option set: `dopt-0d69face8dc93db76`
- Route 53 private hosted zone: `vprofile.internal` — zone id `Z07956241HBR3FVYWP3CB`
  - `db01.vprofile.internal` → `172.20.3.103`
  - `mc01.vprofile.internal` → `172.20.3.186`
  - `rmq01.vprofile.internal` → `172.20.3.245`

### Security Groups

- `vprofile-alb-sg` — `sg-0a1f1d3eb695e0b9f`
- `vprofile-app-sg` — `sg-00326644e64269700`
- `vprofile-db-sg` — `sg-00e621a08a33938e5`
- `vprofile-mc-sg` — `sg-00112dec9af86fba4`
- `vprofile-ssm-ep-sg` — `sg-04d98abaeb5f53e82`
- `vprofile-rmq-sg` — `sg-076f05b512766a6c6`

### IAM Roles / Instance Profiles

- Role: `vprofile-ec2-role`
- Instance profile: `vprofile-ec2-instance-profile`
- Inline policies: `vprofile-secrets-access`, `vprofile-s3-artifacts-access`
- Attached managed policy: `AmazonSSMManagedInstanceCore`

### EC2 Instances

- App tier (Tomcat): `i-07cdc61e6b1142ec5` (`t3.micro`, `172.20.3.15`)
- DB tier (MariaDB): `i-0fe7a3a6b6a2f0370` (`t3.micro`, `172.20.3.103`)
- Cache tier (Memcached): `i-02b3dc69a55f16042` (`t3.micro`, `172.20.3.186`)
- MQ tier (RabbitMQ): `i-069441e9930abc795` (`t3.micro`, `172.20.3.245`)

### Secrets

- `vprofile/db/admin-password` (root), `vprofile/rmq/test-password` — reused from Project 1.
- `vprofile/db/app-password` — dedicated `admin` MariaDB app-user password. Now also rendered into the live `application.properties` via the `tomcat` role.

### Ansible Control Node & Connectivity

- Control node: WSL2 (Ubuntu), pipx-isolated Ansible 14.4.0 (ansible-core 2.21.4).
- Collections: `amazon.aws`, `community.aws`, `ansible.mysql`, `community.rabbitmq`.
- S3 relay bucket: `vprofile-ansible-ssm-1790055238`.
- Static inventory: `ansible/inventory/hosts.yml`.
- Top-level playbook file: `ansible/playbook.yml` (not `site.yml`).
- Git commands run in Git Bash only, per Session 13's working agreement — reinforced this session after a failed commit attempt from WSL.

### S3 Artifacts Bucket Layout

- `db/accountsdb.sql` — MariaDB schema.
- `deps/pymysql-1.2.3-py3-none-any.whl` — standard location for any future Python dependency not available via `dnf`.
- `app/vprofile-v2.war` — application WAR, fetched by the `tomcat` role.

## Known Issues

*(Cross-project naming collisions, the unidentified second VPC, and other early resolved issues — see prior session history, omitted here for length. Nothing regressed.)*

- **Resolved:** `community.aws.secretsmanager_secret` lookup-namespace bug — fixed, committed (`f096304`).
- **Resolved:** no PyMySQL package in AL2023's default repos — S3-hosted-wheel pattern established.
- **Resolved:** private subnet has no general internet route — temporary NAT Gateway pattern established for RabbitMQ.
- **Resolved:** Tomcat 404 — Tomcat 9 → 10, fixed manually and now in code (`90b1179`).
- **Resolved:** bare backend hostnames unresolvable — Route 53 zone + DHCP option set, committed (`ef2e2b7`).
- **Resolved:** `jdbc.password=admin123` / `rabbitmq.password=test` mismatch — fixed via templated `application.properties` with real Secrets Manager values, committed and verified (`90b1179`).
- **Resolved:** second full playbook execution/idempotency check — completed this session; `changed=0, failed=0` across all 4 hosts, after fixing 3 idempotency bugs (see Key Decisions).


- **Resolved:** post-rebuild backend TCP connectivity failure (3306/11211/5672 from `tomcat01`) — root cause was 3 hardcoded Route 53 A records left pointing at the prior rebuild's IPs instead of referencing the instances dynamically. Fixed via `aws_instance.<name>.private_ip` references, committed and pushed (`e6af0b3`), verified via `terraform plan`/`apply` and live TCP checks on all 3 ports.
- **Note (not an issue):** `terraform/ec2.tf` shows as modified under WSL's Git only — confirmed CRLF-only artifact, deliberately left uncommitted; normalize during the Repository Hygiene Checkpoint.

## Definition of Done

### Terraform

- [x] Terraform files written, formatted, validated, applied. AWS state matches.

### Ansible

- [x] Roles created for Tomcat, MariaDB, Memcached, RabbitMQ.
- [x] Inventory configured.
- [x] Playbook executes successfully across all 4 hosts.
- [x] Second execution is idempotent (zero changes) — verified this session across all 4 hosts.

### Verification

- [x] All four services healthy — Tomcat 10 running, VProfile app returns HTTP 200, real credentials confirmed rendered.
- [x] Application reachable from Tomcat host — `curl http://localhost:8080/vprofile/` returns `200`.
- [x] Browser-level application evidence — captured at `docs/images/vprofile-login-page.png`, verified via SSM port forwarding to `localhost:8080/vprofile/`.
- [x] Destroy → recreate → verify reproducibility test completed — full destroy/apply cycle, DNS root-cause fix, and post-fix idempotency re-run (`changed=0, failed=0` all 4 hosts) all verified this session.

### Documentation

- [x] `README.md` — drafted from verified project state, committed and pushed (`c1d7822`).
- [x] `architecture.md` — committed and pushed (`c1d7822`).
- [x] `decisions.md` — committed and pushed (`c1d7822`).
- [x] `incidents.md` — committed and pushed (`c1d7822`).
- [x] `course-coverage.md` — committed and pushed (`c1d7822`).
- [x] `PROGRESS.md` — updated this session (Resource Reference refreshed against verified post-rebuild AWS state).

### Repository

- [x] Clean Conventional Commit history — 3 commits this session (`f096304`, `ef2e2b7`, `90b1179`), amend used once to correct an inaccurate message before pushing.
- [x] No secrets committed.
- [x] Final repository hygiene/cleanup checkpoint completed — .gitattributes added (4257d05), .gitignore completeness fold-in, closing commit (0f24e16).

## Next Step

### Resume here — Final repository hygiene checkpoint

All Phase 6 documentation is committed and pushed (`c1d7822`): `README.md`, `docs/architecture.md`, `docs/decisions.md`, `docs/incidents.md`, `docs/course-coverage.md`. The Resource Reference table above reflects current post-rebuild AWS state, verified this session via `describe-route-tables`, `describe-vpc-endpoints`, and `describe-security-groups`.

Only the repository hygiene checkpoint remains before Project 2 can be closed:

1. Normalize `terraform/ec2.tf`'s CRLF/LF line-ending diff (deferred since Session 17 — confirmed harmless, WSL-only artifact).
2. Run the general cleanup checklist: accidental files, duplicate artifacts, `.gitignore` correctness, clean `git status`.
3. One final `chore:` commit closing out the project.

**Cost note:** All 4 instances `running`, Route 53 zone live (~$0.50/month). No NAT Gateway/EIP present. Re-verify instance state at next session start regardless — it has drifted before.
