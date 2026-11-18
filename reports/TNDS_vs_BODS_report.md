# TNDS vs BODS (TransXChange and GTFS): where the differences come from, and how to reconcile them

*Prepared for the SCRAPE / Publictransportanalysis work, 14 November 2026.*

This report explains why the Traveline National Dataset (TNDS), the Bus Open Data Service (BODS) TransXChange (TXC) archive and the BODS GTFS feed disagree on route coverage, timetable start and end dates, duplicated services and missing services. It ends with concrete rules for code that reconciles the three sources.

The section on the BODS GTFS conversion is based on reading DfT's open-source converter itself (`department-for-transport-BODS/bods-integrated-data`, `main` branch as of 14 Nov 2026), not on secondary descriptions. File and line references point to that repository. Source notes are at the end; anything I could not verify is marked **(unverified)** or **(inference)**.

---

## 0. Summary

1. **Different people supply the data.** TNDS is built by the Traveline regions, Traveline Scotland and Traveline Wales from their own regional databases (originally keyed by local authority staff and Traveline data teams). Some big operators supply their files to Traveline directly, and from July 2026 First Bus files are being sourced from BODS. BODS is self-published by operators (or agents acting for them) under a legal duty that covers **registered local services in England outside Greater London** only. [S1, S2, S6]
2. **Scope differs.** BODS legally excludes Section 19/22 permit services, community buses, unregistered or voluntarily registered closed school services, tours and coach services. Scotland, Wales and London fall outside the duty and are only present when someone publishes voluntarily. TNDS covers GB bus, tram, light rail and ferry. It lost its coach dataset (NCSD) in May 2025. [S1, S2, S6]
3. **Versioning differs.** BODS keeps operators' own revision chains. Several files for one service, with overlapping `OperatingPeriod`s and inconsistent `RevisionNumber`s, were common until the December 2025 PTI Versioning Application Note v2 required one file per service. TNDS is a rebuilt export from a database, with one view of each service per region. TNDS also duplicates cross-boundary services across regional zips, and its look-ahead horizon varies by region. [S1, S3, S4, S5]
4. **BODS GTFS is not a pure conversion of BODS TXC.** The converter:
   - ingests the BODS bulk archive, the BODS coach archive and TNDS;
   - uses TNDS **in full only for London, Scotland and Wales**, and elsewhere only for coach, ferry, metro, tram and underground modes;
   - drops a TNDS route if a BODS route with the same `NOC + LineName` already exists;
   - expands calendars only from max(today, StartDate) to **9 months ahead**;
   - drops expired services;
   - builds trip IDs from a SHA-1 hash of the VehicleJourney plus Service;
   - removes cross-file duplicates using `DISTINCT ON (route, service_id, ticket machine journey code, direction, origin, destination, departure time)` and keeps the highest `RevisionNumber`.

   Overlapping revisions with **different** calendars both survive, and this is a prime source of duplicate trips in BODS GTFS. [code, §4]
5. **For reconciliation:** do not match on `ServiceCode` or file identity across sources. Match at the **trip × service-date** level, on NOC (normalised), line name, ordered NaPTAN stop sequence and first-stop departure time. Resolve versions *within* a source before comparing *across* sources, and always compare over an explicit, shared date window. §5 gives the full rules.

---

## 1. Who contributes data, and how

### 1.1 TNDS (Traveline National Dataset)

| Aspect | Detail |
|---|---|
| Publisher | Traveline Information Ltd (TIL), on behalf of the Traveline partnership [S1, S7] |
| Contributors | The English Traveline regions, Traveline Scotland and Traveline Wales: "data sourced from the English Traveline regions, Traveline Scotland, and Traveline Wales" [S1] |
| Direct operator feeds | Nottingham City Transport; Stagecoach (EA, EM, SE, SW, Cumbria); First (EA, EM, SE, SW, Y, W pending); Reading Buses / Newbury & District since Oct 2020. **From July 2026 First Bus data is migrating to being sourced from BODS** [S6] |
| Modes | Bus, light rail, tram and ferry. **No national rail; coach (NCSD) removed from May 2025**, with coach now on BODS [S1, S6] |
| Format | Each regional supply is imported into a database and exported as TXC 2.1 and TXC 2.5. TNDS "conforms to the BODS TXC profile 'UK PTI Profile v 1.1.A' from July 2025" and includes Tracks where publishers provide them [S1, S6] |
| Packaging | One zip per Traveline region (EA, EM, L, NE, NW, S, SE, SW, W, WM, Y; folder names as seen in the converter code, e.g. `S/S_SC_STWS_X79_2_A.xml`) plus a service report CSV, on FTP or CloudFront |
| Refresh | Built Monday to Thursday overnight; regions supply weekly; ad hoc builds are possible [S1, S6] |
| Licence | OGL [S7] |

**How the data gets in.** Historically each Traveline region kept its timetable database (typically in a commercial scheduling or journey-planner tool) and fed it from:

- registrations and operator timetables, keyed by local authority public transport teams or regional data managers;
- operators' own exports;
- more recently, BODS files re-imported and checked.

Each region then exports its whole database. The consequences:

- **The ServiceCode and file name schemes are regional, not OTC.** Do not assume a TNDS `ServiceCode` equals the OTC registration (`PB0000xxx:yyy`) used in BODS.
- **Data is normalised and re-serialised by a database export.** VehicleJourneyCodes, JourneyPattern IDs, `CreationDateTime`/`RevisionNumber` and private codes generally will *not* match the operator's BODS file, even when the timetable is identical.
- **Coverage includes things BODS legally doesn't need**: tendered services that aren't registered, some school services, community transport, Scotland, Wales, London, ferries and trams. That depends on what each region keys.

**TNDS known issues, stated by Traveline** [S6]:

- "Duplication: a service may be in the data more than once because it crosses a regional boundary."
- "A single line (eg bus route number) can have multiple files."
- "Time Horizon for validity of journeys varies between the regions."
- "Data may contain stop points that have not been added to NaPTAN yet."
- "Short working runs will appear to be available for public use for the whole journey unless the data user detects the dead run information."
- Cross-boundary services "may be provided by the neighbouring region", so a region's zip is not a complete picture of its area.
- Region moves: Suffolk returned to EA and Oxfordshire/Bedfordshire to SE (Apr 2024); Bristol Stagecoach is in `W.zip` from Jan 2026; the Isle of Man was temporarily removed in Jul 2025.

