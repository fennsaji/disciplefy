#!/usr/bin/env python3
"""Build the self-hosted Bible text files served by rs-backend.

Downloads the USFM archives from eBible.org and converts them into one
tab-separated file per translation under rs-backend/data/bible/:

    #name<TAB>USFM<TAB>Localized book name     (one per book, canonical order)
    USFM<TAB>chapter<TAB>verse<TAB>text        (verse may be a span, e.g. "24-25")

Only canonical verse text is kept: footnotes, cross references, Strong's
numbers, headings, introductions and the Hindi inline cross-reference
parentheses are removed.

Usage:  python3 rs-backend/scripts/build_bible_data.py [--cache DIR]
Requires only the Python 3 standard library.
"""

import argparse
import io
import os
import re
import sys
import urllib.request
import zipfile

# Output id -> eBible.org translation id
TRANSLATIONS = {
    "bsb": "engbsb",
    "kjv": "eng-kjv2006",
    "irv-hi": "hin2017",
    "irv-ml": "mal",
    "sv-ml": "mal2015",
}

BOOKS = (
    "GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA "
    "PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC "
    "MAL MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM "
    "HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV"
).split()

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "bible")

# Character spans removed together with their content.
DROP_SPANS = re.compile(r"\\(f|fe|x|bdit|rq|fig)\s.*?\\\1\*", re.S)
# Paragraph-level markers whose whole line is not verse text.
DROP_LINE = re.compile(
    r"^\\(id|ide|h|toc\d|mt\d?|mte\d?|ms\d?|mr|s\d?|sr|r|d|sp|cl|cp|rem|"
    r"is\d?|ip|ipi|im|io\d?|iot|ili\d?|ie|iex|imt\d?|sts|usfm)\b"
)
WORD_ATTRS = re.compile(r"\|[^\\]*?(?=\\\+?w\*)")
# Paragraph/poetry markers separate words; character markers do not.
PARA_MARKER = re.compile(r"\\(p|m|nb|b|pc|pr|pmo|pmc|pmr|pi\d?|mi|li\d?|q\d?|qr|qc|qa|qm\d?)(?![a-z*])\d*")
ANY_MARKER = re.compile(r"\\\+?[a-z]+\d*\*?")


def fetch(ebible_id, cache):
    path = os.path.join(cache, f"{ebible_id}_usfm.zip")
    if not os.path.exists(path):
        url = f"https://ebible.org/Scriptures/{ebible_id}_usfm.zip"
        print(f"downloading {url}", file=sys.stderr)
        with urllib.request.urlopen(url) as r, open(path, "wb") as f:
            f.write(r.read())
    return zipfile.ZipFile(path)


def clean(text):
    # A removed note takes the space before it along, so "word \\f ...\\f*," stays "word,".
    text = re.sub(r"\s*\x00", "", DROP_SPANS.sub("\x00", text))
    text = WORD_ATTRS.sub("", text)
    text = PARA_MARKER.sub(" ", text)
    text = ANY_MARKER.sub("", text)
    text = text.replace("~", "\u00a0").replace("\u00b6", " ")
    return re.sub(r"\s+", " ", text).strip()


def parse_book(usfm):
    """Returns (book_code, name, [(chapter, verse_label, text)])."""
    code, name, verses = None, None, []
    chapter, label, buf = 0, None, []

    def flush():
        if label is not None:
            t = clean(" ".join(buf))
            if t:
                verses.append((chapter, label, t))

    # Join everything so that spans crossing line ends are handled; keep line
    # starts so heading lines can be dropped.
    kept = []
    for line in usfm.splitlines():
        s = line.strip()
        if s.startswith("\\id "):
            code = s.split()[1]
        elif s.startswith("\\h "):
            name = s[3:].strip()
        if DROP_LINE.match(s):
            continue
        kept.append(s)
    body = DROP_SPANS.sub("\x00", "\n".join(kept))

    for tok in re.split(r"(\\c\s+\d+|\\v\s+[\d\-]+[a-z]?)", body):
        m = re.match(r"\\c\s+(\d+)", tok)
        if m:
            flush()
            chapter, label, buf = int(m.group(1)), None, []
            continue
        m = re.match(r"\\v\s+([\d\-]+)", tok)
        if m:
            flush()
            label, buf = m.group(1), []
            continue
        if label is not None:
            buf.append(tok)
    flush()
    return code, name, verses


def build(out_id, ebible_id, cache):
    z = fetch(ebible_id, cache)
    books = {}
    for n in z.namelist():
        if n.endswith(".usfm") or n.endswith(".SFM"):
            code, name, verses = parse_book(z.read(n).decode("utf-8-sig"))
            if code in BOOKS:
                books[code] = (name or code, verses)
    missing = [b for b in BOOKS if b not in books]
    if missing:
        raise SystemExit(f"{out_id}: missing books {missing}")
    out = io.StringIO()
    total = 0
    for b in BOOKS:
        out.write(f"#name\t{b}\t{books[b][0]}\n")
    for b in BOOKS:
        for c, v, t in books[b][1]:
            out.write(f"{b}\t{c}\t{v}\t{t}\n")
            total += 1
    with open(os.path.join(OUT_DIR, f"{out_id}.tsv"), "w", encoding="utf-8") as f:
        f.write(out.getvalue())
    print(f"{out_id} ({ebible_id}): {total} verse rows")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=os.environ.get("TMPDIR", "/tmp"))
    args = ap.parse_args()
    os.makedirs(OUT_DIR, exist_ok=True)
    for out_id, ebible_id in TRANSLATIONS.items():
        build(out_id, ebible_id, args.cache)


if __name__ == "__main__":
    main()
