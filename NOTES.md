# NOTES.md — iac-terraform-ansible (Project 2)

Study notes, chronological by session. Short definitions + real examples from this project.

## Session 1 — 2026-09-09 — Repo Setup

**MinTTY has no PTY support** — Git Bash's terminal (MinTTY) can't run tools that need
an interactive pseudo-terminal (arrow-key menus, live prompts). Same root cause as the
`winpty python` requirement.

*This project:* `gh auth login` failed with "You appear to be running in MinTTY without
pseudo terminal support" — fixed with `winpty gh auth login`.

**Cross-device `mv`** — `mv` between different drives (e.g. C: → G:) can't do an atomic
rename; it copies then deletes. If the destination already has a same-named non-empty
folder, it fails with "unable to remove target: Directory not empty" instead of merging.

*This project:* had a stray `iac-terraform-ansible/PROGRESS.md` already sitting on G:
from before the repo existed — had to move that file into the cloned repo first, then
`rmdir` the empty leftover folder, then `mv` the real repo into place.

**Git line-ending conversion (CRLF/LF)** — On Windows, Git's `core.autocrlf` setting
converts LF → CRLF in your working directory and back on commit. The "LF will be
replaced by CRLF" warning on `git add` is expected behavior, not an error.

*This project:* saw this on `git add .gitignore PROGRESS.md` — no action needed.

**`gh repo create --clone`** — clones into your *current* working directory at the time
the command runs, not a directory you `cd` into afterward. Always `cd` to the target
location first.

