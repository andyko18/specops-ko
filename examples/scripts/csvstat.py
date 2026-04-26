#!/usr/bin/env python3
import csv
import io
import os
import sys


def usage():
    sys.stderr.write("Usage: csvstat.py [FILE]\n       cat FILE | csvstat.py\n")


def analyze(text_io):
    reader = csv.DictReader(text_io)
    headers = list(reader.fieldnames) if reader.fieldnames else []
    counts = {h: set() for h in headers}
    rows = 0
    for row in reader:
        for h in headers:
            counts[h].add(row.get(h, ""))
        rows += 1
    return rows, headers, counts


def print_stats(rows, headers, counts):
    print(f"rows: {rows}")
    print(f"columns: {len(headers)}")
    for h in headers:
        print(f"{h}: {len(counts[h])} unique")


def main():
    if len(sys.argv) > 1:
        path = sys.argv[1]
        if not os.path.exists(path):
            sys.stderr.write(f"Error: file not found: {path}\n")
            sys.exit(1)
        with open(path, newline="") as f:
            rows, headers, counts = analyze(f)
    elif not sys.stdin.isatty():
        content = sys.stdin.read()
        if not content.strip():
            usage()
            sys.exit(1)
        rows, headers, counts = analyze(io.StringIO(content))
    else:
        usage()
        sys.exit(1)
    print_stats(rows, headers, counts)


if __name__ == "__main__":
    main()
