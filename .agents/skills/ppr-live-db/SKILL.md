---
name: ppr-live-db
description: Connect to and run queries against the PPR live replica MySQL database (hnddb). Use this skill when the user asks to query PPR live data, look up shops, agents, rounds, deliveries, activity logs, or any production PPR data. Also covers the Mercury config variant.
---

# PPR Live Replica Database

## Overview

The PPR live system uses a **MySQL** database called `hnddb` (743 tables). Query scripts in the support directory handle credential fetching from AWS SSM and connection automatically.

## Scripts

- **Live config:** `~/ws/ppr/tech/tools/hnddb-queries/query-db.ts` (SSM param: `/appconfig/live`)
- **Mercury config:** `~/ws/ppr/tech/tools/hnddb-queries/query-mercury.ts` (SSM param: `/appconfig/mercury`)
- **Working directory:** `~/ws/ppr/tech/tools/hnddb-queries/`
- Use `query-db.ts` for most queries. `query-mercury.ts` uses a different credential path but same database.

## Prerequisites

1. AWS SSO login: `aws sso login --profile paperround`
2. Node deps: `cd ~/ws/ppr/tech/tools/hnddb-queries && npm install`

## Running Queries

```bash
# Direct execution (most common)
npx tsx ~/ws/ppr/tech/tools/hnddb-queries/query-db.ts "SELECT * FROM shops LIMIT 5"

# Via npm script
cd ~/ws/ppr/tech/tools/hnddb-queries && npm run query -- "SELECT * FROM shops LIMIT 5"

# With bastion tunnel
DB_USE_TUNNEL=1 DB_TUNNEL_PORT=3306 npx tsx ~/ws/ppr/tech/tools/hnddb-queries/query-db.ts "SELECT ..."
```

## How It Works

1. Fetches SSM parameter (`/appconfig/live` or `/appconfig/mercury`) from `eu-west-1` with decryption
2. Parses INI-style config to extract `readonlydb` (replica host) and `update_user_escaped` (user:password)
3. Connects to MySQL port 3306, database `hnddb`
4. Executes query and prints tab-separated results with headers

## Important Notes

- **Read replica only** — safe for SELECT, do NOT attempt writes
- MySQL (not PostgreSQL like the portal databases)
- Credentials fetched fresh each time from SSM — no local storage
- `update_user_escaped` used because readonly user has IP restrictions
- SSM region is `eu-west-1` (not `eu-west-2`)
- When unsure of a table's schema, use `DESCRIBE <table_name>` or `SHOW TABLES LIKE '%keyword%'`

## Data Model Reference

The data model documentation is split into domain-specific files in this skill directory. **Read the relevant file(s) before writing queries** to understand table schemas, relationships, and lookup values.

### Available data model files

- **`data-model-core.md`** — Core entities: shops, customers, publications, publicationprices, customerpublications, days lookup, delivery persons, agents, financial transactions, addresses, key relationships, common query patterns
- **`data-model-rounds.md`** — Full rounds domain: round structure & config, membership & ordering, delivery person assignment (intended vs actual, 5 layers), payment configuration (paybands, frequencies, extras), actual deliveries (deliveryhistory → rounddeliveries → rounddeliverypublications), delivery app (deliverydrop with GPS), training rounds (lifecycle, completion, controls, rules), split rounds, charges, delivery frequency, contractor types
- **`data-model-delivery-persons.md`** — Delivery persons domain: core deliverypersons table (status/lifecycle, type, payment fields, delivery app link), contractortypes lookup, deliverypersongroups, all tables referencing deliverypersonid (round assignment, actual deliveries, payments, collections, route optimisation, training), common query patterns
- **`data-model-activity-logs.md`** — Activity/logging domain: user login trail, delivery app logs, shop command logs, customer/shop/account audit trails, email logs, and common filtering patterns by user/date/entity
- **`data-model-packing.md`** — Packing domain: pack site hierarchy (hubs/child sites, nested set), bundle config per publication/day, title sets, cages, supplier priorities, publication routing overrides, report sheet types (Bundles/Title Sets/Spares/Totals/Cages)

To read a file, use its path relative to this skill: `~/.agents/skills/ppr-live-db/<filename>`

### Quick table/domain lookup

- shops, customers, publications, addresses, transactions → `data-model-core.md`
- rounds, deliveries, roundmembers, training, splits, paybands, chargebands, deliverydrop → `data-model-rounds.md`
- deliverypersons, contractortypes, deliverypersongroups, deliverypersonpayments, deliverypersonpaymentextra, collectionbatch, odlroutesettings → `data-model-delivery-persons.md`
- agents → `data-model-core.md`
- roundpayments (intended delivery person), rounddeliveries (actual delivery person) → `data-model-rounds.md` and `data-model-delivery-persons.md`
- deliveryhistory, rounddeliveries, rounddeliverypublications → `data-model-rounds.md`
- activity logs, audit trails, login history, command logs, delivery drop logs → `data-model-activity-logs.md`
- packingpacksites, packingcages, packingtitlesets, packingbundlelabels, packingsuppliers, bundle/title-set config → `data-model-packing.md`
