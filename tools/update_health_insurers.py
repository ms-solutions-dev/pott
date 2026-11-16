#!/usr/bin/env python3
"""Updates the list of statutory health insurers and their additional contribution rates.

Source: the list the GKV-Spitzenverband publishes under § 242 (5) SGB V,
https://www.gkv-spitzenverband.de/service/krankenkassenliste/krankenkassen.jsp
It shows the rates valid on the day it is read, not the date a rate started.

Usage:
    python3 tools/update_health_insurers.py                 # reads the website, writes the current year
    python3 tools/update_health_insurers.py --year 2027     # file name / year of the output
    python3 tools/update_health_insurers.py --html-dir DIR  # parses saved pages DIR/p1.html … instead

Run it in the first week of January (new rates) and every quarter (changes during the year), then
run the TaxDE tests, which check the file. The app never fetches anything at runtime.

The averages (durchschnittlicher Zusatzbeitragssatz, § 242a SGB V) are set by the Federal Ministry
of Health and are kept from the existing file; add a new year by hand with its source.
"""
import argparse
import datetime
import glob
import html
import json
import os
import re
import sys
import urllib.request

SOURCE = "https://www.gkv-spitzenverband.de/service/krankenkassenliste/krankenkassen.jsp"
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Packages", "TaxDE", "Sources",
                       "TaxDE", "HealthInsurers")

STATES = {
    "Baden-Württemberg": "BW", "Bayern": "BY", "Berlin": "BE", "Brandenburg": "BB", "Bremen": "HB",
    "Hamburg": "HH", "Hessen": "HE", "Mecklenburg-Vorpommern": "MV", "Niedersachsen": "NI",
    "Nordrhein-Westfalen": "NW", "Rheinland-Pfalz": "RP", "Saarland": "SL", "Sachsen": "SN",
    "Sachsen-Anhalt": "ST", "Schleswig-Holstein": "SH", "Thüringen": "TH",
}

ROW = re.compile(
    r'<tr>\s*<th scope="row">(.*?)</th>\s*<td class="alignRight">(.*?)</td>\s*<td>(.*?)</td>', re.S)


def clean(text):
    text = html.unescape(re.sub(r"<[^>]+>", "", text)).replace("\xad", "")
    return re.sub(r"\s+", " ", text).strip()


def fetch(page):
    request = urllib.request.Request(f"{SOURCE}?pageNo={page}", headers={"User-Agent": "pott-tools/1"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def pages(html_dir):
    if html_dir:
        files = sorted(glob.glob(os.path.join(html_dir, "p*.html")), key=lambda f: int(re.sub(r"\D", "", os.path.basename(f))))
        for name in files:
            with open(name, encoding="utf-8") as f:
                yield f.read()
        return
    for page in range(1, 30):
        yield fetch(page)


def parse(html_dir):
    insurers, seen, as_of = [], set(), None
    for text in pages(html_dir):
        match = re.search(r"Stand: (\d{2})\.(\d{2})\.(\d{4})", text)
        if match and not as_of:
            as_of = f"{match.group(3)}-{match.group(2)}-{match.group(1)}"
        new = 0
        for cell_name, cell_rate, cell_region in ROW.findall(text):
            name = clean(cell_name)
            if name in seen:
                continue
            seen.add(name)
            new += 1
            link = re.search(r'href="([^"]*)"', cell_name)
            rate_text = clean(cell_rate)
            rate = None if "nicht" in rate_text or not re.search(r"\d", rate_text) else \
                float(rate_text.replace("%", "").replace(",", ".").strip())
            region = clean(cell_region)
            if region == "bundesweit":
                scope, states = "nationwide", []
            elif region.startswith("betriebsbezogen"):
                scope, states = "company", []
            elif region.startswith("branchenbezogen"):
                scope, states = "sector", []
            else:
                scope = "states"
                states = [STATES[s.strip()] for s in region.split(",")]
            insurers.append({
                "name": name, "additionalRate": rate, "scope": scope, "states": states,
                "homepage": link.group(1) if link else None,
            })
        if new == 0:
            break
    if not insurers:
        sys.exit("no insurers found – did the page layout change?")
    return insurers, as_of


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, default=datetime.date.today().year)
    parser.add_argument("--html-dir")
    parser.add_argument("--retrieved", default=datetime.date.today().isoformat())
    args = parser.parse_args()

    insurers, as_of = parse(args.html_dir)
    insurers.sort(key=lambda k: k["name"].casefold())
    path = os.path.normpath(os.path.join(OUT_DIR, f"health-insurers-{args.year}.json"))
    averages = {}
    for old in sorted(glob.glob(os.path.join(OUT_DIR, "health-insurers-*.json"))):
        with open(old, encoding="utf-8") as f:
            averages.update(json.load(f).get("averages", {}))
    data = {
        "year": args.year,
        "asOf": as_of or args.retrieved,
        "retrieved": args.retrieved,
        "source": SOURCE,
        "sourceNote": "GKV-Spitzenverband, list under § 242 (5) SGB V. Rates valid on asOf; the date a "
                      "rate started is not part of the source.",
        "averages": averages,
        "insurers": insurers,
    }
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    rates = [k["additionalRate"] for k in insurers if k["additionalRate"] is not None]
    print(f"{path}: {len(insurers)} insurers, {min(rates)}–{max(rates)} %, as of {data['asOf']}")


if __name__ == "__main__":
    main()
