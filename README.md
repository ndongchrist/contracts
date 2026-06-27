# contracts

The single source of truth binding the independently-deployed services: **event
schemas** (here) and REST **OpenAPI** specs (added per service). Because the
services share no code, these contracts are the only thing keeping them
compatible — so they're versioned here and compatibility is enforced by the
registry, not by convention.

## Event schemas

```
events/
├── order.created/v1.json       # order-service  → catalog-consumer, payment-service
├── payment.succeeded/v1.json   # payment-service → order-service
├── payment.failed/v1.json      # payment-service → order-service, notification-consumer
└── order.confirmed/v1.json     # order-service  → notification-consumer
```

Each event is a JSON Schema (draft 2020-12). The Kafka message value is JSON;
the producer stamps a `schema_version` header (see the outbox relay).

## Compatibility

`scripts/register-schemas.sh` registers every schema to **Apicurio** under group
`events` as artifact `<topic>-value`, and sets the **global compatibility rule to
`BACKWARD`**. With BACKWARD enforced, a producer **cannot register** a schema that
would break existing consumers — the deploy fails in CI, not in production.

## Versioning rules

- **Additive, optional fields** → bump the file in place (still `v1`), stays BACKWARD-compatible.
- **Breaking change** (remove/rename/retype a required field) → add `v2.json` and a
  new topic version or migration plan; never edit `v1` in a breaking way.
- Events carry their `schema_version` as a Kafka header so consumers can branch.

## Register locally

```bash
kubectl -n kafka port-forward svc/apicurio-registry 8080:8080 &
REGISTRY_URL=http://localhost:8080/apis/registry/v2 ./scripts/register-schemas.sh
```