*This project:* ran `gh repo create ... --clone` from `~`, so it cloned into
`~/iac-terraform-ansible` instead of the intended `G:\...\DevOps Project\`, requiring
a manual move afterward.

## Session 2 — 2026-09-10 — Terraform Version Verification

**Chocolatey installs/upgrades need an elevated shell** — Chocolatey installs packages
under `C:\ProgramData\...`, a system-owned folder. A non-admin terminal can run `choco`
but can't write there, so upgrades fail with `UnauthorizedAccessException: Access ... is
denied` after retrying each file 2-3 times, even after confirming "Y" to proceed.

*This project:* `choco upgrade terraform -y` from a normal Git Bash window failed on
every file under `chocolatey\lib\terraform\`. Re-running the identical command from
Git Bash opened via "Run as administrator" succeeded — Terraform went from v1.15.7 to
v1.16.1. Same root cause as `winpty` and package-manager admin requirements: Windows
permission boundaries, not a tool bug.

## Session 3 — 2026-09-10 — Requirements-to-Architecture Reasoning

**Architecture isn't invented from taste — it's derived by matching plain-English
requirements to a small set of trigger words**, then asking two follow-up questions
per component: *who needs to reach it, from where* (→ public vs. private placement),
and *on what specific ports/protocols even among things allowed to talk* (→ security
group rules).

**Trigger-word lookup table** (the actual mechanism, not intuition):

| Phrase in requirements | Component it implies |
|---|---|
| store / save / permanent / record / history | database |
| real-time / instantly / live update | push/messaging system |
| email / SMS / notification / receipt | separate notification service |
| browse / search / view a list of | read-facing API/backend |
| upload a photo / file / video | file/object storage |
| pay / checkout / charge a card | payment component |
| log in / sign up / account | authentication/user management |
| any device/app talking to "the system" | an API/backend it connects to |

*This project:* not yet applied to a real in-project decision — practiced so far only
on hypothetical apps (blog, food-delivery). Next real application should be an actual
Project 2 decision (e.g., Ansible connectivity method) reasoned out *before* being
told the answer, not after.

**Working agreement going forward:** for real architecture/design decisions in this
project (not hypotheticals), the requirement/constraint gets presented first and I
attempt to name the matching trigger word + component before the answer is confirmed,
instead of always receiving the fully-reasoned answer directly.



## Session 4 — 2026-09-11 — Terraform Fundamentals + Tooling Setup

**Declarative vs. imperative** — Project 1's AWS CLI commands were imperative (run this
step, then this step, then this step). Terraform is declarative: you describe the end
state you want, and Terraform figures out what needs to happen to reach it.

*This project:* a `resource "aws_vpc" "main" { cidr_block = "172.20.0.0/16" }` block
reads as a statement ("a VPC with this CIDR should exist"), not a command — there's no
verb like "create." That's what makes re-running the same files safe.

**Idempotency** — running the same operation multiple times produces the same end
result, with no duplicate side effects. This is *why* a Terraform resource block being
a description (not an instruction) matters: running `apply` twice with nothing changed
does nothing the second time, instead of creating a second copy of everything.

**Terraform state file (`terraform.tfstate`)** — Terraform's memory of what it already
created (resource IDs, properties). On every run it compares three things: what the
`.tf` files say should exist, what the state file says was already created, and what's
actually true in AWS right now.

*This project:* not yet generated — no resources exist yet, so no state file exists
yet either. Will appear the first time something is actually applied.

**`terraform plan`** — a read-only dry run. Shows what would be created (`+`), changed
(`~`), or destroyed (`-`) without touching AWS. Safe to run anytime; doesn't require
approval under this project's approval-gate rules, unlike `apply`.

**Configuration drift** — when real infrastructure no longer matches what the state
file believes exists (e.g., someone manually deletes a resource in the AWS console).
`terraform plan` catches this automatically by checking real AWS state, not just the
state file.

*This project:* reasoned through the example — if the VPC were deleted manually outside
Terraform, `plan` would report `1 to add`, because the state file still believes it
exists but AWS confirms it doesn't, and the `.tf` file still says it should.

**Terraform pessimistic constraint operator (`~>`) segment count changes its meaning**
— `~> 5.31` (two segments) only locks the *first* number, allowing anything from 5.31
up to (not including) 6.0. `~> 5.31.0` (three segments) locks the first *two* numbers,
only allowing patch releases within 5.31.x.

*This project:* `~> 5.31` in `versions.tf` installed v5.100.0 on `terraform init` — far
more drift than intended. Corrected to `~> 5.31.0`, re-ran `terraform init -upgrade`,
confirmed it now installs exactly v5.31.0.

**Editor vs. terminal — different jobs** — an editor (VS Code) is for writing/viewing
files; a terminal (Git Bash) is for running commands (`terraform init`, `git commit`,
etc.). VS Code's integrated terminal just puts both in one window; it doesn't change
what either one does. The editor choice has zero effect on what "runs in production" —
it never touches AWS itself, it only produces the files that a terminal/pipeline later
acts on.

*This project:* switched from heredoc (`cat > file << 'EOF'`) file creation to editing
directly in VS Code with the HashiCorp Terraform extension (syntax highlighting, inline
validation) installed and Git Bash set as the integrated terminal.

**Who decides architecture: architect/senior engineer vs. implementer** — in many
companies a Solutions/Cloud Architect or senior engineer decides the shape of the
infrastructure (how many subnets, what talks to what) from requirements; DevOps
engineers implement that decision in Terraform/Ansible/etc. Implementers are still
expected to catch mistakes and push back, not blindly execute. At smaller companies,
or in a portfolio project with no one else to decide it, the implementer *is* the one
doing the requirements-to-architecture reasoning (see Session 3).

*This project:* Project 2 is the "spec already decided" case — the architecture was
fixed in Project 1, so Phase 1 work here is translation into Terraform syntax, not new
architecture reasoning. Later projects (3+) hand over more undecided territory.

## Session 6 — 2026-09-12 — Terraform Apply, Verification, and Cross-Project State

**Terraform only reads `.tf` files in the current directory** — it does not recurse into
subfolders. Running `terraform plan` from the repo root (instead of `terraform/`) produces
`Error: No configuration files`, not a warning — an easy mistake when the repo root and the
Terraform working directory are different places.

**Tag-based AWS CLI filters aren't project-scoped** — `--filters "Name=tag:Name,Values=X"`
matches by tag value across the *entire account/region*, not just the project you're thinking
about. If two projects reuse the same `Name` tag convention (as Project 1 and Project 2 both do,
by design, to reproduce the same architecture), an un-scoped query can silently return the wrong
project's resource with a valid-looking response — no error to catch it.

*This project:* querying `vprofile-app-sg` by tag alone returned Project 1's SG
(`sg-0eef3641caa12a1ba`, VPC `vpc-0e686e7841a60b687`) instead of Project 2's
(`sg-0936af3af55dc2f2b`, VPC `vpc-0b7f81bc3fae90299`). Fixed by adding a second filter,
`Name=vpc-id,Values=<vpc>`, to every subsequent lookup.

**Verification sampling, not exhaustive checking** — after `terraform apply`, you don't need to
individually verify all N resources against live AWS state by hand. Spot-checking a
representative few (one from each resource category — here: the VPC, a subnet, and a security
group) is enough to confirm Terraform's plan matched reality, since a systematic bug would show
up in any of them.

**Interface VPC Endpoints vs. Gateway VPC Endpoints** — Interface endpoints (e.g. SSM, SSM
Messages, EC2 Messages) bill hourly per-AZ regardless of usage. Gateway endpoints (S3, DynamoDB)
are free. Same "VPC Endpoint" resource type in the console, very different cost profile — worth
checking which kind before treating "there's a VPC endpoint here" as a cost concern.

*This project:* Project 1's leftover S3 Gateway endpoint (`vpce-0540d3b05281c8189`) costs
nothing; its three Interface endpoints (SSM/SSM Messages/EC2 Messages) had already been deleted
before this session, which is why the earlier cost audit found no billable leftovers at all in
Project 1's VPC.

**"Closed" project ≠ "torn down" project** — Project 1's `PROGRESS.md`/master-prompt status says
CLOSED, but its VPC, subnets, route table, IGW, and several security groups still exist in AWS.
None of it costs money (no instances, no NAT, no EIPs, no Interface endpoints), so "closed" here
meant "development finished and documented," not "infrastructure destroyed." Worth keeping these
as separate concepts going forward — a project can be a complete portfolio deliverable while its
infrastructure is either torn down or deliberately left standing as evidence.

## Session 7 — 2026-09-12 — Missing RabbitMQ Security Group

**Root cause of a missing SG, traced to a stale source-of-truth doc, not a Terraform mistake**
— Project 2's Phase 1 security groups were built directly from the master prompt's "Existing
AWS Project State" list, which only ever named 5 of Project 1's SGs (alb, app, db, mc, ssm_ep).
RabbitMQ's SG was never in that list, so Project 2 never reproduced it — even though the
architecture always called for four backend services (MariaDB, Memcached, RabbitMQ, Tomcat).

*This project:* confirmed via `describe-security-groups` scoped to Project 2's VPC that only
6 SGs existed (5 named + `default`) — no `rmq-sg`. Cross-checked Project 1's actual VPC and
found 11 SGs total, including `vprofile-rmq-sg` (`sg-0ba3baa7a8a231777`), closing out the
Known Issue flagged in Session 6.

**A missing resource can hide behind a passing verification** — Phase 1 was marked COMPLETE
and its `terraform apply` output ("17 to add, 0 to change, 0 to destroy") matched the plan
exactly, so the apply itself gave no signal anything was wrong. The gap only surfaced because
the *architecture* (4 backend services) was checked against the *security groups actually
created* (only 3 backend SGs: db, mc — app is not backend), not because Terraform reported
an error.

**Fix applied:** added `aws_security_group.rmq` (ingress 5672 from `app`, same one-rule
pattern as `db`/`mc`), plus two new ingress rules inside the existing `ssm_ep` resource —
one for `rmq`, and one for `mc`, which was also found missing from `ssm_ep` during this same
review despite `mc`'s own SG existing correctly since Phase 1.

*This project:* `terraform plan` showed `1 to add, 1 to change, 0 to destroy` exactly as
predicted; `apply` succeeded; live AWS confirmed `vprofile-rmq-sg` (`sg-0b8768c70645d442c`)
with the correct 5672-from-app-sg rule.

## Session 8 — 2026-09-12 — EC2 Provisioning, AMI Drift, and AWS Free Tier Changes

**AMI data sources avoid hardcoding a fragile, expiring ID** — `data "aws_ami" { most_recent = true }` looks up the newest matching AMI at plan/apply time instead of a fixed ID that could later be deregistered by AWS.

*This project:* `data.aws_ami.amazon_linux_2023` filters on `al2023-ami-*-x86_64`, `owners = ["amazon"]`.

**AMI drift can silently propose destroying a running instance** — because the data source re-resolves on every `plan`, an unrelated future `plan` (weeks later, for something else entirely) can find AWS has published a newer patch AMI and propose `-/+ replace` on an instance that hasn't actually changed — since AWS instances force replacement on AMI changes, not an in-place update.

**`lifecycle { ignore_changes = [ami] }`** — "let it float, then pin implicitly"** — the AMI data source still resolves freely on every plan (the "float"), but the *moment* `terraform apply` first creates the instance, that specific resolved AMI ID becomes a permanent fact about the running instance and gets recorded in state (the "pin") — automatically, without ever typing a literal AMI ID into the file. `ignore_changes = [ami]` tells Terraform not to propose fixing a future mismatch between the (now newer) data source result and the (frozen) state value.

*This project:* applied to all four Phase 2 instances (`app`, `db`, `mc`, `rmq`) — each resolved Amazon Linux 2023 independently at apply time, each permanently pinned to whatever ID it got.

**AWS Free Tier structurally changed on July 15, 2025** — accounts created before that date keep the legacy model (12 months of free EC2/RDS/etc. hours + Always Free services, no account expiration). Accounts created on/after that date get a $200 credit balance instead (split $100 signup + $100 onboarding), with the account itself auto-closing after 6 months or when credits run out, whichever comes first — followed by a 90-day grace period.

*This project:* confirmed via the Billing console that this account is on the credit-based model — $147.53 remaining of $200 as of this session. Changes the cost framing going forward: `t3.micro` isn't "free hours," it's cheap dollars drawn from a balance with a hard 6-month clock, not just a usage cap.

**Cost Anomaly Detection → root cause drill-down** — AWS's Billing dashboard flags spending that deviates from the account's historical pattern and can attribute it to a specific usage type, not just a service name — useful for distinguishing "VPC costs money" (misleading; VPCs themselves are free) from what's actually inside it generating the charge.

*This project:* a flagged $5.13 "Amazon Virtual Private Cloud" anomaly (Sept 2–8) resolved via root-cause drill-down to `USE1-VpcEndpoint-Hours` — an Interface VPC Endpoint, confirmed (via `describe-vpc-endpoints` showing only the one free Gateway endpoint currently exists) to be a historical, already-deleted cost from Project 1's SSM endpoints, not a live leak.

## Session 9 — 2026-09-19 — SSM Connectivity Verification & AMI Variant Root Cause

**AWS Systems Manager (SSM) Session Manager** — lets you open a shell on a private
EC2 instance through AWS's own network, without SSH, a public IP, or an open port 22.
Requires three things: the SSM agent running on the instance, an IAM role with
`AmazonSSMManagedInstanceCore`, and (for fully private instances) Interface VPC
Endpoints for `ssm`, `ssmmessages`, and `ec2messages` so the agent can reach the SSM
service without internet access.

*This project:* all three pieces were individually correct, yet `aws ssm
start-session` failed with `TargetNotConnected` for over an hour of troubleshooting.

**Amazon Linux 2023 has a "minimal" AMI variant that silently excludes the SSM agent**
— alongside the standard variant. Both match the loose naming pattern
`al2023-ami-*-x86_64`; only the name segment (`al2023-ami-minimal-...` vs.
`al2023-ami-2023...`) tells them apart. A `data "aws_ami"` filter with a wildcard
broad enough to match both, combined with `most_recent = true`, can silently resolve
to the minimal variant with no error or warning.

*This project:* `filter { values = ["al2023-ami-*-x86_64"] }` matched
`al2023-ami-minimal-2023.12.20260918.0-...` since it was the most recently published
image at apply time. Every AWS-side networking layer (IAM, security groups, NACLs,
VPC endpoints, route tables, DNS) was independently verified correct — the actual
problem was that the SSM agent was never installed on the instance in the first
place. Fixed by tightening the filter to `al2023-ami-2023.*-x86_64`, which the
minimal variant's name doesn't match.

**`lifecycle.ignore_changes = [ami]` blocks more than you might expect** — once
set, Terraform won't propose replacing the instance even when the underlying
`data.aws_ami` source resolves to a genuinely different AMI (e.g., after fixing a
bad filter). `terraform plan`/`apply` will report "No changes," which can look like
the fix didn't take effect even though it did — the data source itself was verified
correct via a separate `aws ec2 describe-images` call, independent of the ignored
instance attribute.

**`terraform apply -replace="<resource.address>"`** — forces Terraform to destroy
and recreate one or more specific resources, overriding `ignore_changes` for that
one operation, without touching any other resource. Used here to intentionally
recreate all 4 instances (twice — once to test whether recreation alone would fix
registration, once again after the AMI filter fix) while leaving VPC, subnets,
security groups, and endpoints untouched.

**Troubleshooting order matters, and a fix can be valid without being the root
cause** — the private subnet's missing explicit route table association was a real
gap (found and fixed this session) but turned out *not* to be why SSM was failing:
every VPC route table automatically includes an unremovable "local" route for the
VPC's own CIDR block, which already covered traffic to the endpoint ENIs (their
private IPs fall inside that CIDR) regardless of explicit table content. The fix
was kept anyway as correct, explicit infrastructure — but it's a useful lesson that
"AWS accepted this change and it's a sensible improvement" doesn't automatically
mean "this was the bug."

**EC2 Serial Console** — an out-of-band console access method independent of all
VPC networking (security groups, NACLs, routing), authenticated via a short-lived
SSH key pushed through `aws ec2-instance-connect send-serial-console-ssh-public-key`.
Useful for diagnosing an instance when the normal network path (SSH or SSM) is
completely broken — but still requires an OS-level login (password), which a
default Amazon Linux instance doesn't have set up, so it's a dead end for instances
that only ever expected key-based or SSM access.

*This project:* used to attempt direct diagnosis of the DB instance mid-investigation;
confirmed a login prompt was reachable (ruling out total instance failure) but
couldn't proceed past the password prompt — this was inconclusive rather than
diagnostic, and the real answer came from checking the AMI name directly instead.

**Ansible fundamentals — inventory, roles, and playbooks** — Ansible uses an
inventory to identify and group managed hosts, roles to organize reusable
configuration tasks, and playbooks to define which roles/tasks are applied to which
hosts. Terraform and Ansible have different ownership boundaries: Terraform
provisions the infrastructure and its connectivity prerequisites; Ansible performs
post-boot operating-system and application configuration.

*This project:* the four Terraform-created EC2 instances are the hosts Ansible will
eventually configure with roles for Tomcat, MariaDB, Memcached, and RabbitMQ. The
Ansible connectivity method must therefore be decided before Phase 4 role execution.

**Ansible connection plugins** — Ansible's connection layer determines how it reaches
a managed host. SSH is the familiar default connection method, but Ansible can use
other connection plugins when the infrastructure requires a different transport.
For private EC2 instances, SSM can provide the connection path without exposing SSH
to the public internet.

*This project:* the successful SSM path means Ansible does not need public IPs,
internet-facing SSH, or an inbound port 22 rule just to configure the four instances.
The Phase 4 connection decision is therefore SSM, using the appropriate AWS/Ansible
SSM connection plugin (`community.aws` / `aws_ssm`).

**`cat >` vs. `cat >>`** — shell redirection with `>` writes to a file and overwrites
its existing contents; `>>` appends to the existing file instead.

*This project:* `cat > file` was used when creating/replacing file contents, while
`cat >> file` is the pattern to use when adding new content to the end of an existing
notes/documentation file without overwriting what is already there.

**AWS CLI Billing Credits limitation** — the AWS CLI can query billing/cost data such
as Cost Explorer results, but the actual remaining Credits balance is not exposed
through the same CLI cost query; the Credits balance is viewed through the AWS Billing
console.

*This project:* the account's remaining credit balance had to be checked in the
Billing console rather than retrieved as a direct AWS CLI Credits-balance value.

## Session 10 — 2026-09-22 — Ansible Local Install (WSL2 + pipx)

**Ansible requires a real Linux environment, not Git Bash** — Git Bash emulates a
Unix-like shell on Windows but isn't a real Linux kernel, which Ansible's control
node needs. Confirmed via `ansible --version` → `command not found`.

**WSL2 vs. Docker vs. EC2 as a "get me Linux" fix** — WSL2 was chosen over running
Ansible in a Docker container (adds friction for a tool used interactively and
constantly) or from an EC2 instance (real, billable, always-on infrastructure just
to get a shell, plus file-sync overhead). WSL2 runs a genuine Linux kernel alongside
Windows at the OS level, for free, with direct access to the same files (no upload
needed) via `/mnt/g/...`.

*This project:* WSL2 was already present (used internally by Docker Desktop, distro
`docker-desktop`), but that distro isn't meant for general use — a real distro
(Ubuntu) still had to be installed via `wsl --install -d Ubuntu`.

**pipx over `apt` or system-wide `pip` for installing Ansible** — `apt install
ansible` ships an older, stability-frozen version that may not meet the
`amazon.aws`/`community.aws` collection's minimum-version requirements. System-wide
`pip install ansible` gets the latest version but risks polluting Ubuntu's system
Python with dependencies that later conflict with other tools ("dependency hell").
`pipx` gives the latest version in its own isolated environment while still exposing
the `ansible` command globally — this is Ansible's own current recommended install
method for exactly this reason.

*This project:* `pipx install --include-deps ansible` installed ansible 14.4.0
(ansible-core 2.21.4) under `/home/domin/.local/share/pipx/venvs/ansible/`, exposing
`ansible`, `ansible-playbook`, `ansible-galaxy`, etc. globally via `pipx ensurepath`.

## Session 11 — 2026-09-22 — Ansible SSM Connectivity End-to-End

**`wsl -u root` without `-d` hits the *default* distro, not necessarily the one you're
working in** — WSL's default distro can differ from the one you actually intend.

*This project:* `wsl -u root` dropped into `docker-desktop` (the default), giving
`passwd: unknown user domin`. Fixed with `wsl -u root -d Ubuntu`.

**NTFS-mounted paths (`/mnt/g/...`) break Linux-style installs** — NTFS doesn't support
Unix permissions/timestamps, and Windows paths with spaces can break scripts that assume
POSIX path parsing.

*This project:* `unzip`-ing the AWS CLI installer under `/mnt/g/Tutorial Folder/...`
produced a wall of `fchmod ... Operation not permitted` warnings, and `sudo ./aws/install`
failed outright with `/mnt/g/Tutorial: not found` (broken by the space in "Tutorial
Folder"). Fixed by installing from `~` (native Linux filesystem) instead — same fix later
reused for `session-manager-plugin`.

**Each OS environment needs its own AWS CLI install *and* credentials** — Windows and
WSL2/Ubuntu are separate environments; nothing installed or configured on one side is
visible on the other.

*This project:* `aws` worked fine in Git Bash all project, but Ubuntu had no `aws` binary
and an empty credentials file. Installed AWS CLI v2.36.50 and ran `aws configure` inside
Ubuntu using the same `gitops-terraform` IAM user, verified via `aws sts
get-caller-identity`.

**`pipx inject`** — adds a Python package into an *already pipx-installed* app's isolated
environment, for a dependency the app needs but wasn't bundled with.

*This project:* Ansible's AWS modules need `boto3`/`botocore` to call AWS's API, but
pipx's isolated Ansible venv only had `botocore`. Fixed with `pipx inject ansible boto3
botocore`.

**`session-manager-plugin` is a separate binary, per OS, not part of the AWS CLI itself**
— SSM session support depends on this external helper, and it doesn't cross OS
boundaries.

*This project:* the Windows copy (visible on PATH via `/mnt/c/...`) is a `.exe`, unusable
inside Linux. Downloaded and `dpkg -i`'d the Ubuntu-native `.deb` build separately.

**Ansible inventory targeting for `aws_ssm`** — `ansible_host` holds the EC2 **Instance
ID**, not an IP/hostname, since that's what the SSM API uses to identify a target.

*This project:* `inventory/hosts.yml` groups all 4 instances by tier (`app`, `db`,
`cache`, `mq`), each with `ansible_host: i-0...`, plus shared `vars` for
`ansible_connection: community.aws.aws_ssm`, region, and the relay bucket name.

**`aws_ssm` needs an S3 bucket for file transfer, unlike a live SSH/SSM shell session** —
the plugin uploads files to S3, then has the instance download them from there; a
transient relay, not permanent storage.

*This project:* created `vprofile-ansible-ssm-<timestamp>` purely for this purpose,
referenced via `ansible_aws_ssm_bucket_name` in the inventory.

**A working raw SSM shell session doesn't guarantee Ansible will work** — Session
Manager's interactive shell and Ansible's `aws_ssm` file-transfer path exercise different
capabilities of the same service.

*This project:* Session 9's successful `aws ssm start-session` only proved basic
connectivity — it never needed S3. The first real Ansible task (`ping`) immediately
exposed a gap that a raw shell session couldn't have caught.

**Real architecture gap: no network path from private instances to S3** — this project's
private subnet had neither a NAT Gateway nor an S3 Gateway Endpoint, so any attempt to
reach S3 (as opposed to the SSM API itself) had nowhere to route.

*This project:* diagnosed via `ansible -vvvv`, which showed the instance's `curl` to a
presigned S3 URL hanging indefinitely; confirmed via `describe-vpc-endpoints` showing
only the 3 SSM Interface endpoints existed. Fixed by adding `aws_vpc_endpoint.s3` (Gateway
type — free, unlike Interface endpoints — associated with the private route table) in
Terraform. `terraform plan` showed exactly 1 to add; `apply` succeeded; `ansible -m ping`
then succeeded on all 4 hosts immediately after.

**Instance state can drift between sessions** — all 4 EC2 instances were found `stopped`
at the start of this session despite being verified `running`/`Online` in Session 9.

*This project:* confirmed via `describe-instances` before assuming Ansible/SSM was broken
again, rather than guessing; restarted all 4, waited for `describe-instance-information`
to show `PingStatus: Online` before retrying Ansible.

## Session 12 — 2026-09-22 — Ansible Roles: MariaDB, Memcached, RabbitMQ (design)

**Ansible role directory structure is a fixed convention, not a free choice** — `tasks/`, `handlers/`, `templates/`, `files/`, `vars/`, `defaults/` are recognized by any Ansible user; using it (even partially, using only the folders a role actually needs) signals familiarity with the tool's standard layout.

*This project:* `mariadb` and `memcached` roles both use only `tasks/` + `handlers/` (+`templates/` for mariadb) — no `files/`/`vars/`/`defaults/` needed at this portfolio scale.

**`state: present` vs `state: latest` (package modules) — idempotency-driven, not just "which is safer"** — `present` means "install only if missing, never touch it again if it exists"; `latest` would re-check for upgrades on every single run, meaning a playbook could change (upgrade) something on run 50 that had nothing to do with why you're running it that day.

*This project:* every `dnf`/`yum_repository` task in `mariadb`/`memcached`/`rabbitmq` uses `present`, deliberately, for reproducible, predictable runs.

**`template` vs `lineinfile` vs `copy` — pick based on how much of the file you control** — `template`: replace/render a whole file you own (used for MariaDB's multi-setting `.cnf` file). `lineinfile`: find-and-fix exactly one line in a file you don't fully own (used for Memcached's `/etc/sysconfig/memcached`, which has several unrelated settings we don't want to touch). `copy`: move a file byte-for-byte with no variable substitution — not used yet this project, but the plain option when `template`'s Jinja2 rendering isn't needed at all.

*This project:* `mariadb-server.cnf.j2` (whole-file replace) vs. Memcached's single `OPTIONS=` line — same underlying goal (accept connections from other instances, not just localhost), two different tools because the amount of file we control differs.

**Handlers (`notify`) exist to make idempotency real, not just "restart when I remember to"** — a normal task placed right after a config-file task would restart the service on literally every playbook run, forever, even the 100th run where nothing changed. `notify` only fires the named handler if the *triggering* task actually reported a change.

*This project:* both `mariadb`'s and `memcached`'s config tasks use `notify: Restart <service>` — restart only happens the run a setting actually changes, never otherwise.

**"Listen on all interfaces" (`bind-address=0.0.0.0` / `-l 0.0.0.0`) is required whenever the client and server are different machines** — by default MariaDB and Memcached only accept connections that originate from the same machine (`localhost`/`127.0.0.1`). Since Tomcat lives on a separate EC2 instance from both, both backend services need this setting changed, or the app's connection attempt is refused before permissions are even checked.

*This project:* the actual network-level security boundary is the security group (`vprofile-db-sg`/`vprofile-mc-sg`, both scoped to `vprofile-app-sg` only) — "listen everywhere" doesn't mean "reachable by everyone," since the SG still gatekeeps who can even attempt a connection.

**MySQL/MariaDB user identity = username + host, not username alone** — `admin@localhost` and `admin@'%'` are two entirely separate accounts to MySQL/MariaDB, even with the same username. `%` is the wildcard meaning "any host."

*This project:* the `admin` user is created with `host: "%"` specifically because Tomcat connects from a different EC2 instance, not `localhost`.

**`community.aws.secretsmanager_secret` lookup — fetches a secret live at playbook-run time, never stores it in a file** — paired with `no_log: true` on the task that calls it, so the retrieved value also never gets printed to terminal/log output. This is the Ansible-native way of avoiding hardcoded credentials, similar in spirit to Terraform variables but mechanically different: Terraform variables are *supplied*; this lookup is *fetched from a live AWS API call* each run.

*This project:* used twice — `mariadb_root_password` (from `vprofile/db/admin-password`) and `rabbitmq_test_password` (from `vprofile/rmq/test-password`), both reused from Project 1's existing secrets.

**MariaDB root-password bootstrap is a real, deferred idempotency question, not yet resolved** — a fresh MariaDB install has no root password, so the very first login (via `login_unix_socket`, a passwordless local connection method) can't use `login_password` yet. Whether this same task behaves correctly (`changed: false`) on the *second* playbook run — once a password already exists — is not yet verified. Decision: don't solve this on paper; run the playbook twice for real once it's complete, and treat the actual second-run output as the answer.

**MariaDB is a fork of MySQL, not a different product wearing MySQL's protocol as a costume** — created by original MySQL developers after Oracle's acquisition, over licensing/control concerns. Stays highly compatible (same SQL syntax, same wire protocol) because it started as an exact copy and diverged from there.

*This project:* this is *why* `community.mysql`'s modules (`mysql_db`, `mysql_user`) work correctly against MariaDB even though the collection is literally named after MySQL — the module talks over the shared MySQL protocol both implement.

**A "complete-looking" role can still be missing something a first draft didn't check for** — the first version of the `mariadb` role only created an *empty* `accounts` database. Cross-checking Project 1's own actual, verified `PROGRESS.md` (not assumption, not a generic course convention) revealed the real Project 1 also imported a schema file (`accountsdb.sql`, from S3) containing real tables (`role`, `user`, `user_role`) — without which the app would still fail to work even with a correctly-named, correctly-permissioned database.

*This project:* fixed by adding two tasks — `amazon.aws.s3_object` (download the schema from `s3://vprofile-artifacts-747336059892/db/accountsdb.sql`) and `community.mysql.mysql_db` with `state: import` (load it) — inserted between database creation and user creation.

