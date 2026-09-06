# 002 — Shared VPC rather than VPC peering

> **Stub.** `docs/architecture.md` already argues this at length under "Why
> Shared VPC rather than VPC peering". Decide whether this ADR restates that in
> decision form or simply points at it — duplicating it means two documents
> that can drift apart. Delete these prompts either way.

## Context

<!-- Team count now and projected. Who owns networking. What on-premises
     connectivity is assumed to exist. -->

## Options considered

<!-- Shared VPC / VPC peering mesh / Network Connectivity Center.
     The architecture doc covers the mechanics; what belongs here is which
     constraint actually decided it for THIS org. -->

## Decision

<!-- One sentence, your voice. -->

## Consequences

<!-- The host project is a change bottleneck and a single failure domain.
     Service-projects-per-host is a quota with a ceiling. GKE secondary ranges
     are allocated up front, so IP space is reserved against clusters that may
     never exist. Name the one that would actually bite you first. -->