### 1.2 BODS (Bus Open Data Service)

**Legal basis.** Bus Services Act 2017 (s141A Transport Act 2000) and the **Public Service Vehicles (Open Data) (England) Regulations 2020, SI 2020/749** [S2].

| Aspect | Detail |
|---|---|
| Who must publish | Operators of *registered relevant local services* (reg 3(1)(a)); applicants for registration, variation or cancellation; franchising authorities for franchised services (reg 3(1)(a)(iii), reg 2(3)) [S2] |
| Geography | **England outside Greater London** ("relevant area", s141A(12)(d)). Cross-border services count only if they stop in England outside London. Scotland and Wales are not covered by these regulations; some operators publish voluntarily (e.g. Cardiff Bus, Borders Buses) [S2, S3] |
| Excluded | Section 19 and 22 permit services and community buses (reg 2(1)); coach services; tours (unless they carry point-to-point passengers); **unregistered closed school services and closed school services registered voluntarily at an LA's request** [S3]. LA-contracted *registered* services *are* in scope, and the operator publishes them. Demand-responsive transport is generally out of scope [S3, S8] |
| Agents | "Agents are defined as people outside the operator's organisation that can publish data on behalf of an operator"; the legal duty stays with the operator [S3]. Agents include software vendors and consultancies (e.g. Ticketer, Transmach, Optibus exports), and LAs can act as agents |
| Publishing method | Upload a TXC zip or file, or provide a URL that BODS polls ("twice daily"). Operators with 40 or fewer services can upload; others must give a URL (reg 4) [S2, S3] |
| Format | TXC 2.4, **UK PTI profile** (v1.1.A). Non-PTI-compliant files have been rejected since Sep 2021 (BODS 1.14.0) [S3, S4, S9] |
| Timing | Changes needing a Traffic Commissioner application must be published **by the date the application is made** (reg 8(2)). The guidance glosses this as "the 42-day period". Other changes go "before the change takes effect" (reg 8(3)). Franchising authorities publish 28 days ahead (reg 8(4)). A cancelled service's file must be removed "immediately before the cancellation is to take effect" (reg 8(5)) [S2, S3] |
| Quality | "The department will not legally mandate quality standards"; first-stage validation failures are rejected. The Data Quality Service (since 2024) produces observations, and critical ones feed "Services requiring attention" [S3, S9] |

**Consequences for coverage:**

- **Missing in BODS but present in TNDS:** non-registered LA tenders and school services; community transport; London (TfL is not under the regulations); Scotland and Wales (except voluntary publishers); non-compliant operators. In March 2023 Traveline estimated about 1,000 in-scope services were missing [S10]. BODS lists OTC-registered services not found in BODS as "services requiring attention" [S9].
- **Present in BODS but missing in TNDS:** new registrations published at application time, around 42+ days before start. BODS data therefore often *leads* TNDS, which only picks up changes once a region has processed them. Some small operators' services may also never have been keyed by a region.
- **Dates differ:** BODS files are published early (registration application) and often carry **future StartDates**. TNDS shows a regional horizon after its own processing.

### 1.3 BODS "Services requiring attention", staleness and timeliness

BODS has a timeliness and staleness regime: a 42-day look-ahead tied to OTC variation effective dates, an end-date-passed check, and a 12-month "not updated" check. The changelog mentions improvements to "staleness when changes are made to the registration" (Aug 2023), "look ahead" (Nov 2023), the "12 month timeliness check" (Dec 2023), and a "Derived termination date" column added to compliance reports to show "where look ahead when data is made invalid due to the revision number" (Jun 2025) [S9]. I could not reach the live operator guidance page that defines these thresholds exactly **(unverified detail)**. In practice:

- **Stale data stays in the archive** until the operator replaces it, though "inactive data" has been removed from Download All and the API since April 2023 [S9]. A BODS file can therefore describe a timetable that is no longer operated, but only if its `EndDate` is open or in the future.
- Since Nov 2024, **file-level processing** means a dataset zip can be partly published: valid files are passed through and invalid ones are dropped (BODS 1.42.0) [S9]. **Some lines or files of a service can be missing from BODS even though the operator uploaded them.**
- Known GTFS issue: from 13 May 2026 the BODS GTFS daily refresh was stuck, with the file "stale and retains the previous date stamp" (archived changelog, June 2026 capture) [S9]. **Check `feed_info.feed_version` in the GTFS files you compare.**

---

## 2. How timetables are versioned and dated in TransXChange

### 2.1 The fields that matter

```xml
<TransXChange xmlns="http://www.transxchange.org.uk/"
    CreationDateTime="2025-04-25T09:12:00"
    ModificationDateTime="2025-06-17T14:03:00"
    Modification="revise"
    RevisionNumber="3"
    FileName="FESX_PF0000599_75.xml"
    SchemaVersion="2.4">
  ...
  <Services>
    <Service>
      <ServiceCode>PF0000599:75</ServiceCode>            <!-- OTC reg, '/' -> ':' -->
      <Lines>
        <Line id="FESX:PF0000599:75:8">                   <!-- NOC:ServiceCode:LineName -->
          <LineName>8</LineName>
        </Line>
      </Lines>
      <OperatingPeriod>
        <StartDate>2025-06-08</StartDate>
        <!-- no EndDate = "until further notice" -->
      </OperatingPeriod>
      <OperatingProfile>
        <RegularDayType><DaysOfWeek><MondayToFriday/></DaysOfWeek></RegularDayType>
        <BankHolidayOperation>
          <DaysOfNonOperation><AllBankHolidays/></DaysOfNonOperation>
        </BankHolidayOperation>
      </OperatingProfile>
      <RegisteredOperatorRef>O1</RegisteredOperatorRef>
      <PublicUse>true</PublicUse>
      <StandardService>...</StandardService>
    </Service>
  </Services>
```

