# PPR Data Model — Delivery Persons Domain

## deliverypersons — Core table
The central record for anyone who delivers, collects, packs, trunks, or trains on a round.
- `id` (PK, auto_increment), `shopid` → shops
- `familyname`, `firstname`, `title`, `posttitle`
- `mobile`, `telephone`, `email`
- `addressid` → addresses
- `dayeofbirth` (date, note: misspelled in schema)
- `employeeref`, `workpermit`, `vatno`

### Status & lifecycle flags
- `active` (int) — whether the person is currently active
- `disabled` (tinyint) — person has been disabled (e.g. training failure, offboarded)
- `stopped` (tinyint) — person has been stopped (usually set alongside `disabled`)
- **Lifecycle:** A new delivery person starts with `active=1, disabled=0, stopped=0`. Training failure sets `disabled=1, stopped=1`. Offboarding or end of contract may also set these.

### Type & grouping
- `contractortypeid` → contractortypes — the person's role (default: 2 = Delivery)
- `deliverypersongroupid` → deliverypersongroups — payment group membership

### Payment fields
- `paymentfrequencyid` — how often this person is paid
- `paidupto` (datetime) — date payments have been processed up to
- `nextpaymentdate` (datetime) — next scheduled payment date
- `sendpayslipbyemail` (tinyint) — whether payslips are emailed
- `newpay` (tinyint) — flag for new payment system
- `badetails` (blob) — bank account details (encrypted/binary)
- `exported` (tinyint) — whether payment data has been exported

### Delivery app
- `del_app_userid` → users — links to the delivery app login account

### Other
- `created` (datetime) — record creation timestamp
- `startdate` (datetime) — when the person started
- 29 columns total

## contractortypes — Role/type lookup
Defines what kind of work a delivery person does. Both system-wide and shop-specific types exist.
- `contractortypeid` (PK), `shopid` (NULL for system types), `shopgroupid`, `contractortypesdescription`

System types (shopid IS NULL):
- 1 = Other
- 2 = Delivery (default for regular delivery persons)
- 3 = Delivery (minor)
- 4 = Trunking
- 5 = Packing
- 6 = Training (set during training round, changes to 2 on success)
- 7 = Management

**Key transitions:** When a training round completes successfully, the trainee's `contractortypeid` changes from 6 → 2. On training failure, the person is disabled (`disabled=1, stopped=1`) but type remains 6.

## deliverypersongroups — Payment grouping
Groups delivery persons for batch payment processing.
- `id` (PK), `shopgroupid`, `description` (varchar(1) — single-char group code)
- `paymentfrequencyid` — group-level payment frequency
- `paidupto`, `nextpaymentdate` — group-level payment tracking

## Where delivery persons appear across the system

### Round assignment (who should deliver)
See `data-model-rounds.md` → "Delivery Person Assignment" for full details.

**`roundpayments`** — The contracted/paid person for a round over a date range. This is the **primary source of truth** for intended delivery person on any given date.
- `deliverypersonid` → deliverypersons (NULL = VACANT)
- `start_date`/`end_date` — date range of assignment

**`rounds.deliverypersonid`** — Live "NOW" view of the current delivery person. No date context — only reflects the present. Always prefer `roundpayments` for historical queries.

**`rounddeliverypersondays`** — Per-day-of-week overrides (e.g. different person on Sundays).
- `deliverypersonid` → deliverypersons

**`rounddeliverypersonchanges`** — Temporary cover/substitution over a date range.
- `existingpersonid` → deliverypersons (the person being replaced)
- `deliverypersonid` → deliverypersons (the cover person)

**`rounddeliverypersoncover`** — One-off cover for a specific date.
- `deliverypersonid` → deliverypersons

**`rounddeliverypersonoverrides`** — One-off override for a specific date.
- `deliverypersonid` → deliverypersons

**`roundpaymentdays`** — Per-day overrides within a round payment period.
- `deliverypersonid` → deliverypersons

### Actual deliveries (who did deliver)

**`rounddeliveries.deliverypersonid`** — Records who actually performed the delivery run. May differ from intended if cover was informal or the intended person didn't show.

### Payment records

**`deliverypersonpayments`** — Calculated payment records (pay slips) for a delivery person.
- `id` (PK), `deliverypersonid` → deliverypersons
- `start_date`/`end_date` — period covered
- `daily` — daily rate component
- `drops` — per-drop component
- `returns` — returns component
- `topup` — top-up amount
- `extra` — extra payments
- `total` — total payment
- `vat` — VAT amount
- `shopfilesystemid` — link to generated payslip file
- `vatsequentialnumber` — VAT invoice sequence number
- `created` (timestamp)