**A Terraform decision made earlier in the project can silently invalidate an assumption made later** — Project 2's `rabbitmq` EC2 instance was provisioned using the same dynamic AL2023 AMI lookup as the other 3 instances. That's fine for MariaDB/Memcached/Tomcat, but RabbitMQ specifically has no package in AL2023's default repos at all (the same packaging gap Project 1 hit) — meaning our current instance has *no RabbitMQ installed whatsoever*, unlike Project 1, which used a purpose-built golden AMI to route around this exact gap.

*This project:* deliberate decision (Option B of three considered) to install RabbitMQ properly via Ansible, from the real upstream repos, rather than reusing Project 1's golden AMI (which would make Ansible do nothing for this one service) or introducing a NAT Gateway (already explicitly rejected in Project 1 for cost reasons).

**Amazon Linux 2023 uses the "el9" RabbitMQ/Erlang repository family, not "el8"** — confirmed directly from RabbitMQ's own current official docs (2026-09-22), which explicitly list Amazon Linux 2023 under the same repo group as RHEL 9/CentOS Stream 9/Rocky 9, not RHEL 8.

*This project:* directly relevant to writing a *working* RabbitMQ role here — and also a plausible (unconfirmed) explanation for Project 1's own still-open Known Issue, where `dnf install` kept failing even after the Cloudsmith URLs themselves were fixed to return 200. Worth checking against Project 1's actual repo file content if that project is ever revisited.