PTI profile rules (v1.1.A, §2.3, now superseded by the Versioning Note v2) [S4, S5]:

- `CreationDateTime` is set at revision 0 and never changes.
- `ModificationDateTime` is omitted at revision 0 and present on every later revision.
- `Modification` is `new` at revision 0 and `revise` after that. No `delete` is used.
- `RevisionNumber` starts at 0 and goes up by 1 per revision. It is **independent of the OTC variation number** ("will rarely if ever match").
- `Status` is ignored if it conflicts with the data.
- There is one `Service` per file (§5.2, §5.3.1), "even to different versions of the same service". Several `Line`s are allowed only if related spatially (1/1A) or temporally (summer/winter).
- The `Line id` must not contain a version number. Seasonal splits use a suffix (`...:8:winter`).
- **`OperatingPeriod/EndDate` must be omitted for "until further notice".** Far-future sentinel end dates are not allowed, and the validator caps end dates at 11 years.
- Unregistered services use `UZ000<NOC>:<ref>` ServiceCodes (e.g. `UZ000WNCT:GTT32`), which must stay stable across updates.
- The `Registrations` element is *not* allowed in PTI files.
- Stops: use `AnnotatedStopPointRef` to NaPTAN. A custom `StopPoint` is allowed only for at most 2 months.

### 2.2 Which version is valid on a given date? (The rules changed in December 2025)

**Old rule (PTI v1.1.A §2.3, 2021 draft text):** "When a new file is supplied to BODS with a new RevisionNumber the previous RevisionNumber file is superseded **from the start date of the new file**." A new file with an `EndDate` supersedes the old one until that EndDate. After that, if no valid revision remains, BODS provides no data [S4]. In other words, a lower revision stays valid *until* the higher revision's StartDate.

**New rule (PTI Versioning Application Note v2, 1 Dec 2025, which supersedes §2.3)** [S5]:

- "All data for a Service must be provided in a single TXC file." This is a breaking change for suppliers that split Mon–Fri, Saturday and school journeys into separate files.
- "New higher RevisionNumber files supersede lower RevisionNumber files **in their entirety**."
- "OperatingPeriod must be complete, no inheritance from overlapping OperatingPeriod is assumed."
- To end a service, publish a new revision with an EndDate: "After this date there is no valid OperatingPeriod and therefore the Service will cease."
- The operator "should stop publishing" the superseded revision "as soon as practicable". So for a while, both may be in the archive.
- The note gives no explicit go-live date. DfT circulated it to data providers in mid-December 2025 [S11].

**Why this matters for your duplicates and gaps:**

| Situation in BODS archive | Old reading | New reading | What a naive union does |
|---|---|---|---|
| Rev 0 (start 1 Jan, open) and Rev 1 (start 1 Mar, open) both present | Rev 0 runs 1 Jan–28 Feb, Rev 1 from 1 Mar | Rev 1 wins everywhere it overlaps; it is unclear what applies before 1 Mar | **Double counting from 1 Mar** |
| Ticketer-style split: `MF.xml` (rev 5), `SAT.xml` (rev 2), `SCH.xml` (rev 5) for the same ServiceCode | Ambiguous; the forum reports "hundreds of services" affected [S11] | Not allowed; one file per service | A highest-revision-wins rule **deletes Saturdays** |
| Multi-depot service: depot A and depot B journeys in separate files with different revisions [S11] | Ambiguous | Not allowed | Highest-revision-wins **drops one depot's journeys** |
| Rev 3 has `EndDate` = 30 Apr and nothing newer | Service ends 30 Apr | Same | Correct, but the service then disappears from BODS, while TNDS may carry it on to its regional horizon |

The practical effect is that **"keep max RevisionNumber per ServiceCode" is unsafe for pre-2026 data and for publishers that still split files.** The BODS User Forum and TIL describe exactly these problems: revision numbers "often a bit messy", multi-file services, and the Ticketer and Transmach mismatches [S11]. jclgoodwin (bustimes.org) describes a workaround of appending part of the file name to ServiceCode, and warns it risks "misinterpreting correct data" [S11].

### 2.3 Operating profiles: the second source of date disagreement

**Order of specificity:** VehicleJourney, then JourneyPattern, then Service. A more specific profile **replaces** a less specific one; profiles are never merged. PTI §5.3.3.1 says a trip either has no profile or "a complete set of OperatingProfile elements which completely replace the default pattern". Within one profile, the elements apply in this order: `RegularDayType`, then `PeriodicDayType`, then `ServicedOrganisationDayType`, then `BankHolidayOperation`, then `SpecialDaysOperation`, with the last being most authoritative [S12].

**Defaults differ between consumers when no profile exists.** Passenger assumes Monday to Friday [S12]. The BODS GTFS converter assumes **Monday to Sunday** (`DEFAULT_OPERATING_PROFILE`, `txc-processor/data/calendar.ts`). That one difference can produce whole extra weekend services in GTFS for sloppy files.