**`deliverypersonpaymentextra`** — Ad-hoc extra payments for a delivery person (bonuses, deductions, adjustments).
- `id` (PK), `deliverypersonid` → deliverypersons
- `start_date`/`end_date` — period the extra applies to
- `typeid` → lookup for extra payment type
- `reason`, `description`
- `value` — amount
- `perdrop` (tinyint) — whether the extra is per-drop or flat
- `shopid`, `roundid` — optional scope (shop-wide or round-specific)

### Collections

**`collectionbatch`** — Payment collection batches where a delivery person collects money from customers on a round.
- `collectionbatchid` (PK), `shopid`, `to_date`
- `roundid`, `deliverypersonid` → deliverypersons
- `total_owed_pence`, `total_credit_pence`, `total_collected_pence`
- `batchstatusid`, `collectionpercent`
- `banked`, `bankadj`, `wages`
- `email` — for sending collection summary

### Route optimisation

**`odlroutesettings`** — Route optimisation settings per delivery person/round/day combination.
- `odlroundsettings` (PK), `shopgroupid`, `shopid`, `shoplocationid`
- `roundid`, `deliverypersonid` → deliverypersons, `dayid`
- `start_lat`/`start_lon` — route start point GPS
- `end_lat`/`end_lon` — route end point GPS
- `start_time` — scheduled start time

### Training

**`trainingroundcontrols`** — Training round state tracking. Links the trainee to the training round.
- `deliverypersonid` → deliverypersons (the trainee)
- See `data-model-rounds.md` → "Training Rounds" for full details.

### Delivery app (indirect)
The delivery app tables (`deliverydrop`, `deliverydropitem`, `deliverydroplog`, `deliverydroppicture`) do not directly reference `deliverypersonid`. Instead, they link via `rounddeliveryid` → `rounddeliveries.deliverypersonid`. The `deliverypersons.del_app_userid` → `users` link connects the delivery person to their app login.

### Rounds (flags, not FK)
**`rounds.deliverypersoncollection`** — Boolean flag (tinyint) indicating whether the delivery person collects payments on this round. This is NOT a FK to deliverypersons.

## Common Query Patterns

```sql
-- Find a delivery person by name
SELECT id, shopid, firstname, familyname, active, disabled, stopped,
  contractortypeid, startdate
FROM deliverypersons
WHERE shopid = ? AND familyname LIKE '%name%';

-- Delivery person's current round assignments (via roundpayments)
SELECT rp.roundid, r.name AS round_name, rp.start_date, rp.end_date,
  rp.paybandid, rp.retainer
FROM roundpayments rp
JOIN rounds r ON r.id = rp.roundid
WHERE rp.deliverypersonid = ?
  AND rp.end_date >= CURDATE()
ORDER BY rp.start_date;

-- Full round assignment history for a delivery person
SELECT rp.roundid, r.name AS round_name, rp.start_date, rp.end_date,
  rp.paybandid, rp.retainer
FROM roundpayments rp
JOIN rounds r ON r.id = rp.roundid
WHERE rp.deliverypersonid = ?
ORDER BY rp.start_date;

-- Payment history for a delivery person
SELECT start_date, end_date, daily, drops, returns, topup, extra, total, vat
FROM deliverypersonpayments
WHERE deliverypersonid = ?
ORDER BY start_date DESC LIMIT 20;

-- Actual deliveries by a person over a period
SELECT rd.rounddate, r.name AS round_name, rd.cover,
  COUNT(rdp.id) AS items,
  SUM(CASE WHEN rdp.deliverystatusid = 1 THEN 1 ELSE 0 END) AS normal
FROM rounddeliveries rd
JOIN rounds r ON r.id = rd.roundid
LEFT JOIN rounddeliverypublications rdp ON rdp.rounddeliveriesid = rd.id
WHERE rd.deliverypersonid = ?
  AND rd.rounddate BETWEEN '2026-03-01' AND '2026-03-18'
GROUP BY rd.rounddate, r.name, rd.cover
ORDER BY rd.rounddate;

-- Cover work done by a delivery person
SELECT rdc.deliverydate, rdc.roundid, r.name AS round_name, rdc.cover
FROM rounddeliverypersoncover rdc
JOIN rounds r ON r.id = rdc.roundid
WHERE rdc.deliverypersonid = ?
ORDER BY rdc.deliverydate DESC LIMIT 20;

-- Collection batches for a delivery person
SELECT to_date, roundid, total_owed_pence, total_collected_pence,
  collectionpercent, batchstatusid
FROM collectionbatch
WHERE deliverypersonid = ?
ORDER BY to_date DESC LIMIT 10;

-- All delivery persons for a shop with their current type
SELECT dp.id, dp.firstname, dp.familyname, dp.active, dp.disabled, dp.stopped,
  ct.contractortypesdescription AS role, dp.startdate
FROM deliverypersons dp
LEFT JOIN contractortypes ct ON ct.contractortypeid = dp.contractortypeid
WHERE dp.shopid = ? AND dp.active = 1
ORDER BY dp.familyname;
```