**`rpm_key` and `yum_repository` modules exist so GPG-key-import and repo-file-creation are idempotent, not raw shell commands** — a raw `rpm --import` or a hand-written repo file would either always report "changed" or require manually diffing file contents to know if anything's different. The dedicated modules understand the actual state being managed and only act when something's genuinely different.

**`loop` lets one task definition run multiple times over a list of items** — avoids writing near-duplicate tasks that differ only in a couple of values.

*This project:* one `yum_repository` task, looped over two dictionaries (`modern-erlang` and `rabbitmq-el9`), instead of writing the same task twice with copy-pasted values.

**`community.rabbitmq.rabbitmq_user` maps directly, one parameter at a time, onto the exact `rabbitmqctl` commands Project 1 ran manually** — `user`/`password`/`state` ↔ `add_user`; `tags` ↔ `set_user_tags`; `vhost`+`configure_priv`/`write_priv`/`read_priv` ↔ `set_permissions`. Same permission model Project 1 used (full admin rights on default vhost `/`) — a trade-off Project 1 already named as "not least-privilege, acceptable for a portfolio-scale single-app broker," carried forward here rather than re-decided.

**Teaching-preference note for continuity (not a technical lesson, but worth recording):** this session, explanations shifted to a more literal, non-metaphor, line-by-line style at the student's explicit request — including breaking down individual YAML lines one at a time, and always stating "why this choice, not the alternative, and is it best practice / interview-relevant" for meaningful decisions. This preference should carry forward as the default teaching style for the rest of this project, not just this session.