**Bank holidays.** These are named elements (`ChristmasDay`, `BoxingDay`, `GoodFriday`, `EasterMonday`, `MayDay`, `SpringBank`, `LateSummerBankHolidayNotScotland`, `AugustBankHolidayScotland`, `Jan2ndScotland`, `StAndrewsDay`, the `...Holiday` displacement variants, `ChristmasEve`, `NewYearsEve`, and `OtherPublicHoliday` with a `Date`) plus groups (`AllBankHolidays`, `AllHolidaysExceptChristmas`, `HolidayMondays`, `Christmas`, `DisplacementHolidays`, `EarlyRunOffDays`). If a bank holiday is not named at all, the service runs according to its `RegularDayType` (this is how both the GTFS converter and Passenger behave; inferred from Passenger's displacement-holiday examples [S12]).

**ServicedOrganisation (school terms).** In `DaysOfOperation/WorkingDays`, the journey runs only on term days. In `DaysOfNonOperation/WorkingDays`, it runs only outside term. PTI requires inclusive start and end dates and forbids `Holidays` in the organisation definition [S4]. Term dates come from whoever wrote the file. TNDS regions often use LA-wide term calendars, while operators may use the specific school's dates, **so school journeys legitimately differ between sources.**

**Special days.** `SpecialDaysOperation` date ranges override everything else. These are used for Christmas, events and roadworks. A temporary Christmas timetable may appear as (a) special days inside the base file, (b) a separate short-`OperatingPeriod` file (often a separate revision), or (c) a new revision that replaces the base file. Each choice gives a different overlap pattern; see §5.

---

## 3. Causes of duplication and missing services, by source

| Cause | TNDS | BODS TXC | BODS GTFS |
|---|---|---|---|
| Cross-boundary service in two regional zips | **Yes** (documented) | No (one dataset per operator) | Possible: regional GTFS includes a trip if *any* stop is in the region, so a trip can appear in several regional zips; `all_gtfs.zip` dedupes |
| Several files per line (seasonal, depot, day type) | Yes ("A single line can have multiple files") | **Yes, common before v2** | Partly deduped (see §4.5) |
| Overlapping revisions both present | Rare (database export) | **Yes** (old revision not yet removed; future-dated new revision published 42+ days ahead) | Survive unless all seven dedupe keys including `service_id` match |
| Same service published by operator and agent, or two NOCs (e.g. joint operation) | n/a | Yes (two datasets) | Trip ID hash differs if any field differs; route dedupe only happens TNDS-vs-BODS |
| TNDS route duplicating BODS route | n/a | n/a | Dropped when a BODS route with the same `NOC + LineName` exists, **but only that exact key**. A NOC mismatch (e.g. `SCMY` vs `SCEM`, or an old NOC in TNDS) or a LineName mismatch (`X5` vs `X5 Express`) lets **both** through (L, S and W regions only) |
| Missing: service not registered (tender, school, community) | Usually present | **Absent** (out of scope) | Absent unless region is L, S or W (TNDS used) |
| Missing: non-compliant or late operator | Present if region keyed it | Absent, listed as "requiring attention" | Absent |
| Missing: file failed validation (partial publish since Nov 2024) | n/a | **Silently absent** | Absent |
| Missing: invalid stop refs | Region may include non-NaPTAN stops | PTI allows custom stops for at most 2 months | **Whole file skipped** if any stop fails NaPTAN lookup/validation (`processStopPoints` returns falsy, so the file is skipped) |
| Missing: operator/NOC not in NOC database | n/a | n/a | **Service dropped** ("Unable to find agency with national operator code") |
| Missing: service expired | n/a | Stale files may linger | Dropped if `EndDate` < today |
| Missing: date beyond horizon | Regional horizon varies | Up to the file's EndDate (open-ended files have none) | **Cut at today + 9 months** |
| Missing: processing failures | n/a | n/a | The step function tolerates **10 BODS-file and 170 TNDS-file** processing failures per run without failing the build |

---

## 4. How the BODS GTFS conversion actually works

### 4.1 Provenance

BODS was built by DfT with ITO World and KPMG. ITO also markets a TXC to GTFS transformation service [S10, S13], and the early BODS GTFS (around 2020–2023) came from ITO's converter **(not confirmed from primary sources)**. The **current** GTFS is produced by DfT's open-source "BODS Integrated Data" platform (TypeScript Lambdas on AWS with Aurora Postgres), whose README describes "GTFS feed generation via TransXChange". This section describes that code. ITO-era GTFS files you hold may behave differently, so record the download date of every GTFS you analyse.

### 4.2 Pipeline (`terraform/modules/timetables-sfn/timetables-state-machine.asl.json`)

```
DB cleardown
 └─ Reference data (parallel): NOC · NPTG → NaPTAN · UK bank holidays (gov.uk JSON) · TfL TXC generation · NeTEx
 └─ Retrieve BODS TXC  (https://data.bus-data.dft.gov.uk/timetable/download/bulk_archive
                        + https://coach.bus-data.dft.gov.uk/TxC-2.4.zip)
 └─ Unzip → Process BODS TXC   (distributed Map, MaxConcurrency 50, ToleratedFailureCount 10)
 └─ Retrieve TNDS TXC  (FTP; all *.zip except NCSD.zip)
 └─ Unzip → Process TNDS TXC   (distributed Map, MaxConcurrency 50, ToleratedFailureCount 170)
 └─ Table renamer → Trip table creator (national dedupe) → Regional trip tables → England (union)
 └─ Export GTFS CSVs per region from Postgres → zip: all_gtfs.zip, e_gtfs.zip, ea_gtfs.zip, …
```

Key point: **BODS files are processed before TNDS files**, which is what makes the "TNDS route is a duplicate of a BODS route" check work. **Within** the BODS step, files are processed concurrently (50 at a time), so which of two conflicting files is ingested first is not deterministic.

### 4.3 TNDS inclusion rule (`txc-processor/utils.ts`)

```ts
export const isRequiredTndsDataset = (key) =>
  key.includes("/L/") || key.includes("/S/") || key.includes("/W/");
export const isRequiredTndsServiceMode = (mode) =>
  ["coach","ferry","metro","tram","underground"].includes(mode);
// a TNDS service is skipped if !isRequiredTndsDataset && !isRequiredTndsServiceMode
```

So BODS GTFS = BODS (England, plus voluntary Scotland and Wales publishers) + **all TNDS London, Scotland and Wales** + **TNDS non-bus modes everywhere** + BODS coach. **An English bus service that is in TNDS but not in BODS will never appear in BODS GTFS.** This explains much of the coverage gap you see between TNDS and BODS GTFS outside L, S and W.

Then, for each TNDS line, it computes `nocLineName = agency.noc + line.LineName`. If a route with that key already exists with `data_source = 'bods'`, **the whole TNDS service is dropped** (`processRoutes` throws `DuplicateRouteError`, `txc-processor/data/routes.ts`). For TNDS, `route.line_id` becomes `${ServiceCode}_${Line@id}` to avoid ID clashes.

### 4.4 Per-service processing (`txc-processor/index.ts`)

For each `Service` in a file:

1. **Expired?** If `OperatingPeriod/EndDate` is before today, the service is skipped.
2. **Operator.** `RegisteredOperatorRef` maps to an `Operator`. The NOC is `NationalOperatorCode`, falling back to `OperatorCode`, and must exist in the `agency` table, which is built from file operators plus the NOC database for names. If not, the service is skipped. GTFS `agency_id = "OP" + internal id`, and `agency_noc` is exported as an extra column.
3. **Journeys.** VehicleJourneys are matched by `LineRef` to the service's Lines. If there are none, the service is skipped.
4. **Routes.** One GTFS route per TXC `Line`; `route_short_name = LineName`, `route_long_name = ""`. `route_id` is an internal integer, **not stable across builds**.
5. **Calendars** (`data/calendar.ts`, see §4.6).
6. **Shapes** from `RouteSection/RouteLink/Track`, where present.
7. **Trips** (`data/trips.ts`, see §4.5).
8. **Frequencies.** `Frequency/Interval/ScheduledFrequency` becomes `headway_secs`. `exact_times` is 0 only if `EndTime` exists.
9. **Stop times** (`utils.ts mapTimingLinksToStopTimes`): times run from `VehicleJourney/DepartureTime` along `JourneyPatternTimingLink`s using `RunTime` and `WaitTime`. A VehicleJourneyTimingLink value is used when the JP value is zero or missing (`getFirstNonZeroDuration`). Times past midnight roll over to more than 24h, and `DepartureDayShift=1` adds 24h. `pickup_type` and `drop_off_type` come from stop `Activity`; `timepoint` is 1 only for `principalTimingPoint`/`PTP`. `stop_id` is the **upper-cased ATCO code**.

Stops: a file whose stops fail lookup or validation is **skipped entirely**. Stops come from the NaPTAN tables (`naptan_stop_new`), and the region code used for regional splitting comes from NPTG admin area (or locality, for non-bus modes). **A trip's region is therefore defined by its stops' NaPTAN admin areas, not by the TNDS zip or the operator's licence area.**

### 4.5 Trip identity and deduplication

```ts
// data/trips.ts
const hashedVehicleJourney = objectHasher.hash(
  { vehicleJourney: clonedVehicleJourney /* minus DepartureDayShift */, service },
  { alg: "sha1" });
const tripId = `VJ${hashedVehicleJourney}`;
```

- The **trip_id is a SHA-1 of the whole parsed VehicleJourney object plus the whole Service object.** The Service includes `OperatingPeriod`, `OperatingProfile`, Lines and JourneyPatterns. It does **not** include the root `RevisionNumber`.
  - If two files contain an identical VJ *and* an identical Service block, for example the same file republished under two dataset IDs or an agent and operator copy, they get the **same trip_id**. On insert conflict, `conflicting_files` is appended, and the later file's journey is dropped from its own calendar, frequency and stop_time processing. **Which file "wins" depends on the order of concurrent processing.**
  - If anything differs (a new `StartDate`, a changed headway anywhere in the Service, a different VJ code), the trip_ids differ and **both trips are kept**.
- **The national dedupe** (`gtfs-timetables-generator/data.ts createTripTable`):

```sql
INSERT INTO trip_ALL
SELECT DISTINCT ON (route_id, service_id, ticket_machine_journey_code,
                    direction, origin_stop_ref, destination_stop_ref, departure_time) *
FROM trip
ORDER BY route_id, service_id, ticket_machine_journey_code,
         direction, origin_stop_ref, destination_stop_ref, departure_time,
         revision_number DESC;
```

  `service_id` is the calendar's internal ID, deduplicated by a **hash of the expanded calendar plus calendar_dates**. So **two revisions of the same journey are collapsed only if they produce exactly the same calendar after clipping**, and they must share `route_id` (the same `line_id`, i.e. the same `Line@id`). Revision 0 (start 1 Jan, open) and revision 1 (start 1 Mar, open) produce different calendars, so **both survive and double up from 1 Mar** to the 9-month horizon. Note too that `revision_number` is a string column; ordering is lexical if it is not cast, so "10" sorts before "9" **(inference from schema; check the column type)**.
- Regional files: a trip is in region X if any of its stops has NPTG `region_code = X`. `e_gtfs` is the union of the English regions. **The same trip_id can appear in several regional files.** Concatenating regional GTFS files therefore creates duplicates; use `all_gtfs.zip` or dedupe on trip_id.
- `trips.txt` exports `vehicle_journey_code` as an extra column (not standard GTFS). This is the best hook back to TXC.
- The TXC analyser (`txc-analyser/checks/checkForDuplicateJourneys.ts`) flags, as advisory only, journeys in one file with the same DepartureTime, RouteRef and OperatingProfile. Duplicates within a file are not removed by the GTFS step unless the dedupe keys collide.

### 4.6 Calendar expansion (`txc-processor/data/calendar.ts`)

```ts
const startDateToUse = startDate.isBefore(today) ? today : startDate;
const date9MonthsAfterStart = startDateToUse.add(9, "months");
const endDateToUse = endDate?.isBefore(date9MonthsAfterStart) ? endDate : date9MonthsAfterStart;
```

- **Start is clipped to the build date.** A GTFS built on 14 Nov never contains earlier dates, even if the TXC started in June.
- **End is the TXC EndDate or StartDate + 9 months, whichever is sooner.** For a future-dated file, the 9 months count from *its* start. `feed_info.feed_end_date = max(calendar.end_date)`.
- The weekday flags come from `DaysOfWeek` (`Monday … Sunday`, `MondayToFriday`, `MondayToSaturday`, `MondayToSunday`, `Weekend`, `Not<Day>`). `HolidaysOnly` gives an all-zero calendar plus added dates.
- **No profile anywhere means `MondayToSunday`**.
- `SpecialDaysOperation` date ranges, bank holidays and serviced-organisation days become `calendar_dates` rows: 1 for added, 2 for removed. **Non-operation wins** over operation where the same date appears in both.
- **ServicedOrganisation:** if `DaysOfOperation` term days exist, the weekly flags are zeroed and *only* the term days (filtered to the calendar's weekdays) are added as exception 1. This produces large `calendar_dates` tables for school services. `ServicedOrganisation/Holidays` with `DaysOfOperation` is handled too, but only the first matching organisation's holidays are used.
- **Calendars that end up empty** (no weekdays and no added dates) cause the trip to be **dropped**. This happens, for example, to a holidays-only journey whose only holidays fall outside the window.
- **Bank holidays** come from the gov.uk bank-holidays JSON. Each named holiday resolves to its **next occurrence only** (`getNextOccurrenceOfBankHoliday`), so a 9-month window never sees a second Christmas, which is fine. But:
  - `AllBankHolidays` includes **`Jan2ndScotland`, `StAndrewsDay`, `AugustBankHolidayScotland` and their displacement days for every service, England included.** An English Mon–Fri service with `<DaysOfNonOperation><AllBankHolidays/>` loses 2 January, 30 November and the first Monday of August in GTFS, even though it runs in reality. Scottish services marked the same way lose the English late-August Monday. These are spurious **missing-trip** dates (code reading; a candidate issue to raise with DfT).
  - Fixed-date elements (`ChristmasDay` = 25 Dec) and displacement elements (`ChristmasDayHoliday` = the substitute day) are kept separate. If a file says `ChristmasDay` but not `ChristmasDayHoliday` in a year when 25 Dec is a Saturday, the substitute Monday runs as normal.
  - `OtherPublicHoliday/Date` is honoured.
- **Times are naive local times** (`Europe/London`). The trip `departure_time` column used for dedupe is converted to UTC with the build-time offset, which is harmless but means dedupe compares strings like `07:15:00Z`.

### 4.7 Worked example: why one TXC journey becomes 0, 1 or 2 GTFS trips

TXC in the BODS archive, both files present (operator hasn't retired rev 0):

```xml
<!-- file A: RevisionNumber="0" -->
<OperatingPeriod><StartDate>2026-09-01</StartDate></OperatingPeriod>
<VehicleJourney><VehicleJourneyCode>VJ_0715</VehicleJourneyCode>
  <DepartureTime>07:15:00</DepartureTime> ...</VehicleJourney>

<!-- file B: RevisionNumber="1", same Line@id, same 07:15 journey -->
<OperatingPeriod><StartDate>2026-12-01</StartDate></OperatingPeriod>
<VehicleJourney><VehicleJourneyCode>VJ_0715</VehicleJourneyCode>
  <DepartureTime>07:15:00</DepartureTime> ...</VehicleJourney>
```

GTFS built 2026-11-14:

```
calendar.txt
service_id,monday,...,friday,saturday,sunday,start_date,end_date
101,1,1,1,1,1,0,0,20261114,20270814      # from A: clipped start, +9 months
102,1,1,1,1,1,0,0,20261201,20270901      # from B

trips.txt
route_id,service_id,trip_id,...,vehicle_journey_code
55,101,VJ3f1c…,…,VJ_0715
55,102,VJ9ab2…,…,VJ_0715                  # different hash (Service differs) and service_id → not deduped
```

From 1 Dec to 14 Aug, **07:15 runs twice**. Under the v2 note only file B should apply. Under the old v1.1.A reading, A applies until 30 Nov. Neither reading supports both at once.

---

## 5. Guidance for reconciliation code

### 5.1 Principles

1. **Resolve versions within each source first, then compare across sources.** Never union raw files.
2. **Compare at the trip × service-date level** inside an explicit window `[D0, D1]` that every source covers. Use `D0 ≥ max(build dates)` and `D1 ≤ min(source horizons)`, and note that BODS GTFS stops at about build + 9 months and TNDS horizons vary by region. Report coverage outside the window separately, as "horizon" differences rather than "missing" ones.
3. **Treat identifiers as source-local.** ServiceCode, Line@id, VehicleJourneyCode, JourneyPattern IDs, GTFS route_id, service_id and trip_id do not carry across sources. GTFS `route_id` and `service_id` don't even persist across builds; `trip_id` persists only while the VJ and Service are byte-identical in content.

### 5.2 Version selection within BODS TXC

Work per `(NOC, ServiceCode)`, where ServiceCode is the OTC `PB0000xxx:yyy` or `UZ000…`, and fall back to `(NOC, LineName)` if the ServiceCode is missing or malformed.

```python
def select_bods_versions(files, on_date, mode="v2"):
    """files: parsed TXC docs for one (NOC, ServiceCode).
    Returns the files whose journeys apply on on_date."""
    live = [f for f in files
            if f.start <= on_date and (f.end is None or on_date <= f.end)]
    if not live:
        return []
    # Detect a split publication (several files, same ServiceCode,
    # disjoint day-types/lines published together)
    groups = group_by_publication(live)   # same dataset_id & same upload batch / CreationDateTime ±1 day
    if mode == "v2":
        # higher RevisionNumber supersedes lower in their entirety
        best = max(groups, key=lambda g: (max(f.revision for f in g),
                                          max(f.modified or f.created for f in g),
                                          max(f.start for f in g)))
        return best
    else:  # "v1" reading: latest StartDate wins, revision as tie-break
        best = max(groups, key=lambda g: (max(f.start for f in g),
                                          max(f.revision for f in g),
                                          max(f.modified or f.created for f in g)))
        return best
```

Practical rules:

- **Group files that belong to one publication before applying a revision rule.** Use the same dataset ID and the same upload (the BODS API exposes dataset ID and modified time), or files whose Line sets or day-type sets are disjoint and complementary. Then apply supersession to the group, not to single files. This avoids deleting Saturday or depot-B journeys when revisions don't match.
- **Tie-break order:** `RevisionNumber`, then `ModificationDateTime` (or `CreationDateTime` at rev 0), then `StartDate`, then BODS dataset modified time. Cast RevisionNumber to int.
- **Use both v1 and v2 readings for pre-2026 data and report the gap.** If the two readings differ by a lot, treat the service as "ambiguous version" rather than as missing or duplicate.
- **Look for a temporary overlay.** If a higher-revision file has a short `OperatingPeriod` (say 31 days or less) or is dominated by `SpecialDaysOperation`, and the lower revision is open-ended, treat the short file as an overlay. The overlay applies on its dates, and the base timetable resumes after it. This is what operators intend, even though v2 says "in their entirety". **(Heuristic; flag such cases.)**
- **Drop files where `OperatingPeriod/EndDate` < D0.** Keep open-ended files, but flag "stale" if `ModificationDateTime` (or `CreationDateTime`) is more than 12 months old and no newer file exists.

### 5.3 Version selection within TNDS

- **Deduplicate across regional zips first.** Key on `(NOC, LineName, ServiceCode)` and on the journey fingerprints (§5.5). Prefer the zip of the region that holds most of the stops, by NaPTAN `AdministrativeAreaCode` to region. Never prefer by zip order.
- For several files per line inside a region, apply the same group-then-supersede logic. TNDS files are export snapshots, so `RevisionNumber` is less meaningful than `OperatingPeriod`. Use **latest StartDate ≤ date** as the primary rule.
- Record the TNDS build date and treat `[build, region horizon]` as the coverage window. Estimate the horizon per region as the max `EndDate`, or as the date when open-ended services stop being replaced.
- For short workings, use the dead-run information (`StartDeadRun`/`EndDeadRun`) to trim the journey before fingerprinting, as Traveline advises.

### 5.4 Handling BODS GTFS

- Use `all_gtfs.zip`, not concatenated regional zips. If you must use regional zips, dedupe on `trip_id`.
- Map back to TXC through `trips.vehicle_journey_code` + `agency_noc` + `route_short_name`. Add first-stop departure to disambiguate, since VJ codes repeat across files.
- **Re-deduplicate inside GTFS.** Group trips by `(agency_noc, route_short_name, direction_id, stop_id sequence, first departure_time)`. Where two trips have **overlapping active dates** (expand calendar plus calendar_dates), keep one and log the pair. These are the residual revision overlaps from §4.5.
- Know the converter's artefacts and **exclude them from "real" differences**:
  - dates before the GTFS build date are absent;
  - dates after about build + 9 months are absent;
  - services with no operating profile are expanded to 7 days a week;
  - `AllBankHolidays` services are wrongly removed on Scottish holidays in England, and vice versa;
  - files with any bad stop are absent;
  - services whose NOC isn't in the NOC table are absent;
  - English TNDS-only bus services are absent;
  - TNDS L, S and W services can still duplicate BODS where NOC or LineName differ.

### 5.5 Matching keys across sources

Use a hierarchy of keys, from strictest to loosest, and record which level matched:

| Level | Key | Use |
|---|---|---|
| T1 | `NOC*` + `LineName*` + full ordered ATCO list + first departure (HH:MM) + service date | Exact trip match |
| T2 | `NOC*` + `LineName*` + (first ATCO, last ATCO, stop count ±2) + first departure ±2 min + date | Tolerates a minor stop list difference (custom stop, short working trimmed, timing-point-only lists) |
| T3 | `LineName*` + first and last **StopArea / locality** + first departure ±5 min + date (no NOC) | Catches NOC mismatches (old or regional NOCs, joint working, agent publishing under the wrong NOC) |
| S1 | `NOC*` + `LineName*` + Jaccard(stop set) ≥ 0.8 | Service-level presence/absence when trips don't line up (headway changes) |

Normalisation (`*`):

- **NOC:** upper-case. Map legacy and group NOCs through the Traveline NOC database (`NOCLines`/`NOCTable`, "parent" or "group" fields). Keep a manual override table for known swaps.
- **LineName:** upper-case, trim, remove spaces and punctuation, strip leading zeros (`"0X5"` becomes `"X5"`), and strip suffix words (`"Express"`, `"Service"`, `"Line"`). Keep the raw value too.
- **ATCO codes:** upper-case. Map to the **current** NaPTAN, since retired stops have `Status=inactive`. Collapse to a parent StopArea for T3. Don't drop stops missing from NaPTAN (TNDS may contain them); keep them as raw tokens.
- **Times:** convert all times to seconds after service-day midnight, applying `DepartureDayShift` and the over-24h convention.

### 5.6 Precedence when sources disagree

After version resolution and matching, apply rules per service and date:

1. **A trip in all three sources** is consistent, so keep it once.
2. **In BODS TXC and TNDS but not in BODS GTFS:** check the converter artefact list (§5.4). If none applies, it's a GTFS build or processing failure. Prefer TXC.
3. **In BODS TXC but not in TNDS:**
   - If the BODS file's StartDate is after the TNDS build date minus about 14 days, call it **"TNDS lag"** and prefer BODS.
   - Otherwise, check whether TNDS has the same service under a different NOC or LineName (T3 match). If not, it's a probable TNDS coverage gap; prefer BODS.
4. **In TNDS but not in BODS:**
   - Classify by ServiceCode or registration: unregistered or school-closed means **BODS out of scope**, so keep TNDS.
   - Scotland, Wales or London stops only means BODS out of scope, so keep TNDS.
   - A registered English service that appears in BODS "requiring attention" is a **non-compliant operator**. Keep TNDS, flagged.
   - A BODS service with an `EndDate` before this date but a TNDS service still running suggests **either a cancelled service still in TNDS or an end-dated BODS file awaiting replacement.** Use the OTC registration status (from the OTC registered-services file) to decide.
5. **Several trips match within one source after resolution:** keep one, unless they have different block or vehicle numbers and the source is BODS. Duplicated departures *can* be real (duplicates or relief buses in school peaks), but these are normally distinct VehicleJourneyCodes with different `Operational/Block`.
6. **The default ranking for "what operated", when you must pick one,** is:
   - BODS TXC (resolved), for English registered services in the window;
   - then TNDS, for Scotland, Wales and London, unregistered services, and dates before BODS coverage;
   - then BODS GTFS, as a convenience view only.

   For historic dates, use archived snapshots of each source **taken at or before** the date, never a later file, because the later file may have had an earlier revision removed.

### 5.7 Date-window handling checklist

- Store `source`, `snapshot_date`, `file`, `dataset_id`, `revision`, `start`, `end`, `created`, `modified` for every journey.
- Expand every source to explicit service-dates with **one** calendar engine of your own. Do not mix the converter's GTFS calendar with your own TXC expansion. Apply bank holidays by **country** (England and Wales vs Scotland, based on stop locations), and apply `ServicedOrganisation` dates from the file.
- Clip to `[D0, D1]` before counting. Report three counts separately: "outside horizon", "outside window" and "missing".
- For time series, snapshot weekly. TNDS builds Monday to Thursday; BODS changes continuously and is polled twice a day.

### 5.8 Diagnostics worth computing

- For each `(NOC, ServiceCode)` in BODS: the number of files, revisions present, overlapping-period days and split-publication flag. This directly measures how bad versioning is per operator or agent.
- For each pair of sources: matched trips by level (T1 to T3, S1) per region and day type.
- GTFS-specific: trips whose `vehicle_journey_code` appears under more than one `service_id` with overlapping dates, which flags revision overlap.
- Bank holiday sanity check: count trips on 2 Jan, the first Monday in August, 30 Nov and the last Monday in August per country.

---

## 6. Open questions to test empirically

1. Does BODS's `bulk_archive` include future-dated revisions alongside the current ones, and does it still include superseded revisions? The changelog says inactive data was removed from Download All in April 2023, but "inactive" isn't defined there. *Test:* count files per ServiceCode in a fresh bulk archive.
2. How widely has the v2 single-file rule been adopted since December 2025? *Test:* the share of ServiceCodes with more than one file, by agent or software (`FileName` patterns, `CreationDateTime` clusters).
3. First Bus TNDS-from-BODS migration (from July 2026): for those NOCs, TNDS should now mirror BODS, which is a good control group.
4. Is `trip.revision_number` text or integer in the converter's schema? This decides whether revision 10 loses to revision 9.

---

## Sources

- **S1** Traveline, *Traveline National Dataset (TNDS)*: https://travelinedata-blue.prod.aws.passenger-app.com/traveline-open-data/traveline-national-dataset/
- **S2** *The Public Service Vehicles (Open Data) (England) Regulations 2020*, SI 2020/749: https://www.legislation.gov.uk/uksi/2020/749/made (original text as made)
- **S3** DfT, *Bus open data implementation guide*: https://www.gov.uk/government/publications/bus-open-data-implementation-guide/bus-open-data-implementation-guide
- **S4** PTI, *TransXChange UK PTI Profile v1.1.a.4* (draft, Jun 2021): https://www.pti.org.uk/system/files/meeting_files/papers/TransXChange%20UK%20PTI%20Profile%20v1.1.a.4%20Clean.pdf. Current v1.1.A: https://pti.org.uk/system/files/files/TransXChange_UK_PTI_Profile_v1.1.A.pdf
- **S5** PTI, *Versioning in TxC-PTI, Application Note v2.0*, 1 Dec 2025: https://www.pti.org.uk/system/files/files/TransXChange%20UK%20PTI%20Profile%20-%20Versioning%20Application%20Note%20v2.pdf
- **S6** Traveline, *Data reporting / Known issues with TNDS*: https://travelinedata-blue.prod.aws.passenger-app.com/traveline-open-data/data-reporting/
- **S7** data.gov.uk, *Traveline National Dataset*: https://www.data.gov.uk/dataset/traveline-national-dataset
- **S8** CPT, *BODS and school services* (Jan 2024): https://www.cpt-uk.org/media/dr2pqh5b/cpt-paper-bods-and-school-services-210125.pdf
- **S9** BODS changelog and known issues (UK Government Web Archive capture, June 2026): https://tnaqa.mirrorweb.com/ukgwa/20260602043833mp_/https://www.bus-data.dft.gov.uk/changelog/ ; data formats: https://data.bus-data.dft.gov.uk/guidance/requirements/?section=dataformats
- **S10** Podaris, *Exploring the Bus Open Data Service* (May 2023; cites Traveline on missing services and the TNDS share): https://blog.podaris.com/bus-open-data-service/
- **S11** BODS User Forum: *Traveline (TIL) challenges with BODS version control* https://boduf.discourse.group/t/traveline-til-challenges-with-bods-version-control/144 ; *RevisionNumbers not matching in BODS timetable data* https://boduf.discourse.group/t/revisionnumbers-not-matching-in-bods-timetable-data/121
- **S12** Passenger help centre, *Operating profiles* https://help.passenger.tech/support/solutions/articles/60000714575-operating-profiles ; *Bank holidays* https://help.passenger.tech/support/solutions/articles/60000714581-bank-holidays
- **S13** ITO World, *Open standards, open source* (Q4 2024): https://www.itoworld.com/wp-content/uploads/2024/10/2024-Q4-Open-standards-open-source.pdf
- **Code** DfT, `bods-integrated-data` (read 14 Nov 2026, `main`): https://github.com/department-for-transport-BODS/bods-integrated-data. Key files:
  - `src/functions/txc-processor/{index.ts,utils.ts}`
  - `src/functions/txc-processor/data/{calendar.ts,trips.ts,routes.ts,database.ts}`
  - `src/shared/{dates.ts,schema/dates.schema.ts}`
  - `src/functions/gtfs-timetables-generator/data.ts`
  - `src/functions/{bods,tnds}-txc-retriever/index.ts`
  - `terraform/modules/timetables-sfn/timetables-state-machine.asl.json`
- Also relevant, not fully read: RTIG technical notes on special-day data (e.g. RTIGT060 *Christmas 2024 Data*, https://www.rtig.org.uk/system/files/documents/RTIGT060-1.0%20Christmas%202024%20Data.pdf); TransXChange schema documentation, https://www.gov.uk/government/collections/transxchange.

### Limits of this review

- The live BODS download pages and the full TransXChange 2.4/2.5 schema guide could not be fetched from this environment.
- The exact staleness thresholds and the current operator-guidance wording are summarised from the changelog, not the guidance page.
- I could not confirm whether the 2020–2023 GTFS came from ITO's converter.
- Code behaviour is as of 14 Nov 2026 and may change. Pin the commit you rely on.
