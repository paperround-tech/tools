# PPR Data Model — Rounds Domain

## Rounds — Structure & Configuration

**rounds** — Delivery rounds belonging to a shop
- `id` (PK), `shopid` → shops, `name`, `shortname`
- `deliverypersonid` → deliverypersons (default assigned delivery person)
- `roundtypeid` → roundtypes, `setid` → roundsets
- `rounddaytypeid` → rounddaytypes (which days this round operates)
- `paybandid` → paybands (pay rate band)
- `disabled`, `no_delete`, `no_edit`
- `roundparentid` — for sub-rounds (training rounds link here)
- `notforautoplacement` — exclude from auto customer placement
- 36 columns total

**roundtypes** — Standard round type definitions
- `id` (PK), `description`, `days` (bitmask), `morning` (bool)
- System types (shopid IS NULL): 1=Morning 6 Days, 2=Sunday, 3=Evening 5 Days, 4=Morning 5 Days, 5=Morning 7 Days, 6=Saturday, 7=Evening 6 Days, 8=Shop Save, 1065=Saturday and Sunday, 1565=Saturday Evening, 3346=Evening 7 Days, 4587=Collection Round
- Shops can also create custom roundtypes (with shopid set)

**roundsets** — Groups of rounds (e.g. "Morning Set", "Evening Set")
- `id` (PK), `shopid`, `description`, `setsortorder`

**rounddaytypes** — Named day patterns for rounds
- `rounddaytypeid` (PK), `shopid`, `description`, `editable`
- Linked to specific days via `rounddaytypedays` (rounddaytypeid → dayid)

**roundpostcodes** — Postcode assignments to rounds
- `roundpostcodeid` (PK), `roundid`, `postcodeid`, `shopgroupid`

## Rounds — Membership & Ordering

**roundmembers** — Customers on a round (the drop order)
- `id` (PK), `roundid` → rounds, `addressid` → addresses
- `sortorder` — position in the round (what the delivery person follows)
- `sortorder_base` — base sort order, `sortorder_nighlty` — nightly optimised order
- `isactive` — enum('0','1')

## Rounds — Delivery Person Assignment

There are multiple layers that determine who **should** deliver a round on a given date (the "intended" person), and a separate record of who **actually** did it. Understanding both is essential for investigating discrepancies.

### Intended delivery person (who should deliver)

Resolved in priority order — higher layers override lower ones:

**Layer 1: `roundpayments`** — The contracted/paid delivery person for a date range. This is the **primary source of truth** for who is intended to deliver a round on any given date. Each row covers a `start_date`/`end_date` range. A `NULL` `deliverypersonid` means the round is VACANT for that period. Consecutive rows form a complete timeline of round ownership. This table also drives payroll — it links the person to a `paybandid` and `retainer` amount.
- `id` (PK), `roundid`, `deliverypersonid`, `paybandid`
- `paymentfrequencyid`, `retainer`, `start_date`/`end_date`
- **Key insight:** `rounds.deliverypersonid` is a live "NOW" view — it only reflects the current delivery person, not historical assignments. It has no date context. For any historical or date-specific investigation, always use `roundpayments` which provides the full timeline with date ranges.

**Layer 2: `rounddeliverypersondays`** — Per-day-of-week overrides (e.g. a different person does Sundays)
- `id` (PK), `roundid`, `deliverypersonid`, `dayid`

**Layer 3: `rounddeliverypersonchanges`** — Temporary cover/substitution over a date range
- `id` (PK), `roundid`, `existingpersonid`, `deliverypersonid`
- `startdate`/`enddate`, `day1`..`day7` (per-day flags)

**Layer 4: `rounddeliverypersoncover`** — One-off cover assignments for specific dates
- `rounddeliverypersoncoverid` (PK), `roundid`, `deliverydate`, `deliverypersonid`, `cover` (multiplier)

