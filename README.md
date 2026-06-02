# terraform-azurerm-aks

An example AKS module built to demonstrate Terraform **module
authoring** patterns.

## What this module demonstrates

| Pattern | Where to look |
|---|---|
| Input validation (single + cross-field) | `variables.tf` — `cluster_name`, `default_node_pool` |
| Optional object attributes with defaults | `variables.tf` — `optional(...)` everywhere |
| `for_each` over a map of objects | `main.tf` — `azurerm_kubernetes_cluster_node_pool.this` |
| `dynamic` blocks toggled by inputs | `main.tf` — `identity`, `network_profile`, `oms_agent` |
| Feature flags via nullable inputs | `main.tf` — `monitoring_enabled` local |
| Computed/derived names | `main.tf` — `dns_prefix` local |
| Sensitive outputs | `outputs.tf` — `kube_config*` |
| Version pinning | `versions.tf` |
| Native tests with mock providers | `tests/aks.tftest.hcl` |

## Usage

```hcl
module "aks" {
  source = "github.com/<you>/terraform-azurerm-aks?ref=v0.1.0"

  resource_group_name = "rg-platform"
  location            = "swedencentral"
  cluster_name        = "aks-platform"
}
```

See `examples/minimal` and `examples/complete` for full configs.

## Design notes

- **Secure-by-default:** `local_account_disabled = true`, network policy
  defaults to `azure`, and `api_server_authorized_ip_ranges` locks the public
  API server when set. Two Trivy findings remain suppressed via documented
  inline `#trivy:ignore` directives, because Trivy can't resolve secure values
  passed through variables and `dynamic` blocks.
- **`ignore_changes = [kubernetes_version]`** keeps routine applies from
  fighting Azure's out-of-band patch bumps. Pin the minor version via the
  `kubernetes_version` input and upgrade deliberately.
- **Spot pools** automatically get the
  `kubernetes.azure.com/scalesetpriority=spot:NoSchedule` taint and matching
  label so only tolerant workloads schedule onto them.
- **Identity** is a single input (`identity_type`) that selects between two
  mutually exclusive `dynamic "identity"` blocks — a clean way to model
  "exactly one of N" in HCL.

## Testing

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform test            # runs tests/*.tftest.hcl with mocked providers
```

`terraform test` here uses `mock_provider`, so it needs **no Azure
credentials** and is safe to run in CI on every PR.

## CI hints (GitHub Actions)

```yaml
name: terraform-module-ci
on:
  pull_request:
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.8
      - run: terraform fmt -check -recursive
      - run: terraform init -backend=false
      - run: terraform validate
      - run: terraform test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: terraform-linters/setup-tflint@v4
      - run: tflint --init && tflint --recursive

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # Static analysis for misconfig — Trivy/tfsec/checkov all work here.
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: config
          scan-ref: .
```

Additional things real module repos add:
- **`terraform-docs`** to auto-generate the inputs/outputs tables in this README.
- **Conventional commits + release-please** (or `semantic-release`) to cut
  semver tags, which is what `?ref=v0.1.0` consumers depend on.
- **A `.tflint.hcl`** enabling the `azurerm` ruleset for provider-aware lint.

## Versioning

Tag releases with semver (`v0.1.0`). Consumers pin via `?ref=`. Breaking
changes to inputs/outputs bump the major version.
