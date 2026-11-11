# ETL notes

NBS publishes these series as formatted Excel reports, not as data. Everything below had to be handled before a single query could run, and it is most of the work in this project.

## Getting the files

102 files across six series, roughly 180MB, published as a mix of ZIP and XLSX depending on the month. `scripts/download.py` reads each series page in the microdata catalog, pulls every non-PDF download link, and saves it. The PDFs are skipped because each one duplicates the Excel for the same month.

The archives are not committed. Run the script to regenerate them.

## Reading the fuel files

**The header row moves.** It sits on row 1, 2 or 3 depending on the month, and some files open with two paragraphs of narrative before the table starts. The parser scans the first twenty rows for a row carrying three or more parseable month values rather than assuming a position.

**Column labels are inconsistent.** Some months write `Average of May-25`, others hold a raw date. Both are handled.

**Two products share one sheet.** Kerosene is published per litre and per gallon side by side. Cooking gas likewise, as 5kg and 12.5kg. The parser detects these blocks from the marker above each one, so the six products come out of four series.

**Column order differs between series.** Diesel puts year-on-year before month-on-month, kerosene the reverse. The parser takes the third month column by position within its block rather than trusting a label.

**Consecutive files overlap.** Each file carries three months: the reference month, the one before, and the same month a year earlier. Only the reference month is kept, so nineteen files give nineteen months with no duplication.

**Petrol has no zone headers.** Every other series lists zone names in capitals as section headers with their states beneath, which is where the state-to-zone mapping comes from. The petrol sheets list states flat, so their zones are backfilled from the other series.

**Spelling drifts.** Nasarawa appears as "Nassarawa" in some months. Normalised on load.

## The Taraba contradiction

NBS is not internally consistent about which zone a state belongs to. The petrol series files **Taraba in the North West** for all nineteen months. Diesel, kerosene and cooking gas all place it in the **North East**, which is correct.

Resolved by majority rather than by whichever file loads last. The parser tallies every zone assignment per state and takes the most common, and `02_transform.sql` does the same independently with `mode() within group`, so the fix holds whether you rebuild from the spreadsheets or from the CSVs.

Taraba is the only state affected. The parser prints a warning if another ever appears.

## Reading the food files

The first sheet holds national averages with only the single highest and single lowest state written into a text cell such as `Gombe (3600)`. There is no state breakdown. The second sheet gives the same commodities across the six zones, and that is what the parser reads.

## The basket break

Between December 2024 and January 2025, NBS rebased the food basket. Of the 43 item labels in December and 42 in January, **one** is identical: Chicken Wings.

Some changes are cosmetic, "Agric eggs medium size" becoming "Agric hen eggs". Others are not. Bread went from 500g to 450g, evaporated milk from 170g to 150g, vegetable oil from "1 bottle" to 75cl. Items were dropped, including dried and smoked catfish, mudfish and Ofada rice. Items were added, including carrots, ginger, goat meat and watermelon.

Comparing a price across that break would mean comparing a 500g loaf with a 450g one. Rather than guess at a mapping, every item is tagged in `dim_item` with the basket it belongs to, both baskets are loaded, and the analysis uses January 2025 onward.

## What is not cleaned

State figures are NBS averages across outlets. No outlier detection is applied, because a genuine regional price shock and a data error look identical at this level of aggregation, and discarding the first would discard the main finding.