**Layer 5: `rounddeliverypersonoverrides`** — One-off overrides for specific dates
- `id` (PK), `roundid`, `deliverydate`, `deliverypersonid`, `cover`

### Actual delivery person (who did deliver)

**`rounddeliveries.deliverypersonid`** — Records who actually performed the delivery run on a given date. This may differ from the intended person if cover was arranged informally or the intended person didn't show up.

### Investigating intended vs actual discrepancies

To compare intended vs actual for a round over a period:
1. Query `roundpayments` for the date range to get the contracted person per day
2. Check `rounddeliverypersondays`, `rounddeliverypersonchanges`, `rounddeliverypersoncover`, and `rounddeliverypersonoverrides` for any overrides
3. Query `rounddeliveries` for the actual person per day
4. Compare — mismatches indicate informal cover or data gaps

**`roundpaymentdays`** — Per-day overrides within a round payment period
- `id` (PK), `roundpaymentid`, `dayid`, `paybandid`, `deliverypersonid`, `retainer`

## Rounds — Payment Configuration

**paybands** — Named pay rate bands per shop
- `id` (PK), `shopid`, `paybandname`, `bonus`, `disabled`

**paybanddayvalue** — Pay rates per payband per day
- `id` (PK), `paybandid`, `dayid`
- `rate` (per-drop rate), `eveningrate`, `dayrate` (daily flat rate), `eveningdayrate`
- `start_date`/`end_date`, `disabled`

**paybandpublications** — Link specific publications to a payband
- `id` (PK), `paybandid`, `publicationid`

**roundpaymentfrequencies** — How often delivery people are paid
- 4=Weekly (1 week), 5=Four Weekly (4 weeks), 6=Monthly (1 month)

**roundpaymentextra** — Ad-hoc extra payments on a round
- `id` (PK), `roundid`, `start_date`/`end_date`
- `typeid` → roundpaymentextratypes, `reason`, `description`, `value`
- `perdrop` — whether it's a per-drop or flat extra

## Rounds — Actual Deliveries

**deliveryhistory** — One record per shop per delivery day (the "day" container)
- `id` (PK), `shopid`, `activeday` (date), `closed` (bool), `archived`
- `closed_date` — when the day was finalised

**rounddeliveries** — Actual delivery runs (one per round per delivery day)
- `id` (PK), `roundid` → rounds, `deliverypersonid` → deliverypersons
- `deliveryhistoryid` → deliveryhistory
- `rounddate` — the date of the delivery
- `cover` — whether this was a cover run

**rounddeliverypublications** — Individual publication deliveries to customers
- `id` (PK), `rounddeliveriesid` → rounddeliveries
- `roundid`, `publicationid`, `customerid`
- `publicationpricesid` → publicationprices
- `nbrofcopies`, `nbrdeliveries`, `nbrextracopies`
- `deliverystatusid`: 1=Normal, 2=Cancel, 3=Keep in Shop, 4=Deliver when Holiday Over, 5=Per Publication Basis, 6=Did Not Arrive, 7=Part Delivery, 8=Damaged, 9=Damaged Replaced, 10=Redelivery
- `shopsave`, `holidaycancel`, `oneoff`, `added`, `altered`
- `billprinted`, `changed`

**rounddeliverypublicationsext** — Extended delivery info (redirects, returns)
- `rounddeliverypublicationid` (PK) → rounddeliverypublications
- `addressid` — alternate delivery address
- `origroundid`/`origcustomerid` — original round/customer (for redirects)
- `newroundid`/`newcustomerid` — destination for moved deliveries
- `returndeferred`, `issuedate`, `returndate`

**rounddeliverystock** — Stock quantities per publication per delivery run
- `rounddeliverystockid` (PK), `rounddeliveryid`, `publicationid`, `qty`

**rounddeliverysplits** — Split markers within a delivery run
- `rounddeliverysplitid` (PK), `rounddeliveriesid`, `roundid`, `split`, `name`

