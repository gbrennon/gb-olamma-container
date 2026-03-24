# GitHub / Forgejo Actions Standards

## Mandatory Lint Job

Every repository must have a lint-workflows job that runs on any workflow file change:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions: read-all

jobs:
  lint-workflows:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4

      - name: Lint YAML
        uses: ibiqlik/action-yamllint@v3
        with:
          config_file: .yamllint.yml
          file_or_dir: .github/workflows .forgejo/workflows

      - name: Lint Actions
        uses: raven-actions/actionlint@v2

      - name: Security scan
        uses: woodruffw/zizmor-action@v1
```

## .yamllint.yml

Place at repository root:

```yaml
extends: default
rules:
  line-length:
    max: 120
  truthy:
    allowed-values: ["true", "false"]
  comments:
    min-spaces-from-content: 1
```

## Permissions Template

```yaml
permissions: read-all  # workflow-level default

jobs:
  build:
    permissions:
      contents: read
      packages: write  # only what this job needs
```

## Environment-Gated Secrets

```yaml
jobs:
  deploy:
    environment: production          # gates access to production secrets
    runs-on: ubuntu-24.04
    steps:
      - name: Deploy
        env:
          TOKEN: ${{ secrets.DEPLOY_TOKEN }}   # scoped to this job only
        run: ./scripts/deploy.sh
```

## Reusable Workflow Pattern

```yaml
# .github/workflows/_build.yml  (reusable, prefixed with _)
on:
  workflow_call:
    inputs:
      rust-version:
        required: true
        type: string

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@v1
        with:
          toolchain: ${{ inputs.rust-version }}
```

```yaml
# .github/workflows/ci.yml  (caller)
jobs:
  build:
    uses: ./.github/workflows/_build.yml
    with:
      rust-version: stable
```

## Drift Prevention Checklist

Before merging any workflow change, verify:

- [ ] actionlint passes with zero errors
- [ ] yamllint passes with zero warnings
- [ ] zizmor passes with no high-severity findings
- [ ] All actions pinned to a specific version tag
- [ ] permissions declared at job level, not workflow level for write access
- [ ] No secrets referenced outside of environment-gated jobs
- [ ] timeout-minutes set on every job
- [ ] Runner pinned to a specific version (ubuntu-24.04, not ubuntu-latest)
- [ ] No duplicated job blocks — extracted to reusable workflow if repeated

## Forgejo-Specific Notes

Forgejo Actions uses the same workflow syntax as GitHub Actions with these differences:
- Runner labels are self-managed. Pin to your registered runner label explicitly.
- Use `forgejo-actions/` namespace for Forgejo-native actions where available.
- Secrets are managed per-repository or per-organization in the Forgejo UI.
- `workflow_call` reusable workflows are supported from Forgejo 1.21+.
