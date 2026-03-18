# Activity Log Domain (hnddb)

Use this domain when the user asks for operational/audit history such as:
- user logins and access events
- shop/account/customer audit changes
- shop command execution history
- delivery app activity logs
- outbound email and related status/history

## Key Tables

### Login and access
- `userlogin` — user login events
- `userloginactions` — login action types / lookup
- `login_tokens` — token records

### General/system logs
- `internaljoblog` — internal job/process logging
- `shopcommandlog` — command activity against shops
- `deliverydroplog` — delivery app / drop logging
- `tnclog` — terms and conditions log
- `paf_search_log` — address lookup/search log

### Email logs
- `emaillog` — outbound email records
- `emaillogstatus` — status lookup for email events
- `customerbillsemaillog` — customer billing email events
- `customerbillsemailloghistory` — customer billing email history
- `customersentlog` — customer message sent log
- `customersentlogtypes` — customer sent log type lookup

### Audit trails
- `accountsaudit`, `accountsaudittypes`
- `customeraudits`
- `shopaudit`, `shopaudittypes`
- `shopinternalaudit`, `shopinternalauditdetails`, `shopinternalaudittypes`
- `shopremittanceaudit`, `shopremittanceaudittypes`
- `addressbase_audit`

## Querying Workflow

1. Identify target table by event type above.
2. Inspect schema first:
   - `DESCRIBE <table_name>`
3. Build filtered query with:
   - time window (`created`, `createdon`, `date`, or equivalent column)
   - entity id(s) (e.g., shop/customer/account/user id)
   - relevant action/status type joins
4. Order newest first and limit initially:
   - `ORDER BY <time_column> DESC LIMIT 100`

## Starter Query Patterns

```sql
-- 1) Inspect recent login events
SELECT *
FROM userlogin
ORDER BY id DESC
LIMIT 100;

-- 2) Recent shop command activity for a shop
SELECT *
FROM shopcommandlog
WHERE shopid = 12345
ORDER BY id DESC
LIMIT 100;

-- 3) Delivery drop log for a delivery person / drop
SELECT *
FROM deliverydroplog
WHERE deliverypersonid = 12345
ORDER BY id DESC
LIMIT 100;

-- 4) Recent customer audit events
SELECT *
FROM customeraudits
WHERE customerid = 12345
ORDER BY id DESC
LIMIT 100;

-- 5) Email log with status
SELECT el.*, els.*
FROM emaillog el
LEFT JOIN emaillogstatus els ON els.id = el.status
ORDER BY el.id DESC
LIMIT 100;
```

## Practical Notes

- Column names differ across legacy tables; always `DESCRIBE` first.
- Prefer bounded windows and ids to avoid scanning large log tables.
- Treat these tables as append-heavy historical data; do not attempt writes.