## Rounds — Delivery App

**deliverydrop** — Delivery app drop tracking (GPS and completion)
- Composite PK: `rounddeliveryid`, `customerid`
- `deliverydropstatusid` → deliverydropstatus (`deliverydropstatusid` PK, `deliverydropstatusdescription`)
- `completed` datetime, `lat`/`lon` GPS
- `deliverydropreturnsstatusid`
- `dropnote` — free-text note from delivery person

**deliverydropitem** — Individual items within a drop
- `rounddeliverypublicationid` (PK)
- `deliverydropitemstatusid`, `deliverydropstatusid`, `completed`

**deliverypool** — Pre-computed delivery pool (what needs delivering)
- Composite PK: `deliverydate`, `source_shopid`, `source_customerid`, `source_publicationid`
- `delivery_shopid`, `delivery_customerid`, `delivery_publicationid`
- `nbrofcopies`, `deliverystatusid`, `shopsave`, `morning`, `holidaycancel`

## Rounds — Training Rounds

Training rounds gradually hand over a round to a new delivery person. A training round is a **child round** of a parent round, linked via `rounds.roundparentid`. The trainee takes over a portion of the parent's drops, starting small and increasing over time.

**How training rounds work:**
1. A training round is created as a child of a parent (regular) round
2. The trainee is assigned to the training round (`rounds.deliverypersonid`)
3. The system allocates a set number of drops (`allowance`) from the parent round
4. Drops are taken from either the **start** or **end** of the parent round (`deliver_from_start_of_parent`)
5. After each delivery day, the allowance is increased by a configurable `increment` (from `trainingroundrules`)
6. When the training round has taken all drops from the parent, it has `converged`
7. The training is then completed with a status: Success, Reassignment, or Failure

**On completion:**
- **Success (1):** Trainee replaces existing delivery person on parent round. Trainee's `contractortypeid` changes from 6 (Training) to 2 (Delivery). Payment records split at today's date.
- **Reassignment (2):** Training ends, trainee stays available. If overflow training, the overflow flag is cleared and allowance increases.
- **Failure (3):** Trainee is disabled and stopped (`disabled=1, stopped=1`).
- **Redundant (4):** Auto-set on other training rounds for the same trainee when one succeeds.

**Key characteristics in the `rounds` table:**
- `roundparentid` → the parent round ID
- `contractortypeid` = 6 (Training)
- `no_delete` = 1, `no_edit` = 1
- Round name pattern: `Training Round (<parent_name> - START/END - <person_name>)`

**trainingroundcontrols** — State tracking for each active training round
- `trainingroundcontrolid` (PK), `trainingroundid` → rounds
- `deliverypersonid` — the trainee
- `deliver_from_start_of_parent` — 1=take drops from start, 0=take from end
- `secondary_priority` — 0=primary, 1=secondary. Affects round numbering (parent.1 or parent.2)
- `overflow` — whether this is an overflow round (allowance starts at half)
- `converged` — whether training round has taken all parent drops
- `start_date`, `days_delivered`, `last_date_delivered`, `last_delivered_qty`
- `allowance` — current number of drops the trainee handles
- `previous_allowance`, `minimum_allowance`
- `completed_date`, `completedstatusid` — NULL while active; set on completion

**trainingroundrules** — Configuration for how quickly training progresses
- `trainingcontrolruleid` (PK), `shopgroupid` or `shopid`
- `increment` — how many additional drops per day
- `default_start_quantity` — initial number of drops (default 30)
- `minimum_days_for_completion` — minimum days before training can complete (default 5)

**trainingroundcompletedstatus** — Completion outcome lookup
- 1=Success, 2=Reassignment, 3=Failure

**Priority switching:** A parent round can have two training rounds (from start and from end). Their priorities can be switched so the secondary becomes primary and vice versa. Used when training is converging and you want to rebalance.

