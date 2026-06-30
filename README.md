# VPSmaxxing 🖥️⚡

> **I couldn't find anything that would just *set this up* for me — so I spent hours
> figuring it out, and then turned the whole thing into a skill so you don't have to.**
> Point your Claude Code (or Codex) at this and it'll stand up your own cloud VPS as
> a dedicated AI-agent workbench: install the agents, network it privately, bring
> over your skills / memory / history / logins, and keep it all synced — so you can
> run agents 24/7, in parallel, from anything — **without dropping thousands on a
> maxed-out MacBook Pro.**

A rented Linux box with 8 cores and 32 GB costs a few dollars a month (or a few
cents an hour). Your laptop becomes a thin cockpit; the VPS does the heavy lifting.

---

## What it does

- **Provisions** a fresh Linux VPS: git, Node + pnpm, Docker + compose, tmux
  (OS-aware: Amazon Linux 2023 / Ubuntu / Debian).
- **Installs + logs in** Claude Code and OpenAI Codex.
- **Makes the box self-aware** — hostname, MOTD, an `agent` launcher, and
  `CLAUDE.md`/`AGENTS.md` that tell every agent it's a dedicated, headless AI host
  and how to behave (right package manager, expose ports via tunnels, don't nuke
  other sessions).
- **Networks it with Tailscale** — SSH with **zero public ports**, stable address,
  works behind any firewall/NAT.
- **Adds "maxxing" launchers** — `claudevps` / `codexvps`: one command from your
  laptop drops you into a persistent tmux session running the top model at max
  reasoning.
- **cmux cockpit** (macOS) to drive many agents in parallel; plain tmux elsewhere.
- **Reverse access** so the VPS can read/write your laptop's files — including a
  **no-admin path for managed/work laptops** — with a one-command kill switch.
- **Migrates** your existing skills, memory, conversation history, and logins
  (GitHub `gh`, git, MCP servers).
- **Auto-syncs** skills/memory/history between laptop and VPS, automatically.

Every step here was **actually run** during a real setup. The hard-won gotchas live
in [`references/troubleshooting.md`](references/troubleshooting.md) — that file alone
is worth the repo.

---

## Quickstart

**With Claude Code (recommended):**
```bash
git clone <this-repo> ~/Personal-Projects/VPSmaxxing
bash ~/Personal-Projects/VPSmaxxing/scripts/install-skill.sh   # symlinks into ~/.claude/skills
```
Then in Claude Code just say: **"set up a VPS for my AI agents"** (or run
`/vpsmaxxing`). The skill **interviews you first** — what you have, which agents,
auth method, Tailscale, reverse access, migration, sync — then does it, step by step.

**Manual (no skill):** run the scripts in order on/against your VPS —
`scripts/provision-vps.sh` → authenticate → `scripts/setup-agent-env.sh` → then the
references for Tailscale, sync, etc.

---

## What you get (capability map)

| Phase | What | Reference |
|---|---|---|
| Provision | base + Node/pnpm + Docker + tmux | [`01`](references/01-provision-vps.md) |
| Agents | install + auth Claude Code & Codex | [`02`](references/02-install-agents.md) |
| Environment | hostname/MOTD/tmux/`agent`/self-briefing | [`03`](references/03-agent-environment.md) |
| Tailscale | SSH, no exposed ports | [`04`](references/04-tailscale.md) |
| Launchers | `claudevps`/`codexvps`, top model + reasoning | [`05`](references/05-maxxing-launchers.md) |
| cmux | macOS cockpit for parallel agents | [`06`](references/06-cmux-cockpit.md) |
| Ports | `localhost:PORT` testing via tunnel | [`07`](references/07-ports-localhost.md) |
| Reverse access | VPS→laptop files (+ no-admin path) | [`08`](references/08-reverse-access.md) |
| Migration | skills/memory/history/logins | [`09`](references/09-migration.md) |
| Auto-sync | two-way rsync on a timer | [`10`](references/10-autosync.md) |

Architecture & mental model: [`references/00-architecture.md`](references/00-architecture.md).

---

## Don't have a VPS yet? Here's where to get one 💸

*Researched June 2026; prices change — every figure links to its source. Pick by
how you'll use it:*

- **Cheapest always-on:** **Contabo Cloud VPS 30** — 8 vCPU / 24 GB / 200 GB NVMe
  for **~$16/mo flat**, unlimited traffic.