## Session 13 — 2026-09-24 — Ansible Roles Finished, First Real Deployment Debugging

**A role with nothing to `notify` doesn't need a `handlers/` folder** — `rabbitmq`'s tasks never modify a config file, so nothing ever triggers a restart-on-change. Adding an unused handler file would just be dead code.

*This project:* `rabbitmq` role has only `tasks/`, unlike `mariadb`/`memcached`/`tomcat`, all of which do edit a file the running service depends on.

**Amazon Linux 2023 doesn't ship a package literally named after the software** — it ships versioned packages instead (`tomcat9`, `tomcat10`, `tomcat11`), so `dnf install tomcat` fails with "No package tomcat available" even though Tomcat genuinely is packaged for AL2023.

*This project:* confirmed via `dnf list --available 'tomcat*'` directly on the instance rather than guessed from generic docs.

**Tomcat 10+ made a breaking namespace change — `javax.servlet` → `jakarta.servlet`** — older WAR files built against the pre-10 API don't error loudly on Tomcat 10/11; the server starts fine, but the app is never recognized, producing endless 404s with no obvious cause.

*This project:* `vprofile-v2.war` is a legacy-style app, so **Tomcat 9** is the only one of the three available AL2023 packages with a real chance of working — a real requirements-to-architecture decision, not a style pick, reasoned through directly rather than told upfront.

**`CATALINA_HOME` vs `CATALINA_BASE`, and why guessing an install path is risky** — RPM-packaged Tomcat can create more than one folder that *looks* like the webapps directory (`/usr/share/tomcat9/webapps` and `/var/lib/tomcat9/webapps` both existed). Only one is the one the running service actually uses, determined by `CATALINA_BASE` if set, falling back to `CATALINA_HOME` if not.

*This project:* confirmed the real path by reading `/etc/tomcat9/tomcat9.conf` directly (`CATALINA_HOME="/usr/share/tomcat9"`, no `CATALINA_BASE` override) rather than assuming from generic Tomcat tutorials, which often describe a different (Debian-style) packaging layout that doesn't match AL2023's.

**`community.mysql` collection has been renamed to `ansible.mysql`** — the old module names (`community.mysql.mysql_user`, `mysql_db`) still work today only as redirects, and will be removed entirely in a future collection version.

*This project:* confirmed both collections were already installed (`ansible-galaxy collection list`) before switching all 3 FQCNs in the `mariadb` role.

**Reusing one password across a superuser account and a limited-purpose app account defeats least privilege, even if it "works"** — the `admin` MariaDB user was created using the same secret as MariaDB's own root password. A leak of the app's one credential (from a log, a config file, a compromised instance) would hand over full root access, not just access to the one database the app actually needs.

*This project:* fixed by creating a dedicated `vprofile/db/app-password` secret via AWS Secrets Manager and updating the role to fetch/use it only for the `admin` user — root's password stays separate and untouched.

**AWS CLI's `create-secret` has no `--generate-secret-string` flag** — despite it sounding plausible and matching a real console UI feature, the actual API/CLI splits this into two separate steps: `get-random-password` (generates a value) and `create-secret --secret-string` (stores it). Confirmed via the official CLI docs after the invented flag failed identically across multiple retries (different quoting, different line formatting) — a reminder that a persistent identical error across several fix attempts is itself a signal the assumed command/flag might not exist at all, not that the syntax needs more tweaking.

*This project:* generated the password into a shell variable (`SECRET_PW=$(...)`) so the actual value was never displayed or typed manually, then passed it to `create-secret`, then `unset` the variable afterward.

**Ansible *lookups* run on the control node; Ansible *modules* run on the target host — different Python environments entirely** — a lookup like `secretsmanager_secret` executes using the control node's own Python (WSL's pipx-isolated Ansible install, already has boto3/botocore since Session 11). A module like `amazon.aws.s3_object` copies its code to the **remote EC2 instance** and runs there, using *that machine's* Python — which had no boto3/botocore installed at all, and not even `pip` itself.

*This project:* this distinction wasn't documented anywhere Session 11 covered, and only surfaced because `secretsmanager_secret` (a lookup) had already worked fine in both `mariadb` and `rabbitmq`, making the `s3_object` (a module) failure genuinely confusing at first. Fixed by adding a `python3-boto3`/`python3-botocore` install task (via `dnf`, not `pip`, since `pip` wasn't even present) to both `tomcat` and `mariadb` — each EC2 instance needs this independently; fixing one instance does nothing for another.

