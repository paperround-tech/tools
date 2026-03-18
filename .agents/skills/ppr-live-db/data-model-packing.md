# PPR Packing Domain — Data Model

## Overview

The packing domain manages the physical packing and dispatch of newspapers/magazines from distribution centres (pack sites) to shops. It covers:
- The hierarchy of pack sites (hubs and their child sites)
- Bundle configuration per publication per day
- Title set groupings (publications packed together)
- Cage assignments (physical trolleys/cages per shop)
- Supplier node priorities per pack site

There are **14 packing tables** in total. In live data, configuration is almost entirely at the hub/pack-site level — the "global default" tables (`packingpublicationdays`, `packingtitlesetpublications`) are largely unused (32 and 0 rows respectively); the hub-level override tables hold the real data (2225 and 2013 rows).

---

## Key Lookup: days

Day IDs follow MySQL `DAYOFWEEK()` convention:

| id | description | shortdescription |
|----|-------------|-----------------|
| 0  | (any/all)   |                 |
| 1  | Sunday      | Sun             |
| 2  | Monday      | Mon             |
| 3  | Tuesday     | Tue             |
| 4  | Wednesday   | Wed             |
| 5  | Thursday    | Thu             |
| 6  | Friday      | Fri             |
| 7  | Saturday    | Sat             |

---

## Key Lookup: packingsplitinserts

Controls whether a publication's copies are split into a main bundle and an insert bundle.

| splitinserts | isinsert | suffix    | Meaning                             |
|-------------|----------|-----------|-------------------------------------|
| 0           | -1       | (empty)   | No split — single bundle stream     |
| 1           | 0        | " (Main)" | Split enabled — main paper stream   |
| 1           | 1        | " (Insert)"| Split enabled — insert stream       |

`isinsert = -1` in title set publications means the publication is excluded/not applicable for that stream.

---

## Tables

### packingpacksites — Pack Sites

Physical distribution centres, stored as a nested set hierarchy (lft/rgt/depth).

| Field            | Type         | Notes                                              |
|------------------|--------------|----------------------------------------------------|
| packingpacksiteid | int PK      | Auto increment                                     |
| shopgroupid      | int          | FK → shopgroups. Only 3 shopgroups use packing (9, 21, 46) |
| description      | varchar(30)  | E.g. "Oldham - OLD (Hub)", "Stoke - OLD"           |
| shopid           | int          | FK → shops — the shop this site is physically at   |
| lft, rgt, depth  | int          | Nested set: depth=0 = hub, depth=1 = child site    |
| uselocations     | tinyint      | Whether shop locations are used for cage assignment |
| labelwidth/height/top/bottom/left/right | int | Per-site label dimensions (mm), overrides packingbundlelabels |

**Hierarchy**: Hubs are at depth=0. Child pack sites are at depth=1 beneath a hub. In live data, shopgroup 9 has 44 sites across 8 hubs.

**Hub identification**: A pack site is a hub if `depth = 0`. For a child site, its hub is the ancestor with `lft <= child.lft AND rgt >= child.rgt AND depth = 0`.

**Common query — all hubs:**
```sql
SELECT packingpacksiteid, description, shopid
FROM packingpacksites
WHERE shopgroupid = 9 AND depth = 0
ORDER BY lft;
```

**Common query — children of a hub:**
```sql
SELECT child.packingpacksiteid, child.description
FROM packingpacksites hub
JOIN packingpacksites child ON child.shopgroupid = hub.shopgroupid
  AND child.lft > hub.lft AND child.rgt < hub.rgt
WHERE hub.packingpacksiteid = 29;
```

---

### packingpublicationdays — Global Bundle Defaults

Default bundle/title-set configuration per publication per day, scoped to a shopgroup. **Rarely used in live data (32 rows)** — most config lives in `packingpacksitepublicationdays`.

| Field              | Type     | Notes                                                |
|--------------------|----------|------------------------------------------------------|
| packingpublicationdayid | int PK |                                                    |
| shopgroupid        | int      |                                                      |
| publicationid      | int      | FK → publications                                    |
| dayid              | int      | Day of week (0=all, 1=Sun…7=Sat)                    |
| splitinserts       | tinyint  | 0 = no split, 1 = split into main + insert           |
| bundleqty          | int      | Copies per bundle (main paper or unsplit)            |
| insertbundleqty    | int      | Copies per bundle (insert stream, only if splitinserts=1) |
| titlesets          | tinyint  | 1 = this publication uses title sets on this day     |

---

### packingpacksitepublicationdays — Hub-Level Bundle Config

Hub-specific overrides of `packingpublicationdays`. Same fields but scoped to a `packingpacksiteid`. **This is the primary config table in live data (2225 rows).**

All fields identical to `packingpublicationdays` except:

| Field              | Notes                                         |
|--------------------|-----------------------------------------------|
| packingpacksiteid  | FK → packingpacksites (must be a hub, depth=0)|

Resolution order: `IFNULL(pppd.bundleqty, ppd.bundleqty)` — hub config wins over global default.