- **Best performance/$ (if your stack is ARM-clean):** **Hetzner CAX41** — 16 vCPU /
  32 GB ARM for **~$47/mo**.
- **Free, if you can get capacity:** **Oracle Cloud "Always Free"** Ampere A1 —
  up to **4 vCPU / 24 GB, $0 forever** (ARM; fight for stock).
- **Simplest managed:** **DigitalOcean** / **Vultr** (great UI/API).
- **Bursty/occasional:** an **AWS/GCP/Azure** hourly box that you **stop when idle**
  (pay only for disk while stopped).

> ⚠️ **The 24/7 trap:** hourly clouds look cheap per-hour but an always-on AWS
> `m6a.2xlarge` (8 vCPU/32 GB) is ≈ **$252/month**. Either go flat-rate, or
> stop-when-idle. (Flat-rate VPS keep billing even powered off — snapshot+destroy to
> truly stop paying.)


### Budget / best-value providers

> Pricing captured **June 2026**. EUR figures converted at **≈ €1 = $1.14** ([ECB/Trading Economics, 30 Jun 2026](https://tradingeconomics.com/euro-area/currency)); USD is approximate and region/VAT-dependent. ⚠️ **Hetzner raised CPX/CCX cloud prices ~110–175% on 15 June 2026** ([Hetzner price-adjustment notice](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/)), which reshuffles the value ranking below.

| Provider | Plan | vCPU / RAM | Disk | ~USD/mo | Regions | Link |
|---|---|---|---|---|---|---|
| **Hetzner Cloud** | CPX42 (AMD, shared) | 8 / 16 GB | 320 GB NVMe | **~$79** (€69.49) | DE, FI, US, SG | [hetzner.com/cloud](https://www.hetzner.com/cloud/) |
| **Hetzner Auction** | Refurb dedicated (e.g. i7 + 64 GB) | 4–8 / 32–64 GB | 2× SSD/HDD | **~$51** (≈€45) | DE, FI | [hetzner.com/sb](https://www.hetzner.com/sb/) |
| **Contabo** | Cloud VPS 30 | 8 / 24 GB | 200 GB NVMe | **~$16** (€14.00) | EU/US/UK/Asia/AU (9 regions) | [contabo.com/vps-server](https://contabo.com/en/vps-server/) |
| **Netcup** | VPS 2000 G12 | 8 / 16 GB DDR5 ECC | 512 GB NVMe | **~$18 net** (€16.18 ex-VAT) | DE, AT, NL, US, SG | [netcup.com/server/vps](https://www.netcup.com/en/server/vps) |
| **OVHcloud** | VPS-4 | 8 / 24 GB | 200 GB NVMe | **~$23** ($23.37) | EU (FR/DE/UK/PL), CA, US, APAC | [ovhcloud.com/vps](https://us.ovhcloud.com/vps/) |
| **Hostinger** | KVM 8 | 8 / 32 GB | 400 GB NVMe | **~$26 promo / ~$50 renew** | US/EU/Asia/SA | [hostinger.com/vps-hosting](https://www.hostinger.com/vps-hosting) |
| **Scaleway** | PRO2-XS | 4 / 16 GB | block storage extra | **~$93** (€81.90) + storage/IPv4 | FR (Paris), NL (Amsterdam), PL (Warsaw) | [scaleway.com/pricing/virtual-instances](https://www.scaleway.com/en/pricing/virtual-instances/) |

**Bandwidth at a glance:** Contabo 600 Mbit/s *unlimited* traffic; OVH 1.5 Gbps *unmetered*; Netcup unmetered; Hetzner CPX42 1 Gbit/s + **20 TB**/mo included (overage billed); Hostinger KVM 8 **32 TB**; Scaleway billed PAYG with egress included in list price.

**Standout pros / cons**

- **Hetzner** — Pros: best-in-class hardware, fast NVMe, hourly billing, real EU/US DCs. Cons: the June-2026 hike made x86 CPX/CCX pricey (CPX42 ~$79; dedicated CCX33 8 vCPU/32 GB ~$158, [costgoat Jun 2026](https://costgoat.com/pricing/hetzner)). The **ARM CAX41 (16 vCPU / 32 GB, €40.99 ≈ $47)** survived as a value monster *if your toolchain is ARM64-clean* — most agent CLIs and Docker images are. The **Server Auction** is the cheap path to a real dedicated box (no noisy neighbors, unlimited traffic), but stock/specs fluctuate ([Server Radar](https://radar.iodev.org/) helps).
- **Contabo** — Pros: rock-bottom flat pricing, generous RAM/disk, no setup fee, unlimited traffic, global DCs. Cons: oversubscribed shared cores and 600 Mbit/s port mean weaker single-thread/IO than Hetzner/Netcup; cheapest rate wants a 12-month term.
- **Netcup** — Pros: **DDR5 ECC RAM** + huge 512 GB NVMe at a low price, snapshots, hasn't hiked in 2026. Cons: EU-centric, prices quoted **incl. 19% VAT** (non-EU/business pay the ~€16.18 net), 1- or 12-month terms.
- **OVHcloud** — Pros: predictable flat pricing, unmetered 1.5 Gbps, anti-DDoS + daily backups included, wide DC footprint. Cons: support reputation is hit-or-miss; mid-tiers are middling on raw CPU.
- **Hostinger** — Pros: cheap *promo*, 32 GB RAM + 32 TB traffic, beginner-friendly panel, AMD EPYC. Cons: **renewal nearly doubles** (~$50) and the headline price needs a long up-front term.
- **Scaleway** — Pros: genuine cloud (API, snapshots, EU data sovereignty), true hourly PAYG. Cons: **far pricier** for sustained 24/7 use and block storage + IPv4 are billed separately — not a budget pick.

**💸 Best value pick:** **Contabo Cloud VPS 30 — 8 vCPU / 24 GB / 200 GB NVMe for ~$16/mo flat, unlimited traffic** ([contabo.com](https://contabo.com/en/vps-server/)) is the cheapest way to keep Claude Code + Codex agents running 24/7; step up to **Hetzner's ARM CAX41 (16 vCPU / 32 GB ≈ $47)** for the best raw performance-per-dollar if your stack is ARM64-friendly, or **Netcup VPS 2000 G12 (~$18, DDR5 ECC)** for the best price/quality balance on x86.


### Mainstream cloud providers

These are the big, well-supported clouds for running a Linux box with Claude Code + OpenAI Codex on it. Pricing verified June 2026; every figure links to its source. Target tier: ~4–8 vCPU / 16–32 GB RAM.

| Provider | Instance (plan) | vCPU / RAM | Disk | ~USD/mo | ~USD/hr | Link |
|---|---|---|---|---|---|---|
| **DigitalOcean** | General Purpose Droplet | 8 / 32 GB | 100 GB SSD | **$252** | $0.375 | [pricing](https://www.digitalocean.com/pricing/droplets) |
| **Vultr** | Cloud Compute (Regular) | 8 / 32 GB | 640 GB SSD | **$160** | $0.219 | [pricing](https://www.vultr.com/pricing/) |
| **Akamai Linode** | Shared "Linode 32 GB" | 8 / 32 GB | 640 GB SSD | **$192** | $0.288 | [pricing](https://www.akamai.com/cloud/pricing) |
| **AWS Lightsail** | 8 vCPU / 32 GB bundle | 8 / 32 GB | 640 GB SSD | **$164** | flat¹ | [pricing](https://aws.amazon.com/lightsail/pricing/) |
| **AWS EC2 (on-demand)** | m6a.2xlarge | 8 / 32 GB | EBS only² | **~$252** if 24/7 | $0.3456 | [pricing](https://aws.amazon.com/ec2/pricing/on-demand/) · [m6a.2xlarge](https://instances.vantage.sh/aws/ec2/m6a.2xlarge) |
| **Hetzner Cloud** | CCX33 (dedicated AMD) | 8 / 32 GB | 240 GB NVMe | **~$150**³ (€138.49) | $0.24 | [price notice](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/) |
| **Google Cloud** | e2-standard-8 | 8 / 32 GB | PD extra⁴ | **~$196** if 24/7 | $0.27 | [GCE pricing](https://cloud.google.com/products/compute/pricing/general-purpose) |
| **Microsoft Azure** | D8as_v5 (AMD) | 8 / 32 GB | disk extra⁴ | **~$252** if 24/7 | $0.344 | [D8as_v5](https://instances.vantage.sh/azure/vm/d8as-v5) |

¹ Lightsail bills hourly but is capped at the flat monthly price. ² EC2 m6a.2xlarge has no local disk — add EBS (100 GB gp3 ≈ $8/mo). ³ Hetzner bills EUR; USD approx at €1≈$1.08. ⁴ GCE/Azure prices are compute only — disk + egress billed separately.

**Notes & gotchas**

- **DigitalOcean** — simplest managed experience, great docs/UI/API, per-second billing with a monthly cap. A CPU-Optimized 8 vCPU / 16 GB is **$168/mo** if 32 GB is overkill. Con: dearer than budget VPS; bandwidth overage extra. ([src](https://www.digitalocean.com/pricing/droplets))
- **Vultr** — best mainstream value at this tier, 32+ regions. **High Performance NVMe 8 vCPU / 16 GB = $96/mo**. Con: a powered-off instance still bills (resources reserved). ([src](https://www.vultr.com/pricing/))
- **Akamai Linode** — clean predictable pricing, generous transfer; Shared 16 GB = 6 vCPU / 16 GB / **$96/mo**. Dedicated-CPU plans cost more but kill noisy-neighbor jitter. ([src](https://www.akamai.com/cloud/pricing))
- **AWS Lightsail** — flat AWS-flavored VPS, 7 TB bundled transfer. Con: fixed bundles, lower ceiling than EC2 — "set and forget," not bursty scaling. ([src](https://aws.amazon.com/lightsail/pricing/))
- **Hetzner Cloud** — historically the price/perf champ, but a **15 Jun 2026 hike raised CCX ~+120% / CPX ~+209%**. Still good NVMe + EU residency, fewer regions (DE/FI/US/SG). ([src](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/))
- **Google Cloud** — `e2-standard-8` is the value pick (~$196/mo); newer `c4-standard-8` is faster but ~$294/mo. Sustained/committed-use discounts help. ([src](https://cloud.google.com/products/compute/pricing/general-purpose))
- **Microsoft Azure** — `D8as_v5` (AMD) $0.344/hr; best if you're already in Microsoft/Entra; reserved instances cut cost a lot. ([src](https://instances.vantage.sh/azure/vm/d8as-v5))

⚠️ **The 24/7-cost trap.** Hourly clouds (**AWS EC2, GCE, Azure**) look cheap per-hour but get expensive run around the clock: AWS **m6a.2xlarge (8 vCPU/32 GB) = $0.3456/hr ≈ $252/mo** if always on ([Vantage](https://instances.vantage.sh/aws/ec2/m6a.2xlarge)); GCE e2-standard-8 ~$196/mo, Azure D8as_v5 ~$252/mo behave the same.

💡 **Stop-when-idle (the money-saver).** On EC2/GCE/Azure you can **stop** the instance when not coding — while stopped you pay only for the attached disk (EBS/PD/managed-disk, ~$8–12/mo for 100 GB), not compute. An agent box used ~3 hrs/day can cost **$30–40/mo instead of $250+**. Caveats: a static/Elastic IP may bill while stopped, and **flat-rate VPS providers (DO, Vultr, Linode, Lightsail, Hetzner) keep charging when powered off** — to stop paying there you snapshot + destroy, then rebuild.

☁️ **Best for managed/scalable:** **AWS EC2** (m6a.2xlarge + stop-when-idle) for max flexibility and pay-for-what-you-use, or **DigitalOcean** for the simplest predictable flat-rate managed VPS.


### Free & cheapest options + how much you actually need

Running Claude Code or OpenAI Codex on a VPS is cheap because the heavy lifting (the model) runs on Anthropic's/OpenAI's servers — your box is mostly a thin shell for `git`, package installs, builds, and the agent process. That means you can get away with very little, and there are a few genuinely-free ways to do it.

#### Free / nearly-free

| Option | Specs | Cost | Caveat | Link |
|---|---|---|---|---|
| **Oracle Cloud "Always Free" (Ampere A1, ARM)** | Up to 4 OCPU / 24 GB RAM + 200 GB block storage + 10 TB/mo egress | **$0 forever** | **ARM, not x86.** Frequent **"Out of host capacity"** in popular (esp. US) regions — EU/APAC provision faster. As of **June 2026** the headline was trimmed to **2 OCPU / 12 GB** for new free-tier signups (PAYG-upgraded accounts may still keep 4/24; enforcement is inconsistent). Idle instances can be reclaimed. | [oracle.com/cloud/free](https://www.oracle.com/cloud/free/) · [2026 change](https://terminalbytes.com/oracle-cloud-free-tier-changes-2026/) · [capacity notes](https://space-node.net/blog/oracle-cloud-always-free-limits-2026) |
| Oracle x86 micro (always free) | 2× VM.Standard.E2.1.Micro — ⅛ OCPU / 1 GB each | $0 forever | x86, but **1 GB RAM** each — too small for real builds; useful only as a control node. | [OCI free breakdown](https://fullmetalbrackets.com/blog/oci-free-tier-breakdown) |
| **GCP "Always Free" e2-micro** | 2 shared vCPU (~0.25 real) / **1 GB RAM** / 30 GB disk | $0 forever | **us-west1 / us-central1 / us-east1 only.** 1 GB RAM OOMs on `npm install`/docker — needs swap. New accounts also get a **$300 / 90-day** trial credit on top. | [cloud.google.com/free](https://cloud.google.com/free) |
| **AWS Free Tier (new accounts)** | Your choice of EC2 within credits | $100 on signup + up to $100 from activities (**$200 total**) | **New model = ~6 months**, expires when credits run out (accounts created after 15 Jul 2025). Not "always free." | [AWS Free Tier](https://aws.amazon.com/free/) · [announcement](https://aws.amazon.com/blogs/aws/aws-free-tier-update-new-customers-can-get-started-and-explore-aws-with-up-to-200-in-credits/) |
| AWS Free Tier (legacy accounts) | 750 hrs/mo t2/t3.micro (1 vCPU / **1 GB**) + 30 GB EBS | $0 for **12 months** | Only for accounts created **before 15 Jul 2025**; 12-month clock then bills at PAYG. 1 GB RAM is tight. | [Free Tier FAQ](https://aws.amazon.com/free/free-tier-faqs/) |
| **Azure free account** | $200 credit + 750 hrs/mo **B1S** (1 vCPU / 1 GB) Linux | $0 (credit 30 days; B1S free 12 mo) | **$200 credit expires in 30 days.** B1S is 1 GB. Disks/public IP/logs can bill even on "free" VMs. | [Azure free account](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account) · [free services](https://azure.microsoft.com/en-us/pricing/free-services) |
| **fly.io** | Pay-as-you-go Machines (from 256 MB) | Trial = **2 VM-hrs or 7 days**; cheapest always-on ~$2/mo | **No real free tier in 2026** (old Hobby allowances are legacy-only). A realistic small always-on box lands at **~$8–25/mo** once egress is counted. | [fly.io/pricing](https://fly.io/pricing/) |
| **Hetzner CAX11 (ARM)** ⭐ | **2 vCPU / 4 GB / 40 GB / 20 TB traffic** | **~€3.79/mo (~$4.50)** | Best genuine value. **ARM** (Ampere) — watch x86-only Docker images/binaries. ARM available in DE/FI only. Prices rose mid-2026. | [hetzner.com/cloud](https://www.hetzner.com/cloud/) · [price change](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/) |
| **Hetzner CX22 (x86)** | 2 vCPU / 4 GB / 40 GB / 20 TB traffic | **~€4.49/mo (~$5)** | x86 if you need it; EU + US (Ashburn/Hillsboro) locations. | [hetzner.com/cloud](https://www.hetzner.com/cloud/) |
| **RackNerd (annual)** | 1–2 vCPU / 1–2.5 GB / 20–50 GB SSD (x86) | **~$1.49–2/mo billed yearly (~$18/yr)** | Oversold shared CPU; **renewal price is higher than promo**; quality varies by deal. | [racknerd.com](https://www.racknerd.com/) |

**Bottom line on "free":** Oracle's Ampere A1 is the only free tier that's actually big enough to be comfortable — but you have to fight for capacity and accept ARM. Every other free tier (GCP/AWS/Azure micro) is **1 GB RAM**, which will OOM on real package installs and Docker builds unless you add swap and keep it to one light session. If free is fragile, **Hetzner CAX11 at ~$4.50/mo** is the dependable floor.

Both agents run fine on ARM: OpenAI Codex ships an `aarch64-unknown-linux-musl` build and Claude Code installs on ARM64 Linux — so the tools themselves aren't the ARM problem; your *project's* toolchain (some Docker images, prebuilt binaries, ML wheels) is. ([Codex releases](https://github.com/openai/codex), [Claude Code on Arm](https://learn.arm.com/install-guides/claude-code/))

#### How much do you actually need?

Claude Code and Codex are **network-bound to the model API**, not CPU-bound. The model does the thinking remotely; your VPS only does the "developer machine" work — cloning repos, `npm/pip/cargo` installs, Docker builds, running tests/linters, language servers, and holding several agent sessions open at once. So size for **builds and parallelism**, not for inference.

- **Minimum (single session, light projects): ~2 vCPU / 4–8 GB RAM, 40 GB disk.** Handles one agent, normal git/package work, and small test runs. Avoid 1 GB tiers — `npm install` and Docker will OOM. If you're stuck on a 1 GB free tier, add **2–4 GB swap** as a crutch. *Fits: Oracle A1 (2/12), Hetzner CAX11/CX22.*
- **Comfortable (parallel agents, Docker, big repos): ~4–8 vCPU / 16–32 GB RAM, 80 GB+ disk.** Run multiple agent sessions, Docker builds, language servers, and heavier test suites without thrashing. *Fits: Oracle A1 (4/24), a Hetzner CCX/CPX, or a hyperscaler box you stop when idle.*

**Region & latency.** Two different latencies matter, and the one you *feel* is **your terminal/SSH round-trip — so put the box near you.** Latency to the model API matters less: the agent **streams tokens**, so sustained throughput dominates over first-token RTT, and Anthropic/OpenAI endpoints are globally edge-routed. A US region shaves a little off first-token time, but "near me" wins for the interactive feel. Default: **closest region to you; US is a fine tiebreaker.**

**Money-saving tactics.**
- **Always-on dev box → flat-rate provider.** Hetzner/RackNerd-style fixed monthly pricing is far cheaper and more predictable than hyperscaler hourly rates (no egress surprises). The right default for a personal agent box you SSH into daily.
- **Bursty/occasional use → hourly cloud + stop-when-idle.** AWS/GCP/Azure only beat flat-rate if you actually **shut the instance down** when not coding (a cron/script that stops it saves ~70% vs 24/7). Leave one running overnight and the math flips against you.
- **Go ARM for cost.** Ampere/Graviton are ~20–40% cheaper per unit of performance and run the agents + most Node/Python/Go/Rust fine. Only avoid ARM if your project pulls **x86-only Docker images or prebuilt binaries**.
- **Spot/preemptible: skip for interactive work.** 60–90% off, but the provider can kill the VM mid-session — fine for checkpointed batch jobs, painful for a live agent.
- **Storage ≥ 40–80 GB.** `node_modules`, Docker layer caches, and multiple repo clones balloon fast; 20–30 GB free-tier disks fill within a couple of projects. On hyperscalers, watch **block-storage and egress** billing separately from the VM.


---

## How it works (90 seconds)

```
   LAPTOP (cockpit)                                VPS (workbench)
 cmux/tmux · editor · browser   ── Tailscale ──▶  agents in tmux · docker · builds
 localhost:5173 ◀── ssh tunnel ──────────────────  dev server :5173
 files ◀──────── reverse ssh ────────────────────  ssh mac (clone/copy/rm)
```
Laptop drives; VPS works; everything's on a private Tailscale mesh; agent state
syncs both ways. Full rationale in [`references/00-architecture.md`](references/00-architecture.md).

---

## Safety (read once)

- The box runs agents in **YOLO mode** on purpose — it's a disposable, isolated
  workbench. Keep real work in git.
- **Reverse access re-couples the blast radius** to your laptop (a runaway agent
  could delete laptop files). Scope it to a shared folder if unsure, and keep
  `revoke-vps-access` handy.
- **Never paste secrets into a chat.** The skill pipes credentials device-to-device
  and never prints them; if a key leaks, rotate it.
- Tailscale means you can keep **port 22 closed to the world** entirely.

---

## Repo layout

```
SKILL.md            the Claude Code skill (interview + orchestration)
references/00..10    step-by-step guides, OS-aware, generalized
references/troubleshooting.md   every trap that cost hours
scripts/            runnable: provision, setup-agent-env, agent-sync,
                    mac-user-sshd (no-admin reverse access), install-skill
```

---

## Status & credits

Built by generalizing a real, end-to-end setup (AWS Amazon Linux 2023 + a managed
macOS laptop) into something anyone can re-run. PRs welcome — especially provider
price updates and more OS branches.

*Made because renting 8 cores should be easier than affording 8 cores.* 🚀