**`HeadBucket`'s permission gate is `s3:ListBucket`, not something more obviously named** — a module checking "does this bucket exist and can I see it" before reading a file calls the S3 `HeadBucket` API action underneath, which AWS's IAM system gates behind the `s3:ListBucket` permission — not `s3:GetObject` (that only covers reading a file's actual contents) and not some more literally-named "HeadBucket" permission.

**S3 IAM permissions use two different ARN shapes for two different scopes** — `s3:ListBucket` (a bucket-existence/listing action) applies to the bucket itself: `arn:aws:s3:::bucket-name` (no `/*`). `s3:GetObject` (reading a file's contents) applies to objects inside the bucket: `arn:aws:s3:::bucket-name/*` (with `/*`). Using the wrong shape for either action, or granting only one of the two actions, produces the same generic `403 Forbidden`.

*This project:* the EC2 role had neither action at all (confirmed via `aws iam list-attached-role-policies`/`list-role-policies` before writing any fix) — new `s3_artifacts_access` inline policy grants both, scoped only to `vprofile-artifacts-747336059892`, following the same least-privilege shape as the existing `secrets_access` policy rather than a broad `s3:*`.

**Each OS environment needs its own Git identity and credentials too, not just its own tool installs** — same underlying lesson as Session 11's separate-AWS-CLI-per-environment finding, now hit again with Git: WSL2/Ubuntu's Git had never been configured with a username/email or GitHub auth, since Git Bash (a completely separate environment) already had both and every prior commit/push had gone through there.

*This project:* rather than configure a second Git identity inside WSL, adopted a deliberate split going forward — all `git` commands run in Git Bash; WSL2 is reserved for Ansible only. Also: pasting multiple commands as one block while an earlier command in that block is still hanging on an interactive prompt causes the later lines to be silently fed into that prompt as answers — explains the garbled `Username for 'https://github.com': cd ansible` output seen when this happened.

## Session 14 — 2026-09-27 — Four Services Working, One Open Gap

**Two different Python plugin *kinds* can share an identical dotted name across collections, and only one of them is what you asked for** — `community.aws.secretsmanager_secret` genuinely exists, but as a *module* (create/update/delete a secret), not a *lookup plugin* (read an existing secret's value). Calling it with `lookup(...)` fails with "plugin not found," which sounds like a missing collection but actually means "wrong collection for this specific plugin type." The real lookup plugin is `amazon.aws.secretsmanager_secret`.

*This project:* fixed in 3 places across `mariadb` (2) and `rabbitmq` (1) — same one-line namespace swap each time.

**`grep` exits 1 when it finds zero matches — and Ansible's `shell` module treats any non-zero exit as a task failure by default.** A "command failed" error from an ad-hoc `shell` task wrapping `grep` can just mean "grep found nothing," not "the command itself is broken."

*This project:* `dnf list --available | grep -i pymysql` came back as a task failure — the real information was that grep found zero matches, meaning no PyMySQL package exists under that name at all, not that the search command was wrong.

**When a Python dependency isn't available via the OS package manager, and the target has no internet route, host the wheel yourself instead of trying to reach PyPI.** A pure-Python package (no C extensions) produces a `py3-none-any` wheel — meaning one file works across any Python 3.x, any OS, any CPU architecture. Download it once from a machine with real internet access, upload it to a bucket the target can already reach (here, the same artifacts bucket already used for the WAR and schema files), then have Ansible fetch-and-install from that local copy instead of the internet.

*This project:* `pymysql-1.2.3-py3-none-any.whl`, downloaded from WSL, uploaded to a new `deps/` prefix in `vprofile-artifacts-747336059892`, fetched via the same `amazon.aws.s3_object` module already used for the WAR/schema, then `pip install`'d from the local file path — `pip` never contacts an index at all when given an exact file, so no internet route is needed for the install itself.

**A temporary NAT Gateway is a legitimate, narrowly-scoped tool — not a workaround — for a one-time install with a real multi-package dependency chain that a single hosted file can't substitute for.** The distinguishing question isn't "is this the field's default" (a NAT Gateway usually is the default for general internet access) — it's whether the *specific* need is a single small file (S3-wheel fits) or a live dependency-resolution process against an upstream repo (`dnf` resolving Erlang + RabbitMQ + whatever they pull in — S3-wheel doesn't fit; you'd have to hand-compute the whole closure).

*This project:* created `aws_eip.nat` + `aws_nat_gateway.main` + `aws_route.private_internet_temp` in `main.tf`, applied, ran the playbook once against `rabbitmq01` only, confirmed success, then destroyed all 3 immediately via `terraform destroy -target=...` — never left standing.

**`-target` scoped destroy leaves dead code behind unless you remove it — and that dead code is a real accidental-recreation risk, not just clutter.** Destroying resources with `-target` doesn't touch the `.tf` file that declares them. A later `terraform apply` for something completely unrelated would see the code still describing those 3 resources, find they don't exist in state, and recreate them — silently reintroducing the exact temporary infrastructure you just tore down, for an unrelated change.

*This project:* deleted the 29 lines from `main.tf` in the same session as the destroy, then ran a plain `terraform plan` and confirmed `No changes` — proof the code and live state agree, closing the loop completely rather than leaving a landmine for a future session.

**A task reporting `ok` with zero `changed` on what looks like a "first ever" run isn't automatically suspicious — check *when* the underlying state was actually created, not just the run count in your own head.** `tomcat01`'s WAR deployment showed `changed=0` on every run this session, which looked like a possible silent failure. The real explanation: the WAR was successfully deployed several days earlier (the session the S3 IAM policy was first applied), and every playbook run since then correctly found it already present and reported `ok` without `changed` — that's idempotency working as designed, confirmed by checking the actual file timestamp on the instance rather than assuming from the recap alone.

**Command-line evidence and "is the app actually working" are two different questions, and closing the gap between them is where a real bug was found.** `ls` showing the WAR file present, and `systemctl is-active` showing the service running, both looked like success — but neither actually tests whether the deployed application responds to a real request. A direct `curl` to the app's expected URL returned `404`, surfacing a genuine unresolved problem that file-presence and service-status checks alone would have missed entirely. Diagnosis was interrupted at session end — first step next session is finding Tomcat's real log location, since the assumed path from Session 13 (`/var/log/tomcat9/catalina.out`) doesn't exist on this particular install; AL2023's RPM-packaged Tomcat likely logs to `journald` instead.

**Recurring friction, not a new lesson exactly, but worth naming since it happened three times this session:** mixing up which shell you're in (Git Bash vs. WSL) when the prompt itself already shows which one — `terraform: command not found` and `ansible: command not found` are both instant, unambiguous signals of being in the wrong shell, worth checking the prompt for before assuming a tool is broken or missing.

## Session 15 — 2026-09-27 — Tomcat Jakarta/Servlet Mismatch, Private Route 53 DNS

**A container "failing to start a listener" can mean the listener's *class* never loaded, not that its logic threw an error** — `NoClassDefFoundError` fires when the JVM can't even find a class byte-for-byte, distinct from an exception thrown by code that did run. Tomcat 9's `SEVERE ... listeners failed to start` pointed here, not to a DB/network problem as first assumed.

*This project:* the real trace (`jakarta.servlet.ServletContextListener` not found) was in `localhost.<date>.log`, not `catalina.log` — Tomcat splits container-level events (`catalina.log`) from application-level startup errors (`localhost.log`). Grepping the wrong file, and even grepping the right file in the wrong direction (`-A` instead of `-B` around the summary line), delayed finding it.

**`javax.*` vs. `jakarta.*` is a real, hard compatibility boundary, not a cosmetic rename** — Tomcat 9 and earlier only ever provide `javax.servlet.*` classes to a deployed app; Tomcat 10+ only provide `jakarta.servlet.*`. A WAR built against one will never satisfy the other, regardless of the app's apparent "vintage."

*This project:* assumed in Session 13 that `vprofile.war` needed `javax` because it's a legacy-style reference app — never actually checked what was bundled inside it. It shipped `spring-web-6.0.11.jar`, a Jakarta-namespace artifact, contradicting that assumption. **Lesson: verify a WAR's actual bundled dependencies before choosing a container version, don't infer from the app's reputation.**

**Spring Framework's major version caps which Jakarta EE generation it supports — not just "does it use jakarta or javax."** Spring 6.0.x supports Jakarta EE 9–10 (Servlet 5.0–6.0) only, confirmed via Spring's own release documentation. Tomcat 10.1.x implements Servlet 6.0 (fits); Tomcat 11 implements Servlet 6.1/Jakarta EE 11 (does not fit Spring 6.0.x's stated range).

*This project:* this ruled out Tomcat 11 even though it also uses the `jakarta` namespace — "same namespace family" isn't sufficient; the specific spec version has to be checked too. Verified via official Tomcat and Spring documentation before switching, not assumed.

**A package removal (`dnf remove`) only removes what the package manager itself put there — files an external tool (Ansible, S3 download) placed outside package management survive.**

*This project:* `dnf remove tomcat9` deleted the package's own files, but `/var/lib/tomcat9/webapps/vprofile.war` (placed there by Ansible's `s3_object` task, not by the RPM) was untouched — meaning the already-downloaded WAR could just be copied to the new `tomcat10` webapps path instead of re-fetched from S3.

**Command chaining with `;` can hide a real failure inside an apparent one — `systemctl status` returning non-zero on a freshly-installed, not-yet-started service is not evidence anything actually broke**, same class of false alarm as `grep` exiting 1 on zero matches (Session 14). Ansible's `shell` module reports the whole chained command as `FAILED` based on the *last* command's exit code, even when every real step before it succeeded.

*This project:* a chained `dnf remove; dnf install; systemctl status` reported `FAILED`, but reading the actual output showed both package operations completed cleanly — the `status` check alone tripped the non-zero-exit label because the service was simply `inactive (dead)` before ever being started.

**"The Ansible role completed successfully" and "the app can actually reach that backend service" are two different claims — verified separately, not implied by each other.** A role can finish (install package, create user, start service) entirely independently of whether the *deployed application* can ever successfully talk to it.

*This project:* `mariadb01`/`memcached01`/`rabbitmq01` all completed clean Ansible runs in Session 14, and this got recorded as those services "working" — but the actual app (`vprofile.war`) never once successfully connected to any of them, because all three are addressed by short hostnames (`db01`, `mc01`, `rmq01`) that had no DNS resolution anywhere in the project until this session. The 404 bug happening to block Tomcat *before* it reached that code path is the only reason this gap stayed hidden through Session 14.

**Course-fidelity check applies to me too, not just the student** — the master prompt (v3.3) already required checking the course curriculum before presenting a design decision as a generic best-practice-vs-simplicity tradeoff, and this session's first pass at the DNS-resolution fix skipped that check, defaulting straight to a generic "simpler" answer (`/etc/hosts`) that turned out to contradict the course's own dedicated "DNS Route 53" lecture.

*This project:* corrected only because the student happened to remember the lecture existed — a reminder that the rule needs to actually be applied at decision time, not just exist in the prompt.

**A private Route 53 hosted zone is VPC-scoped internal DNS, not the same feature as a public hosted zone for a real domain name** — created via a `vpc` block inside `aws_route53_zone` instead of leaving it public; records inside it (e.g. `db01.vprofile.internal`) never resolve outside that VPC, by design.

*This project:* `vprofile.internal` chosen as the zone name specifically because `.internal` is conventionally reserved for exactly this non-public use, avoiding any collision risk with a real domain.


## Session 16 — 2026-09-27 — DHCP Option Sets and the AL2023 Network Stack

**A Route 53 private zone answering a query is different from an instance knowing to ask that query at all** — a Route 53 zone with correct records doesn't help if nothing ever tells the OS to try the suffix that zone covers. Every VPC hands out DNS behavior via a **DHCP option set**: alongside an IP address, DHCP also delivers which DNS resolver to use and which **search domain** to append when a bare hostname (like `db01`) doesn't resolve on its own.

*This project:* the VPC's default DHCP option set had `domain_name = us-east-1.compute.internal` (AWS's default), not `vprofile.internal`. So `db01` was never even being tried as `db01.vprofile.internal` — the Route 53 zone was correct and irrelevant at the same time.

**Fix: `aws_vpc_dhcp_options` + `aws_vpc_dhcp_options_association`** — create a new option set with the right `domain_name`, then attach it to the VPC. This affects every instance in the VPC, not just one — worth knowing on a shared VPC, though fine here since all 4 instances are ours.

**Amazon Linux 2023 doesn't use `dhclient` or NetworkManager** — it uses `systemd-networkd` (handles the actual DHCP client role) paired with `systemd-resolved` (manages `/etc/resolv.conf` and the search domain). The command to force a lease renewal is `networkctl renew <interface>`, not `dhclient -r && dhclient`. Interface names are `ens5`-style, found via `networkctl list`.

*This project:* three consecutive wrong guesses (`dhclient` missing, then `nmcli` missing) before checking `systemctl list-units | grep network` directly and finding the real running services — a reminder to check what's actually running rather than guessing a third likely tool name.

**Ping (ICMP) failing does not mean the network path is broken — it may just mean the security group is doing its job.** Security groups are protocol-and-port specific. `vprofile-db-sg`/`mc-sg`/`rmq-sg` were built to allow exactly the ports each service needs (3306, 11211, 5672) from `vprofile-app-sg` — never ICMP, since nothing in the architecture needs ping. A failing ping after DNS resolves correctly should be tested against the *real* port before being treated as a bug.

*This project:* `ping db01` resolved correctly (`172.20.3.56`) but showed 100% packet loss; a direct TCP check via `(echo > /dev/tcp/db01/3306)` confirmed the real port was open. Same result confirmed for Memcached (11211) and RabbitMQ (5672).

**A WAR's own bundled `logback.xml` can make the application itself unverifiable through server logs, independent of anything Ansible or Terraform did.** This project's `vprofile.war` ships a `logback.xml` that sets the ROOT logger and `org.springframework`/`org.hibernate`/the app's own package all to `OFF`. This isn't a bug we introduced — it's baked into the artifact — but it means `journalctl` on `tomcat10` will not show Spring's AMQP/RabbitMQ connection activity, success or failure, regardless of what's actually happening.

*This project:* after the DNS fix, we could not find `UnknownHostException` in the logs (good) but also could not find positive confirmation the RabbitMQ listener connected (logging is off). We therefore relied on independent infrastructure-level evidence — DNS resolution confirmed, TCP reachability confirmed on all 3 backend ports, app still returns HTTP 200 — rather than waiting on log output that structurally cannot appear without a temporary logging override (not done this session, listed as optional future work).

**Ansible ad-hoc commands vs. playbooks — a distinction that should have been introduced before first use, not after several were already run.** An ad-hoc command (`ansible <target> -i <inventory> -m <module> -a "<args>"`) is a one-off, throwaway action run directly from the CLI — used for diagnostics, quick fixes, or anything you won't need to repeat identically. A playbook (a `.yml` file executed via `ansible-playbook`) defines repeatable configuration meant to run the same way every time. `-i` names the inventory file (how Ansible knows what `tomcat01` means and how to reach it); `-m` names the module (the unit of built-in functionality, e.g. `ansible.builtin.shell` = "run this raw command"); `-a` supplies that module's arguments (for `shell`, just the command string).

*This project:* every diagnostic command this session (DNS renewal, ping/TCP checks, service restart, journal queries) was an ad-hoc command — none of it is saved anywhere, which is exactly why the `tomcat` role still needs a separate, permanent edit to actually install `tomcat10` going forward.

**`grep` exiting 1 on zero matches can be worked around cleanly with `|| echo 'NO MATCHES FOUND'`** rather than treating the resulting Ansible task failure as a real error each time — turns an ambiguous FAILED result into an unambiguous, readable one.

## Session 17 — 2026-09-27 — Tomcat Role Reconciliation, Credential Templating, Git Hygiene

**Ansible ad-hoc commands run as the SSM session's default user, not `root` or the service account — and permission errors from this are the access control working, not a bug.** `grep`ing a file we'd just set to `mode: 0640, owner: tomcat` failed with `Permission denied` under a plain ad-hoc command, because the command runs as `ssm-user`, which is neither `tomcat` nor a member of its group.

*This project:* confirmed the fix works by re-running with `-b` (`--become`, tells Ansible to run that one command via `sudo` on the target) — a deliberate, one-off privilege escalation for verification, not a standing permission change.

**`wait_for` with a `path` polls for a real condition; a fixed `pause`/`sleep` is a guess.** Tomcat only creates its exploded `webapps/vprofile/` directory a few seconds after service start (auto-deploy), so a task writing into that directory immediately after "start Tomcat" could race it on a slower instance.

*This project:* `ansible.builtin.wait_for: path: .../WEB-INF/classes, state: present, timeout: 60` — checks every second until the directory exists, rather than guessing a delay.

**Tomcat auto-explodes a deployed `.war` into a same-named directory alongside it — and only the exploded copy is what the running server actually reads.** `/usr/share/tomcat10/webapps/` ends up with both `vprofile.war` (the original archive) and `vprofile/` (Tomcat's unpacked copy). Editing the `.war` does nothing at runtime; the exploded directory is the real target for any post-deploy file change.

*This project:* `application.properties` is rendered to `webapps/vprofile/WEB-INF/classes/application.properties`, not into the `.war` file.

**A WAR's baked-in credentials are the reference app's original dev defaults, not a bug to patch in the artifact — the fix is overriding them at deploy time, not editing the file that ships them.** `jdbc.password=admin123` and `rabbitmq.password=test` in `vprofile.war` turned out to be the exact same values Project 1's own `mysql.sh` originally hardcoded, confirmed by reading Project 1's actual `PROGRESS.md` rather than guessing. Project 1's own architecture already solved this by writing a fresh `application.properties` at boot with real fetched secrets — never editing the WAR's compiled-in file.

*This project:* replicated that same pattern via Ansible's `template` module instead of a boot-time shell script — a `.j2` template with the two credential lines parameterized, rendered from `amazon.aws.secretsmanager_secret` lookups, same mechanism already used in the `mariadb`/`rabbitmq` roles.

**`git commit --amend` is safe on a local, unpushed commit — and unsafe (history-rewriting) on one already shared.** A commit's message undersold what it actually contained (staged before a related new file was added). Checking `git status` for "ahead of origin by N commits, not yet pushed" *before* amending is what made it safe — amending a commit already on `origin` would rewrite shared history instead of just correcting a local mistake.

**Git identity is genuinely per-shell-environment, not just per-tool-install — reinforced, not new.** A commit attempt from WSL failed outright (`empty ident name`) because WSL's Git had never been configured, since Session 13 already established all `git` commands run in Git Bash. This wasn't a new lesson so much as a concrete example of why that rule exists — switching shells fixed it in one step, no WSL Git config needed.

**A heredoc-written file can silently mangle one specific character while leaving everything else intact — worth scanning for, not assuming.** the emoji character `���` (a 4-byte "supplementary plane" Unicode character) became a stray `�` byte after a `cat > file << 'EOF'` heredoc in Git Bash's Windows console, while `✅` (a simpler, 2-byte character) on an adjacent line survived fine in the same file. `grep -nP "[\x80-\xFF]"` (match any byte outside plain ASCII), with known-good characters filtered out via `grep -v`, found the one bad spot without having to eyeball the whole file.

*This project:* fixed by replacing the one emoji with plain text (`(CURRENT)`) rather than fighting the terminal encoding — the safer general lesson: prefer simple ASCII/BMP characters in files edited across Windows/WSL/Git Bash boundaries, since emoji-class characters are the ones most likely to break in this pipeline.

**`--limit <host>` scopes one playbook run to a single inventory host without touching the playbook file.** Used to validate the new `tomcat` role changes in isolation before running the full playbook (which would also re-touch `mariadb`/`memcached`/`rabbitmq`, unnecessarily, since nothing in their roles changed).

*This project:* `ansible-playbook -i inventory/hosts.yml playbook.yml --limit tomcat01` — confirmed the actual top-level playbook filename is `playbook.yml`, not the more commonly-seen convention `site.yml` (an assumption that failed on first try).

## Session 18 — 2026-09-27 — Real Idempotency Bugs Found and Fixed

**A task that "worked the first time" can still not be idempotent — the second real run is the actual test, not a formality.** Three separate tasks across `mariadb` and `rabbitmq` passed cleanly on their first-ever execution and then genuinely failed or behaved destructively on the second. All three had looked complete after Session 12–14's individual role verification.

**`mysql_user` can silently switch MariaDB root's auth method away from `unix_socket` as a side effect of setting a password.** A fresh MariaDB install authenticates root passwordlessly via the `unix_socket` plugin (trusts the matching Linux user). Giving `mysql_user` a `password:` with no `login_password`/`login_user` specified works the first time (root has no password yet, connects via socket) — but can switch root to password-based auth as part of setting that password. Every run after that, the same socket-only connection attempt is correctly refused, because it's no longer the account's real auth method.

*This project:* fixed by adding `login_user: root` + `login_password: "{{ mariadb_root_password }}"` alongside the existing `login_unix_socket`, with `check_implicit_admin: true` now doing real work — try the password login first (works on run 2+), fall back to the socket only if that fails (true only on a genuinely fresh install).

**`check_implicit_admin: true` is a fallback flag, not a standalone mechanism — it needs a primary login path to fall back *from*.** With no `login_password` given at all, there was nothing to fail first; the task went straight to `unix_socket` every time, which is exactly why it worked once and broke afterward.

**A `mysqldump` file's own `DROP TABLE IF EXISTS` statements make `state: import` genuinely destructive on repeat runs, not just wasteful.** Read the actual file (`head -40 /tmp/accountsdb.sql` on the instance) before assuming a re-import is harmless — this one drops and recreates every table, deleting any real data written since the last import, on every single playbook run.

*This project:* guarded with a new read-only check task — `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='accounts' AND table_name='role'` — registered, `changed_when: false`, then `when: schema_check.stdout | trim == "0"` on the import task itself. Import only ever runs against a genuinely empty database now.

**`ansible.builtin.rpm_key` given a URL (instead of a local file path) for `key:` can't check "is this already imported" without fetching the URL first — so `state: present` still unconditionally re-fetches on every run.** This isn't a config mistake, it's a real limitation of checking presence via a remote key you haven't downloaded yet.

*This project:* confirmed the key genuinely was already present (`rpm -q gpg-pubkey --qf '%{summary}
' | grep -i rabbitmq` → real match) — meaning Session 14's temporary-NAT-Gateway install had held, and only the *check* was missing, not the actual state. Guarded with the same check-then-`when` pattern: a `shell` task (needed here specifically because of the `|` pipe — `command` can't interpret shell operators) with `failed_when: false` (since `grep` exiting 1 on zero matches is expected, not a real failure — same lesson as Session 14/16's `grep` gotcha, now hit a third time), registered, then `when: rabbitmq_key_check.rc != 0` on the actual fetch task.

**`when:` is a task-level directive, not a module argument — it must be indented at the same level as the module name, never nested underneath it.** Made this exact mistake once this session (on the mariadb import task — `when` ended up indented as if it were an `ansible.mysql.mysql_db` parameter, which would have silently made the guard do nothing) and caught it by re-reading the file's actual indentation before running anything, rather than assuming the edit matched the diff.

**The general fix shape used twice today, worth remembering as a reusable pattern:** when a task's own module can't idempotently check its own precondition, add a separate read-only task that queries real state (`register:` the result, `changed_when: false` since it's read-only, `failed_when: false` if a "no match" exit code is expected), then gate the real task behind `when:` on that result — rather than trusting the module's own `state: present`/`import` to be smart about it.

## Session 19 — 2026-09-27 — Reproducibility Test: Destroy/Recreate Succeeded, New Connectivity Gap Found

**Full destroy → recreate cycle completed cleanly** — `terraform destroy` (35 destroyed) followed by `terraform apply` (35 added) from a genuinely blank state, no manual AWS Console intervention. All 4 EC2 instances came up with a correctly-resolved standard (non-minimal) AL2023 AMI — the Session 9 AMI-filter fix held on a real second test.

**SSM agent registration lag is real and measurable, not instant** — after `terraform apply` completes, instances don't appear in `describe-instance-information` immediately. This run: 2 of 4 registered within ~90s, all 4 registered within ~8 minutes of apply completing. Worth checking `PingStatus` before assuming Ansible connectivity is broken on a freshly-built environment.

**The RabbitMQ temporary-NAT-Gateway bootstrap (Session 14) is a confirmed repeatable requirement, not a one-time fix** — rebuilding from scratch reproduced the exact same failure (GPG key fetch timeout, no route to `github.com`), for the exact same architectural reason (private subnet has no general internet route; RabbitMQ needs live `dnf` dependency resolution against upstream repos, which can't be substituted with a single S3-hosted file the way the PyMySQL wheel was). Confirmed the fix procedure is a repeatable 7-step cycle: add 3 NAT resources to `main.tf` → `plan` → `apply` → run Ansible `--limit rabbitmq01` → `terraform destroy -target=` the 3 resources → delete the block from `main.tf` → `plan` again to confirm `No changes`. Considered scripting this automatically; decided against it for now since Phase 6's destroy/recreate is a rare, one-time verification exercise, not a recurring workflow — noted as a possible future improvement, not implemented.

**New, unresolved connectivity gap found via the reproducibility test itself** — after rebuilding, `tomcat01` cannot reach any of the 3 backend services (MariaDB 3306, Memcached 11211, RabbitMQ 5672), tested and failed via both hostname (`db01.vprofile.internal`) and direct private IP (`172.20.3.56`). This is a genuinely new problem not present before the destroy/recreate — the exact same architecture worked prior to this session.

**Ruled out so far (with real evidence, not assumption):**
- All 3 backend services confirmed `active` via `systemctl is-active`, confirmed actually listening via `ss -tlnp` on their expected ports.
- DNS resolution confirmed correct (`getent hosts` returned correct IPs for all 3 backend hostnames from `tomcat01`).
- `vprofile-db-sg`'s ingress rule confirmed correct: port 3306, source = current `vprofile-app-sg` ID (`sg-00326644e64269700`) — no stale ID.
- `vprofile-app-sg`'s egress confirmed unrestricted (`-1` protocol, `0.0.0.0/0`) — not the source of the block.
- Both `tomcat01` and `mariadb01` confirmed to exist (verification of matching subnet was in progress when session ended — **first thing to check next session**).

**Failing by IP, not just hostname, is the important clue** — this rules out DNS/DHCP as any part of the current problem (it worked correctly right before this failure was found), and narrows the search to something at the routing or lower-level networking layer: subnet placement, route table association, or possibly NACLs (not yet checked this session).

## Session 20 — 2026-09-27 — Hardcoded DNS Records: A Second Rebuild-Sensitivity Bug

**A Terraform record set as a literal string has no idea what it's "supposed" to track — it just never changes.** `records = ["172.20.3.56"]` and `records = [aws_instance.db.private_ip]` look almost identical but behave completely differently on rebuild: the first is a fixed value Terraform will never revisit; the second is a real dependency Terraform re-evaluates and updates automatically whenever the referenced instance's IP changes.

*This project:* all three backend Route 53 records (`db01`, `mc01`, `rmq01`) were written as hardcoded strings from the very first apply, and silently drifted the moment the Session 19 destroy/recreate gave each instance a new private IP. `tomcat01` was resolving hostnames correctly to *stale* addresses — nothing was actually broken at the DNS-lookup mechanism level, the records themselves were just wrong.

**"Failing by IP too" ruled out DNS as a *mechanism*, but not as the actual root cause — those are different claims.** Session 19 correctly used the by-IP test to rule out DNS resolution/DHCP as the failure point. But the specific IP tested (`.56`, from the rebuild table in `PROGRESS.md`) was itself stale — so the by-IP test wasn't actually testing live infrastructure, it was testing a documented value nobody had re-verified against `describe-instances`. Same class of lesson as Session 6: a "record of intended state" (here, `PROGRESS.md`'s own rebuild table) isn't proof of current state, even when the record was accurate a few messages ago.

**Fix:** replaced all 3 hardcoded `records = ["<IP>"]` values with `records = [aws_instance.<name>.private_ip]` — verified via `terraform plan` (3 changed, 0 added/destroyed), `apply`, and a live TCP reachability recheck (`/dev/tcp` on 3306/11211/5672) from `tomcat01`, all three succeeding. Committed and pushed as `e6af0b3`.
