# PPR Data Model — Core Tables

## shops — Retail outlets / newsagents
- `id` (PK), `name`, `actualname`, `email`, `telephone`
- `addressid` → addresses, `regionid` → regions
- `shopstatusid`: 1=Active, 2=Suspended
- `has_agents` — whether shop uses delivery agents
- `delivery_app` — whether shop uses the delivery app
- 301 columns total — many are feature flags and settings

## customers — End consumers receiving deliveries
- `id` (PK, auto_increment), `shopid` → shops, `accountnbr`
- `familyname`, `firstname`, `title`, `companyname`
- `telephone`, `mobile`, `email`
- `addressid` → addresses
- `current_balance` — current account balance
- `statusid`: 1=Active, 2=Suspended, 3=Inactive, 4=Awaiting Activation
- `billingmethodid`, `paymentmethodid`, `chargebandid`
- `agentid` → agents (wholesale agent)
- `customer_start_date`, `customer_end_date`
- 129 columns total

## publications — Newspapers, magazines, and other publications
- `id` (PK, auto_increment), `title`, `ean_name` (barcode name)
- `typeid` → publicationtypes: 1=Dailies, 2=Sundays, 3=Regional & Local, 4=Weekly, 5=Monthly, 6=Others, 7=1-Shot
- `frequencyid` → frequencies: 1=Daily, 2=Weekly, 3=Other
- `morning` — morning or evening edition
- `is_subscription`, `firm_order`, `finished`
- 42 columns total

## publicationprices — Price records per publication per shop
- `id` (PK), `shopid`, `publicationid` → publications
- `price`, `barcodeid`, `ean_issue`, `cover_issue`
- `onshelf`/`offshelf` datetimes, `startdate`/`stopdate`
- `dayid` — day of week the price applies

## customerpublications — Which publications each customer receives
- `id` (PK), `customerid` → customers, `publicationid` → publications
- `dayid` — bitmask of delivery days
- `nbrofcopies`, `start`/`end` dates, `permanent`, `morning`
- `shopsave` — shop-save vs delivery
- `deliveryfrequencyid` — for alternating week deliveries

## Days Lookup
The `days` table defines day-of-week IDs used throughout the system:
- 0 = (none/all), 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday, 7 = Saturday

Many tables use `dayid` as a **bitmask** — e.g. in `customerpublications.dayid`, the value encodes which days a publication is delivered.

## deliverypersons — Delivery people
- `id` (PK), `shopid` → shops
- `familyname`, `firstname`, `mobile`, `telephone`, `email`
- `active`, `disabled`, `stopped`
- `addressid` → addresses, `del_app_userid` — delivery app user link
- `contractortypeid`, `startdate`, `paidupto`, `nextpaymentdate`

## deliverypersonpayments — Payment records
- `id` (PK), `deliverypersonid` → deliverypersons
- `start_date`, `end_date`
- `daily`, `drops`, `returns`, `topup`, `extra`, `total`, `vat`

## agents — Wholesale agents (NOT delivery people)
- `agentid` (PK), `shopid` → shops
- `name`, `actualname`, address fields

## customertransactions — All financial transactions
- `id` (PK), `customerid` → customers
- `date`, `delivery_date`, `value`, `balance`
- `typeid` → customertransactionstypes
- `paymentmethodid`, `adjustmenttypeid`
- `rounddeliverypubid` — links to the delivery that generated the charge

## addresses — Shared address table
- `id` (PK), `shopid`
- `address1`, `address2`, `address3`, `town`, `county`, `postcode`, `house`
- `lat`/`lon` — GPS coordinates
- `roadid` → roads

## postcodes / postcodeareas / postcodesectors — Postcode geography

## Key Relationships
- shops ← customers (shopid) ← customerpublications (customerid) → publications
- shops ← rounds (shopid) ← roundmembers (roundid) → addresses
- rounds ← rounddeliveries (roundid) ← rounddeliverypublications → customers, publications
- shops ← deliverypersons (shopid) → rounds (deliverypersonid)
- customers → addresses (addressid)
- customertransactions → customers, rounddeliverypublications

## Common Query Patterns

```sql
-- Find a shop by name
SELECT id, name, email FROM shops WHERE name LIKE '%keyword%';

-- Find customers for a shop
SELECT id, accountnbr, firstname, familyname, current_balance
FROM customers WHERE shopid = ? AND statusid = 1;

-- Customer's publications
SELECT cp.*, p.title FROM customerpublications cp
JOIN publications p ON p.id = cp.publicationid
WHERE cp.customerid = ?;

-- Customer balance and recent transactions
SELECT ct.date, ct.value, ct.balance, ctt.description
FROM customertransactions ct
JOIN customertransactionstypes ctt ON ctt.id = ct.typeid
WHERE ct.customerid = ? ORDER BY ct.date DESC LIMIT 20;

-- Delivery person payments
SELECT * FROM deliverypersonpayments
WHERE deliverypersonid = ? ORDER BY start_date DESC;
```
