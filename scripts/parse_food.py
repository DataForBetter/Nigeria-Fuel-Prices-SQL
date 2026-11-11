"""Parse the NBS food price workbooks into one tidy table.

The second sheet of each workbook holds average prices by commodity across
the six geopolitical zones. The reference month comes from the third price
column on the first sheet.

Output: data/food_prices.csv with item, zone, month, price.
"""

import csv, re, sys
from datetime import datetime
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data"
ZONES = ["North Central", "North East", "North West",
         "South East", "South South", "South West"]
SKIP = re.compile(r"^(grand total|total|average|row labels)", re.I)


def parse_month(cell):
    if isinstance(cell, datetime):
        return cell.year, cell.month
    m = re.search(r"([A-Za-z]{3,9})[\s\-/]*(\d{2,4})", str(cell or ""))
    if not m:
        return None
    months = ["jan", "feb", "mar", "apr", "may", "jun",
              "jul", "aug", "sep", "oct", "nov", "dec"]
    name = m.group(1)[:3].lower()
    if name not in months:
        return None
    yr = int(m.group(2))
    return (yr + 2000 if yr < 100 else yr), months.index(name) + 1


def reference_month(wb, path):
    """Third 'Average of' column on sheet one is the reference month."""
    ws = wb.worksheets[0]
    for row in ws.iter_rows(min_row=1, max_row=6, values_only=True):
        found = [parse_month(c) for c in row]
        found = [f for f in found if f]
        if len(found) >= 3:
            return found[2]
    return parse_month(path.name)


def parse_file(path):
    wb = openpyxl.load_workbook(path, data_only=True, read_only=True)
    ym = reference_month(wb, path)
    if not ym:
        wb.close()
        return []
    year, month = ym
    if len(wb.worksheets) < 2:
        wb.close()
        return []
    rows = [list(r) for r in wb.worksheets[1].iter_rows(values_only=True)]
    wb.close()

    header_i = next((i for i, r in enumerate(rows[:6])
                     if sum(1 for c in r if str(c or "").strip().upper() in
                            [z.upper() for z in ZONES]) >= 4), None)
    if header_i is None:
        return []
    cols = {}
    for ci, c in enumerate(rows[header_i]):
        name = str(c or "").strip().upper()
        for z in ZONES:
            if name == z.upper():
                cols[z] = ci

    out = []
    for row in rows[header_i + 1:]:
        if not row or row[0] is None:
            continue
        item = re.sub(r"\s+", " ", str(row[0])).strip()
        if not item or SKIP.match(item):
            continue
        for zone, ci in cols.items():
            if ci < len(row) and isinstance(row[ci], (int, float)):
                out.append({"item": item, "zone": zone,
                            "month": f"{year:04d}-{month:02d}-01",
                            "price": round(float(row[ci]), 2),
                            "source_file": path.name})
    return out


def main():
    rows = []
    for f in sorted((ROOT / "extracted" / "food").glob("*.xlsx")):
        try:
            r = parse_file(f)
        except Exception as e:
            print(f"  !! {f.name}: {e}", file=sys.stderr)
            continue
        if not r:
            print(f"  ?? no rows from {f.name}", file=sys.stderr)
        rows.extend(r)

    seen, deduped = set(), []
    for r in rows:
        k = (r["item"], r["zone"], r["month"])
        if k in seen:
            continue
        seen.add(k)
        deduped.append(r)

    OUT.mkdir(exist_ok=True)
    with open(OUT / "food_prices.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["item", "zone", "month", "price", "source_file"])
        w.writeheader()
        w.writerows(sorted(deduped, key=lambda r: (r["month"], r["item"], r["zone"])))
    print(f"{len(rows)} parsed, {len(deduped)} unique -> data/food_prices.csv")


if __name__ == "__main__":
    main()
