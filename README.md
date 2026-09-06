# gcp-landing-zone-terraform

<!-- Written in Weekend 6, by you, from the template in the build guide.
     Sections: The problem / Architecture / Key decisions / Cost /
     Running this / What this does not cover. -->

A reference GCP landing zone: org hierarchy, org policy, Shared VPC,
group-based IAM, a project factory, and keyless CI/CD.

## Status

| Weekend | Deliverable | State |
|---|---|---|
| 1 | `environments/bootstrap` — state bucket, CI SA, WIF | Written, not applied |
| 2 | `modules/folder-structure`, `modules/org-policies`, `environments/sandbox` | Written, not applied |
| 3 | `modules/shared-vpc`, `docs/architecture.md` | Written, not applied |
| 4 | `modules/project-factory`, `teams/teams.yaml`, `environments/production`, `environments/non-production` | Written, not applied |
| 5 | `.github/workflows/` — plan on PR, gated apply on merge | Written, not run |
| 6 | `docs/diagrams/` generated | README narrative still to write |
