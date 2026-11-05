# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

A collection of independent, standalone Terraform/OpenTofu examples for AWS — one directory per example (`ec2`, `ec2-ebs`, `auto-scaling-group`, `eks-fargate`, `eks-fargate-lb`, `elasticsearch-single-az`, `elasticsearch-multi-az`, `rds-oracle`). There is no shared root module and no cross-module references; each directory has its own `provider.tf` and is init/applied on its own. `eks-fargate-lb` builds on the `eks-fargate` pattern by duplicating (not importing) its code and adding an ALB (`load-balancer.tf`) plus `nginx/` manifests.

## Agents

Project agents are in `.claude/agents/` (`issue-worker`, `module-builder`, `tf-auditor`, `tf-planner`, `pr-reviewer`, `azure-pipeline`); `docs/agents.md` lists them and the usual workflow. Commits and PRs here carry no `Co-Authored-By` line.

## Commands

Tooling is pinned via devbox (`devbox.json`: OpenTofu 1.10.2, kubectl, helm, k9s). Use `tofu`, not `terraform`, locally (CI uses `terraform` 1.5.0).

```sh
devbox shell                      # enter the pinned toolchain
devbox run fmt                    # tofu fmt across every dir containing .tf files
cd <module> && tofu init && tofu validate
cd <module> && tofu plan / apply
tflint --init && tflint --chdir=<module>   # uses root .tflint.hcl (aws ruleset)
checkov -d .                      # config in .checkov.yaml; the CI job is currently disabled (if: false)
```

CI (`.github/workflows/terraform-ci.yml`) runs fmt-check → validate (`init -backend=false`) → tflint on top-level module dirs. There are no tests (`devbox run test` is a stub).

## Conventions

From `.github/copilot-instructions.md` and enforced partly by `.tflint.hcl` (naming convention, documented variables/outputs, unused providers):
- No abbreviated names; underscore-separated; resource names are nouns and don't repeat the resource type.
- Every variable has `type` and `description`; every output has `description`.
- `#` for comments; always include an explicit provider configuration.
- Use `count`/`for_each` sparingly; avoid excess variables/locals.

## Gotchas

- Local `terraform.tfstate*` files exist in some module dirs (`ec2`, `eks-fargate*`, `rds-oracle`); `.gitignore` excludes them — never commit state or `.tfvars` with real values (`rds-oracle` ships `terraform.tfvars.example`).
- `.terraform.lock.hcl` is gitignored.
- Security scanning context lives in `SECURITY_IMPROVEMENTS.md`, `.checkov.yaml` (skips CKV_AWS_338, CKV_AWS_117), and `.github/prompts/run-checkov.md` / `run-security-scan.md`; `.github/cidr.md` documents CIDR choices.
- `ec2-ebs` has Ansible/shell helpers (`mount-disk-ansible.sh`, `mount-disk-cli.sh`) for mounting the extra volume, with its own README.
