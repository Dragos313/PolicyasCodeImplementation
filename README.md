# Policy as Code — Self-Healing Cloud Infrastructure

Automated security auditing and **self-healing** for Terraform infrastructure on Microsoft Azure, powered by [Open Policy Agent (OPA)](https://www.openpolicyagent.org/).

This project implements a **"Policy Gate"** that sits between your infrastructure code and the cloud. Before any resource is deployed, the Terraform plan is evaluated against organisation-wide security and governance rules written in **Rego**. Non-compliant configurations are blocked at the source — and, uniquely, the pipeline can **automatically rewrite the vulnerable code** to make it compliant, cutting Mean Time To Remediation (MTTR) to seconds.

> Built on the principles of **Shift-Left Security**, **Zero Trust** and **Defense in Depth**. Presented at the ESTIC conference.

---

## Why?

Most cloud breaches come from **misconfiguration**, not sophisticated attacks. As Infrastructure as Code (IaC) lets teams ship resources faster than security teams can audit them manually, this project turns security policy into automated, enforced code — and goes one step beyond detection to **self-repair**, keeping the developer workflow fast while making the cloud environment compliant by default.

---

## How It Works

```
  ┌───────────┐     ┌──────────────────────┐     ┌────────────────┐
  │  DEFINE   │ ──▶ │      TRANSFORM       │ ──▶ │  DECIDE (OPA)  │
  │ main.tf   │     │ terraform plan       │     │ Rego policy    │
  │ (HCL)     │     │   → tfplan.json      │     │ evaluation     │
  └───────────┘     └──────────────────────┘     └───────┬────────┘
                                                          │
                            ┌─────────────────────────────┴───────────────┐
                            ▼                                              ▼
                  ┌──────────────────┐                        ┌────────────────────────┐
                  │  PASS            │                        │  FAIL → SELF-HEALING   │
                  │  terraform apply │                        │  Auto-patch HCL,       │
                  │  (secure deploy) │                        │  then re-evaluate      │
                  └──────────────────┘                        └────────────────────────┘
```

1. **Define** — infrastructure is described declaratively in Terraform (HCL).
2. **Transform** — `terraform plan` output is exported to JSON (`tfplan.json`), the universal contract between Terraform and OPA.
3. **Decide** — OPA evaluates the plan against the Rego policies and returns an `allow` / `deny` verdict.
4. **Act:**
   - **PASS** → `terraform apply` runs and only compliant resources reach Azure.
   - **FAIL** → the orchestrator blocks the deploy and offers to trigger the **self-healing** module, which uses regex-based patching to rewrite the non-compliant HCL into secure resources, then re-evaluates.

The orchestration is **cross-platform** (PowerShell on Windows, Bash on Linux), thanks to the platform-independent Terraform and OPA binaries.

---

## Governance Policies Enforced

| Policy | Rule |
| --- | --- |
| **SSH exposure** | Blocks any NSG rule allowing inbound traffic on port `22` from an unrestricted source (`*`). |
| **Public network access** | Denies creation of Storage Accounts / Key Vaults that expose a public network endpoint. |
| **GDPR data residency** | Flags any resource created outside EU regions (e.g. `West Europe`) as non-compliant. |
| **Cost governance (tagging)** | Requires mandatory tags (`Department`, `CostCenter`) on all resources for financial traceability. |

New rules can be added simply by dropping additional `.rego` files — no change to the orchestration script required.

---

## Results

| Metric | Result |
| --- | --- |
| Detection rate (defined rules) | **100%** |
| Policy evaluation latency (OPA) | **< 30 ms** |
| Audit time vs. manual review | **minutes → milliseconds** |
| MTTR with self-healing | **seconds** |

---

## Tech Stack

- **Terraform** `v1.14.8` (HCL) — `azurerm` provider
- **Open Policy Agent** `v1.15.1` (Rego)
- **Microsoft Azure** (Resource Groups, NSG, Storage Account, Key Vault)
- **PowerShell** / **Bash** — pipeline orchestration
- **JSON** — data interchange between Terraform and OPA
- **Azure CLI** — authentication (with Entra ID + MFA)

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.14`
- [Open Policy Agent](https://www.openpolicyagent.org/docs/latest/#running-opa) `>= 1.15`
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- An active Azure subscription
- PowerShell 7+ (Windows) or Bash (Linux/macOS)

---

## Getting Started

```bash
# 1. Authenticate to Azure
az login

# 2. Initialise Terraform (downloads the azurerm provider)
terraform init

# 3. Run the policy gate
#    Windows:
./runCheck.ps1
#    Linux/macOS:
./runCheck.sh
```

The orchestration script will:
1. Generate the execution plan and convert it to `tfplan.json`.
2. Evaluate it with OPA against the Rego policies.
3. On **PASS**, proceed to `terraform apply`.
4. On **FAIL**, report every violation and offer to run the self-healing module.

> **Tip:** to see the pipeline in action, the repo includes intentionally misconfigured resources (a "broken by design" plan) so you can watch the gate catch and remediate them.

---

## Project Structure

```
.
├── main.tf              # Infrastructure definition (HCL)
├── politici.rego        # Security & governance policies (Rego)
├── runCheck.ps1         # Pipeline orchestrator (PowerShell)
└── README.md
```
---

## Roadmap / Future Work

- Native integration into a CI/CD platform (GitLab CI / GitHub Actions).
- Extend policy coverage toward multi-cloud (AWS, GCP).
- Richer self-healing beyond regex — AST-based rewriting of HCL.

---

## Author

**Dragoș-Andrei Pană** — MSc Cyber Security & Machine Learning, Ovidius University of Constanța
pana749@gmail.com

---

## License

Released under the [MIT License](LICENSE). Feel free to use, learn from, and build on this project.