## Rounds — Split Rounds

Split rounds divide a single round's delivery run into named sections. Unlike training rounds, they do **not** create separate `rounds` records. They use the `roundsplits` table to define named break points within a round.

**How split rounds work:**
1. Named split points are defined in `roundsplits` for a round, each with a `sortorder`
2. When generating round sheets, customers are grouped by these split points based on their `roundmembers.sortorder`
3. Each split can optionally start a new page (`newpage` flag)
4. In the delivery view, splits appear as `rounddeliverysplits` entries linked to `rounddeliveries`

**roundsplits** — Split point definitions within a round
- `roundsplitid` (PK), `roundid` → rounds
- `sortorder` — position where this split occurs
- `splitname` — name of the split section (e.g. "Section A", "High Street")
- `newpage` — whether to start a new page on round sheets

**In queries:** Split rounds are identified by `rounddeliverysplits.roundid IS NOT NULL`. The round listing SQL uses:
- `splitsonly` filter: shows only rounds that have splits
- `includesplits` filter: includes split rounds alongside regular rounds
- Default: excludes splits (shows parent rounds only)

The round number for a split round displays as the parent round number plus the split character (e.g. "5A", "5B").

## Rounds — Charges

**chargebands** — Delivery charge bands per shop
- `id` (PK), `shopid`, `band` (2-char code), `description`
- `rate`, `baserate`, `chargebandfrequencyid`, `predrop`, `active`

**chargebanddayvalue** — Per-day rates within a chargeband
- `id` (PK), `chargebandid`, `dayid`, `rate`, `eveningrate`

**chargebandfrequency** — How charges are calculated
- 1=Daily, 2=Weekly, 3=Calendar Month, 4=Weekly (Daily Variable), 5=Per Drop, 6=Per Drop (Daily), 7=Per Drop (calendar monthly), 8=Number Days

## Rounds — Delivery Frequency

**deliveryfrequency** — Alternating delivery patterns
- 1=Every Week, 2=Every 2 Weeks, 3=Every 3 Weeks, 4=Every 4 Weeks
- Used by `customerpublications.deliveryfrequencyid`

## Contractor Types

The `contractortypes` table defines the role of a delivery person or round:
- 1=Other, 2=Delivery, 3=Delivery (minor), 4=Trunking, 5=Packing, 6=Training, 7=Management

Training rounds always have `contractortypeid` = 6. Regular delivery rounds use 2.

## Common Round Query Patterns

```sql
-- Delivery history for a round on a date
SELECT rd.id, rd.rounddate, rdp.customerid, p.title, rdp.nbrofcopies, rdp.deliverystatusid
FROM rounddeliveries rd
JOIN rounddeliverypublications rdp ON rdp.rounddeliveriesid = rd.id
JOIN publications p ON p.id = rdp.publicationid
WHERE rd.roundid = ? AND rd.rounddate = '2026-03-16';

-- Delivery app drops for a round on a date
SELECT dd.customerid, c.firstname, c.familyname, a.address1, a.postcode,
  dds.deliverydropstatusdescription as drop_status, dd.completed, dd.lat, dd.lon, dd.dropnote
FROM deliverydrop dd
JOIN customers c ON c.id = dd.customerid
JOIN addresses a ON a.id = c.addressid
LEFT JOIN deliverydropstatus dds ON dds.deliverydropstatusid = dd.deliverydropstatusid
WHERE dd.rounddeliveryid = ?
ORDER BY dd.completed;

-- Training round status
SELECT tc.*, r.name as round_name, rp.name as parent_name,
  dp.firstname, dp.familyname
FROM trainingroundcontrols tc
JOIN rounds r ON r.id = tc.trainingroundid
JOIN rounds rp ON rp.id = r.roundparentid
JOIN deliverypersons dp ON dp.id = tc.deliverypersonid
WHERE tc.completedstatusid IS NULL;
```
