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
