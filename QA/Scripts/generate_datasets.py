#!/usr/bin/env python3
"""Generate all anonymized BookmarkBridge QA datasets."""

import argparse
from pathlib import Path

from qa_support import generate_all_datasets, validate_dataset


def main():
    script_root = Path(__file__).resolve().parent
    qa_root = script_root.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=qa_root / ".work" / "Datasets",
        help="Generated dataset directory (default: QA/.work/Datasets)",
    )
    args = parser.parse_args()
    generated = generate_all_datasets(qa_root / "Datasets", args.output)
    for name, root in generated.items():
        validation = validate_dataset(root)
        print(
            "{name}: Safari={safari_bookmarks}, Chrome={chrome_bookmarks}, "
            "folders={folders_per_browser}, round-trip=OK".format(**validation)
        )


if __name__ == "__main__":
    main()
