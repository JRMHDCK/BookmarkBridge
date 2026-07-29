#!/usr/bin/env python3
"""Generate datasets and execute one or all declarative QA scenarios."""

import argparse
import tempfile
from pathlib import Path

from qa_support import generate_all_datasets, run_scenarios


def main():
    script_root = Path(__file__).resolve().parent
    qa_root = script_root.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", action="append", help="Scenario identifier; repeat to select several")
    parser.add_argument("--workdir", type=Path, help="Keep generated datasets in this directory")
    args = parser.parse_args()

    if args.workdir:
        work_root = args.workdir
        work_root.mkdir(parents=True, exist_ok=True)
        generated = generate_all_datasets(qa_root / "Datasets", work_root / "Datasets")
        results = run_scenarios(qa_root / "Scenarios" / "catalog.json", generated, args.scenario)
    else:
        with tempfile.TemporaryDirectory(prefix="bookmarkbridge-qa-") as temporary:
            generated = generate_all_datasets(qa_root / "Datasets", Path(temporary) / "Datasets")
            results = run_scenarios(qa_root / "Scenarios" / "catalog.json", generated, args.scenario)

    for result in results:
        print("[{}] {} ({:.3f}s)".format(result["status"].upper(), result["id"], result["duration_seconds"]))
        for difference in result["differences"]:
            print("  - {}".format(difference))
    if any(result["status"] == "failed" for result in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
