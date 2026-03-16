# HNDDB Queries

Query scripts for the PPR live replica MySQL database (`hnddb`). Credentials are fetched automatically from AWS SSM Parameter Store.

## Prerequisites

1. **AWS SSO authentication** — logged in with a profile that has SSM access in `eu-west-1`:
   ```bash
   aws sso login --profile paperround
   ```

2. **Node dependencies**:
   ```bash
   cd hnddb-queries && npm install
   ```

## Scripts

### query-db.ts — Live config (most common)

Fetches credentials from SSM parameter `/appconfig/live`.

```bash
# Direct execution
npx tsx query-db.ts "SELECT * FROM shops LIMIT 5"

# Via npm script
npm run query -- "SELECT * FROM shops LIMIT 5"
```

### query-mercury.ts — Mercury config

Fetches credentials from SSM parameter `/appconfig/mercury`. Same database, different credential path.

```bash
npx tsx query-mercury.ts "SELECT * FROM shops LIMIT 5"

# Via npm script
npm run query:mercury -- "SELECT * FROM shops LIMIT 5"
```

### With bastion tunnel

If connecting via a bastion tunnel instead of directly to the RDS endpoint:

```bash
DB_USE_TUNNEL=1 DB_TUNNEL_PORT=3306 npx tsx query-db.ts "SELECT ..."
```

## How It Works

1. Fetches the SSM parameter from `eu-west-1` with decryption
2. Parses the INI-style config to extract:
   - `readonlydb` — the replica host
   - `update_user_escaped` — the `user:password` pair (the write user is used because the readonly user has IP restrictions; queries run on a read replica so this is safe)
3. Connects to MySQL on port `3306`, database `hnddb`
4. Executes the query and prints tab-separated results with column headers

## Important Notes

- This connects to a **read replica** — safe for SELECT queries, do NOT attempt writes
- The database is **MySQL** (not PostgreSQL like the portal databases)
- Credentials are fetched fresh each time from SSM — no local credential storage
- AWS region for SSM is `eu-west-1` (not `eu-west-2`)
- Output format: tab-separated with column headers and row count
