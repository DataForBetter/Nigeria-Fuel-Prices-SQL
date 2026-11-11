"""Parse the NBS fuel price workbooks into one tidy table.

Each workbook holds one or two product blocks side by side. Within a block,
zone names in capitals act as section headers and the states of that zone
follow beneath. Three price columns give the year-ago month, the previous
month and the reference month. We keep the reference month only, because
consecutive files overlap.

Output: data/fuel_prices.csv with product, zone, state, month, price.
"""

import csv, re, sys
from datetime import datetime
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
EXTRACTED = ROOT / "extracted"
OUT = ROOT / "data"

ZONES = {"NORTH CENTRAL", "NORTH EAST", "NORTH WEST",
         "SOUTH EAST", "SOUTH SOUTH", "SOUTH WEST"}

# Rows that mark the end of the state list, or summary rows to skip.
STOP = re.compile(r"^(grand total|average|year on year|month on month|states? with|national|total)", re.I)

# Series folder -> default product name when the sheet has no block markers.
DEFAULT_PRODUCT = {"pms": "Petrol (PMS), litre",
                   "ago": "Diesel (AGO), litre",
                   "nhk": "Kerosene, litre",
                   "lpg": "Cooking gas, 5kg"}

BLOCK_LABELS = {
    "LITRE": "Kerosene, litre",
    "GALLON": "Kerosene, gallon",
    "5KG": "Cooking gas, 5kg",
    "12.5KG": "Cooking gas, 12.5kg",
}

STATE_FIXES = {"nassarawa": "Nasarawa", "abuja": "FCT Abuja", "fct": "FCT Abuja",
               "fct abuja": "FCT Abuja", "akwa-ibom": "Akwa Ibom",
               "cross river": "Cross River", "akwaibom": "Akwa Ibom"}


def norm_state(s):
    key = re.sub(r"\s+", " ", str(s)).strip().lower()
    return STATE_FIXES.get(key, re.sub(r"\s+", " ", str(s)).strip().title())


def parse_month(cell):
    """Turn a header cell into a (year, month) pair."""
    if isinstance(cell, datetime):
        return cell.year, cell.month
    t = str(cell or "").strip()
    m = re.search(r"([A-Za-z]{3,9})[\s\-/]*(\d{2,4})", t)
    if not m:
        return None
    name, yr = m.group(1)[:3].lower(), int(m.group(2))
    months = ["jan", "feb", "mar", "apr", "may", "jun",
              "jul", "aug", "sep", "oct", "nov", "dec"]
    if name not in months:
        return None
    return (yr + 2000 if yr < 100 else yr), months.index(name) + 1


def find_blocks(rows):
    """Locate (header_row_index, label_col, price_col, month) for each block."""
    blocks = []
    for ri, row in enumerate(rows[:20]):
        months = [(ci, parse_month(c)) for ci, c in enumerate(row)]
        months = [(ci, m) for ci, m in months if m]
        if len(months) < 3:
            continue
        # Group consecutive price columns into blocks of three.
        group = []
        for ci, m in months:
            if group and ci - group[-1][0] > 1:
                if len(group) >= 3:
                    blocks.append((ri, group))
                group = []
            group.append((ci, m))
        if len(group) >= 3:
            blocks.append((ri, group))
        if blocks:
            return ri, blocks
    return None, []


def block_product(rows, hdr_i, first_col, series):
    """Read the block marker above the header, if there is one."""
    for ri in range(max(0, hdr_i - 2), hdr_i + 1):
        for ci in range(max(0, first_col - 2), first_col + 2):
            try:
                v = str(rows[ri][ci] or "").strip().upper().replace(" ", "")
            except IndexError:
                continue
            if v in BLOCK_LABELS:
                return BLOCK_LABELS[v]
    return DEFAULT_PRODUCT[series]


def parse_file(path, series):
    wb = openpyxl.load_workbook(path, data_only=True, read_only=True)
    rows = [list(r) for r in wb.worksheets[0].iter_rows(values_only=True)]
    wb.close()
    hdr_i, blocks = find_blocks(rows)
    if not blocks:
        return []

    out = []
    for _, group in blocks:
        price_col = group[-1][0]          # the reference month
        year, month = group[-1][1]
        label_col = group[0][0] - 1
        if label_col < 0:
            continue
        product = block_product(rows, hdr_i, group[0][0], series)
        zone = None
        for row in rows[hdr_i + 1:]:
            if label_col >= len(row) or price_col >= len(row):
                continue
            label, price = row[label_col], row[price_col]
            if label is None:
                continue
            text = re.sub(r"\s+", " ", str(label)).strip()
            if not text or STOP.match(text):
                if STOP.match(text):
                    break
                continue
            if text.upper() in ZONES:
                zone = text.upper().title()
                continue
            if not isinstance(price, (int, float)):
                continue
            out.append({"product": product, "zone": zone or "", "state": norm_state(text),
                        "month": f"{year:04d}-{month:02d}-01", "price": round(float(price), 2),
                        "source_file": path.name})
    return out


def main():
    rows = []
    for series in ["pms", "ago", "nhk", "lpg"]:
        folder = EXTRACTED / series
        got = 0
        for f in sorted(folder.glob("*.xlsx")):
            try:
                r = parse_file(f, series)
            except Exception as e:
                print(f"  !! {f.name}: {e}", file=sys.stderr)
                continue
            rows.extend(r)
            got += len(r)
            if not r:
                print(f"  ?? no rows from {f.name}", file=sys.stderr)
        print(f"{series}: {got} rows")

    # Some sheets list states without zone headers. Backfill from the sheets
    # that do carry them, so every row lands in a zone.
    from collections import Counter
    tally = {}
    for r in rows:
        if r["zone"]:
            tally.setdefault(r["state"], Counter())[r["zone"]] += 1
    zone_of = {st: c.most_common(1)[0][0] for st, c in tally.items()}
    for st, c in tally.items():
        if len(c) > 1:
            print(f"  zone disagreement for {st}: {dict(c)} -> {zone_of[st]}", file=sys.stderr)
    missing = set()
    for r in rows:
        r["zone"] = zone_of.get(r["state"], r["zone"])
        if not r["zone"]:
            missing.add(r["state"])
    if missing:
        print("  no zone for:", sorted(missing), file=sys.stderr)

    # Overlapping files repeat months, so keep one price per key.
    seen, deduped = set(), []
    for r in rows:
        k = (r["product"], r["state"], r["month"])
        if k in seen:
            continue
        seen.add(k)
        deduped.append(r)

    OUT.mkdir(exist_ok=True)
    with open(OUT / "fuel_prices.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["product", "zone", "state", "month", "price", "source_file"])
        w.writeheader()
        w.writerows(sorted(deduped, key=lambda r: (r["product"], r["month"], r["state"])))
    print(f"\n{len(rows)} parsed, {len(deduped)} unique -> data/fuel_prices.csv")


if __name__ == "__main__":
    main()