**Common query — bundle config for a hub:**
```sql
SELECT p.title, pppd.dayid, pppd.splitinserts,
       pppd.bundleqty, pppd.insertbundleqty, pppd.titlesets
FROM packingpacksitepublicationdays pppd
JOIN publications p ON p.id = pppd.publicationid
WHERE pppd.packingpacksiteid = 29
ORDER BY p.title, pppd.dayid;
```

---

### packingpublicationoverrides — Hub Publication Routing

Declares that a publication belonging to a hub should actually be handled by a specific child pack site instead. Used to route local/regional titles to the appropriate sub-depot.

| Field                        | Notes                                              |
|------------------------------|----------------------------------------------------|
| packingpublicationoverrideid | int PK                                             |
| hubpacksiteid                | FK → packingpacksites (the hub)                    |
| publicationid                | FK → publications                                  |
| packingpacksiteid            | FK → packingpacksites (the child site it routes to)|

Example: Oldham hub routes "Alsager Chronicle" to Stoke-OLD.

**Common query — all overrides for a hub:**
```sql
SELECT p.title, child.description overridden_to
FROM packingpublicationoverrides ppo
JOIN publications p ON p.id = ppo.publicationid
JOIN packingpacksites child ON child.packingpacksiteid = ppo.packingpacksiteid
WHERE ppo.hubpacksiteid = 29
ORDER BY child.description, p.title;
```

---

### packingtitlesets — Title Sets

Named groupings of publications that are packed together (e.g. "Daily Mail + The I Mon-Fri"). **Empty packingtitlesetpublications means all title set membership is via packingpacksitetitlesetpublications in live.**

| Field              | Type        | Notes                                                    |
|--------------------|-------------|----------------------------------------------------------|
| packingtitlesetid  | int PK      |                                                          |
| shopgroupid        | int         |                                                          |
| packingpacksiteid  | int NULL    | NULL = global; set = hub-specific title set              |
| description        | varchar(50) | Name, e.g. "Daily Mail - The I Mon-Fri"                  |
| minimumsize        | int         | Min total copies across all pubs in set to form a bundle. Default 10. If below, copies go to Spares instead |

---

### packingtitlesetpublications — Global Title Set Membership

Maps publications to title sets (global, not hub-specific). **0 rows in live — not used in practice.**

| Field                         | Notes                                   |
|-------------------------------|-----------------------------------------|
| packingtitlesetpublicationid  | int PK                                  |
| packingtitlesetid             | FK → packingtitlesets                   |
| dayid                         | Day this membership applies             |
| publicationid                 | FK → publications                       |
| isinsert                      | -1=excluded, 0=main paper, 1=insert     |

---

### packingpacksitetitlesetpublications — Hub Title Set Membership

Hub-specific title set membership. **This is the real title set config in live data (2013 rows).** Can override or augment the global defaults.

| Field                                  | Notes                                                      |
|----------------------------------------|------------------------------------------------------------|
| packingpacksitetitlesetpublicationid   | int PK                                                     |
| packingtitlesetid                      | int NULL — FK → packingtitlesets. NULL = removed from set  |
| packingpacksiteid                      | FK → packingpacksites (hub)                                |
| dayid                                  | Day this membership applies                                |
| publicationid                          | FK → publications                                          |
| isinsert                               | -1=excluded/N/A, 0=main paper, 1=insert                   |
| defaulttitlesetid                      | int NULL — the global default title set being overridden   |

`defaulttitlesetid` is used to track what the hub is overriding, enabling revert/merge logic when pack site hierarchy changes.

**Common query — title set contents for a hub:**
```sql
SELECT pts.description titleset, p.title publication,
       pptsp.dayid, pptsp.isinsert
FROM packingpacksitetitlesetpublications pptsp
JOIN packingtitlesets pts ON pts.packingtitlesetid = pptsp.packingtitlesetid
JOIN publications p ON p.id = pptsp.publicationid
WHERE pptsp.packingpacksiteid = 29
ORDER BY pts.description, pptsp.dayid, p.title;
```

---

### packingcages — Cages

Physical trolleys/roll-cages at a pack site, identified by a letter code.

| Field             | Notes                                                |
|-------------------|------------------------------------------------------|
| packingcageid     | int PK                                               |
| packingpacksiteid | FK → packingpacksites                                |
| cageletter        | varchar(3) — e.g. "A1", "B2", "ST"                  |

Cage letters can be multi-character (e.g. "A1", "ST"). Oldham hub has 50+ cages.

---

### packingcageitems — Cage → Shop Assignment

Maps each cage to one or more shops (and optionally a specific shop location).

| Field             | Notes                                                    |
|-------------------|----------------------------------------------------------|
| packingcageitemid | int PK                                                   |
| packingcageid     | FK → packingcages                                        |
| shopid            | FK → shops                                               |
| shoplocationid    | int NULL — FK → shoplocations (if pack site uses locations)|

---

