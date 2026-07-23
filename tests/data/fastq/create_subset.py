#!/usr/bin/env python3
"""Create the bounded HG002 paired-end FASTQ test fixture.

The source streams are closed as soon as the requested records have been read,
so running this script does not download either complete WGS FASTQ file.
"""

from __future__ import annotations

import argparse
import gzip
import os
from pathlib import Path
import sys
import urllib.request


SOURCE_R1 = (
    "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/"
    "AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/reads/"
    "D1_S1_L001_R1_004.fastq.gz"
)
SOURCE_R2 = (
    "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/"
    "AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/reads/"
    "D1_S1_L001_R2_004.fastq.gz"
)
DEFAULT_PAIRS = 50_000


def read_record(stream: gzip.GzipFile, mate: str, number: int) -> tuple[bytes, ...]:
    record = tuple(stream.readline() for _ in range(4))
    if any(not line for line in record):
        raise RuntimeError(f"{mate} ended within FASTQ record {number}")
    header, sequence, separator, quality = record
    if not header.startswith(b"@") or not separator.startswith(b"+"):
        raise RuntimeError(f"{mate} has malformed FASTQ record {number}")
    if len(sequence.rstrip(b"\r\n")) != len(quality.rstrip(b"\r\n")):
        raise RuntimeError(f"{mate} has unequal sequence/quality lengths at record {number}")
    return record


def read_name(header: bytes) -> bytes:
    name = header[1:].split(maxsplit=1)[0]
    if name.endswith((b"/1", b"/2")):
        name = name[:-2]
    return name


def create_subset(output_dir: Path, pairs: int) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    final_r1 = output_dir / "HG002_test_R1.fastq.gz"
    final_r2 = output_dir / "HG002_test_R2.fastq.gz"
    temp_r1 = final_r1.with_suffix(final_r1.suffix + ".tmp")
    temp_r2 = final_r2.with_suffix(final_r2.suffix + ".tmp")

    request_r1 = urllib.request.Request(SOURCE_R1, headers={"User-Agent": "ClinicalSuite-test-fixture/1"})
    request_r2 = urllib.request.Request(SOURCE_R2, headers={"User-Agent": "ClinicalSuite-test-fixture/1"})

    try:
        with (
            urllib.request.urlopen(request_r1, timeout=120) as response_r1,
            urllib.request.urlopen(request_r2, timeout=120) as response_r2,
            gzip.GzipFile(fileobj=response_r1, mode="rb") as input_r1,
            gzip.GzipFile(fileobj=response_r2, mode="rb") as input_r2,
            temp_r1.open("wb") as raw_r1,
            temp_r2.open("wb") as raw_r2,
            gzip.GzipFile(filename="", mode="wb", fileobj=raw_r1, mtime=0) as output_r1,
            gzip.GzipFile(filename="", mode="wb", fileobj=raw_r2, mtime=0) as output_r2,
        ):
            for number in range(1, pairs + 1):
                record_r1 = read_record(input_r1, "R1", number)
                record_r2 = read_record(input_r2, "R2", number)
                if read_name(record_r1[0]) != read_name(record_r2[0]):
                    raise RuntimeError(f"mate names differ at FASTQ record {number}")
                output_r1.writelines(record_r1)
                output_r2.writelines(record_r2)

        os.replace(temp_r1, final_r1)
        os.replace(temp_r2, final_r2)
    except BaseException:
        temp_r1.unlink(missing_ok=True)
        temp_r2.unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pairs", type=int, default=DEFAULT_PAIRS)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    if args.pairs < 1:
        parser.error("--pairs must be a positive integer")

    create_subset(args.output_dir, args.pairs)
    print(f"Created {args.pairs} paired reads in {args.output_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