### packingbundlelabels — Default Label Dimensions

Per-shopgroup default label dimensions used for printing bundle sheets (all values in mm).

| Field        | Notes                         |
|--------------|-------------------------------|
| shopgroupid  | PK — FK → shopgroups          |
| labelwidth   | Width of label area           |
| labelheight  | Height of label area          |
| labeltop     | Top margin                    |
| labelbottom  | Bottom margin                 |
| labelleft    | Left margin                   |
| labelright   | Right margin                  |

Individual `packingpacksites` rows can override these with site-specific dimensions.

---

### packingsuppliers — Supplier Priority per Pack Site

Ordered list of supplier nodes for a pack site, defining which supplier delivers which publications and in what priority order.

| Field              | Notes                                                     |
|--------------------|-----------------------------------------------------------|
| packingsupplierid  | int PK                                                    |
| packingpacksiteid  | FK → packingpacksites                                     |
| suppliernodeid     | FK → suppliernodes                                        |
| sortorder          | 1 = highest priority                                      |
| defaultnode        | 1 = this is the default/primary delivery node (usually the main wholesaler e.g. Smiths News) |
| startdate/enddate  | Effective date range (enddate 2100-01-01 = current)       |

Active suppliers: `WHERE enddate > NOW()` or `enddate = '2100-01-01'`.

---

### packingsupplierpublications — Supplier Publication Rules (non-day-specific)

Maps a publication to a supplier node for a pack site, without day restriction.

| Field                          | Notes                             |
|--------------------------------|-----------------------------------|
| packingsupplierpublicationid   | int PK                            |
| packingpacksiteid              | FK → packingpacksites             |
| publicationid                  | FK → publications                 |
| supplierruleid                 | FK → supplierrules                |
| extraid                        | int NULL — for multi-supply rules |
| quantity                       | int NULL                          |
| priority                       | int NULL                          |
| noreturns                      | tinyint — 1 = no returns for this publication from this supplier |
| startdate/enddate              | Effective date range              |

---

### packingsupplierpublicationdays — Supplier Publication Rules (day-specific)

Same as `packingsupplierpublications` but restricted to a specific day of week. Day-specific rules take precedence.

| Field   | Notes in addition to above                    |
|---------|-----------------------------------------------|
| dayid   | Day of week this rule applies to              |

---

## Report Sheet Types

The packing report (`packing.py`) produces these sheet types, generated in pipeline order:

1. **Bundles** — One label sheet per bundle of copies. `bundleqty` copies = 1 bundle. Labelled with cage letter, publication, shop, round number.
2. **Title Sets** — Publications packed together as a group. If a round's combined quantity for all pubs in the set meets `minimumsize`, a title set sheet is produced and those copies are zeroed. Otherwise they fall to Spares.
3. **Spares** — Remaining copies after bundles and title sets are extracted. Printed as a checklist (checkbox + quantity × title) per round. Interleaved with customer return sheets in PDF output.
4. **Totals** — Total delivery quantities per publication across all rounds.
5. **Cages** — Bundles and title sets grouped by cage letter, then shop, then round. Used for cage loading.

---

## Common Query Patterns

**All title sets and their publications for a hub on a given day:**
```sql
SELECT pts.description titleset, p.title, pptsp.isinsert
FROM packingpacksitetitlesetpublications pptsp
JOIN packingtitlesets pts ON pts.packingtitlesetid = pptsp.packingtitlesetid
JOIN publications p ON p.id = pptsp.publicationid
WHERE pptsp.packingpacksiteid = :hubid
  AND pptsp.dayid = :dayid
ORDER BY pts.description, pptsp.isinsert, p.title;
```

**Bundle config for all publications at a hub on a given day (with fallback to global):**
```sql
SELECT p.title,
       IFNULL(pppd.bundleqty, ppd.bundleqty) bundleqty,
       IFNULL(pppd.insertbundleqty, ppd.insertbundleqty) insertbundleqty,
       IFNULL(pppd.splitinserts, ppd.splitinserts) splitinserts,
       IFNULL(pppd.titlesets, ppd.titlesets) titlesets
FROM publications p
LEFT JOIN packingpublicationdays ppd
  ON ppd.publicationid = p.id AND ppd.shopgroupid = :shopgroupid AND ppd.dayid = :dayid
LEFT JOIN packingpacksitepublicationdays pppd
  ON pppd.publicationid = p.id AND pppd.packingpacksiteid = :hubid AND pppd.dayid = :dayid
WHERE (ppd.packingpublicationdayid IS NOT NULL OR pppd.packingpacksitepublicationdayid IS NOT NULL);
```

**Shops assigned to a cage:**
```sql
SELECT pc.cageletter, s.shortname shop, pci.shoplocationid
FROM packingcages pc
JOIN packingcageitems pci ON pci.packingcageid = pc.packingcageid
JOIN shops s ON s.id = pci.shopid
WHERE pc.packingpacksiteid = :packsite_id
ORDER BY pc.cageletter, s.shortname;
```
