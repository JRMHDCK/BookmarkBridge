#!/usr/bin/env python3
"""Run BookmarkBridge's complete, reusable quality-assurance platform."""

import argparse
import datetime
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from qa_support import QAError, generate_all_datasets, run_scenarios, validate_dataset


def command_output(command, root):
    result = subprocess.run(
        command,
        cwd=str(root),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def repository_metadata(root):
    project = (root / "BookmarkBridge.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    version_match = re.search(r"MARKETING_VERSION = ([^;]+);", project)
    build_match = re.search(r"CURRENT_PROJECT_VERSION = ([^;]+);", project)
    return {
        "commit": command_output(["git", "rev-parse", "HEAD"], root),
        "branch": command_output(["git", "branch", "--show-current"], root) or "(detached HEAD)",
        "version": version_match.group(1).strip() if version_match else "unknown",
        "build": build_match.group(1).strip() if build_match else "unknown",
    }


def changed_paths(root):
    tracked = command_output(["git", "diff", "--name-only", "HEAD"], root).splitlines()
    untracked = command_output(
        ["git", "ls-files", "--others", "--exclude-standard"],
        root,
    ).splitlines()
    return sorted(set(path for path in tracked + untracked if path))


def validate_change_scope(root):
    paths = changed_paths(root)
    violations = [path for path in paths if not path.startswith("QA/")]
    if violations:
        raise QAError(
            "QA scope guard rejected files outside QA/: {}".format(", ".join(violations))
        )
    return paths


def run_logged(name, command, root, log_directory):
    log_path = log_directory / "{}.log".format(name)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    print("\n==> {}".format(name))
    print("    {}".format(" ".join(command)))
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            command,
            cwd=str(root),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        assert process.stdout is not None
        for line in process.stdout:
            log.write(line)
            if (
                "** BUILD " in line
                or "** TEST " in line
                or "error:" in line.lower()
                or "warning:" in line.lower()
            ):
                print(line.rstrip())
        return_code = process.wait()
    duration = time.monotonic() - started
    status = "passed" if return_code == 0 else "failed"
    print("<== {}: {} ({:.1f}s)".format(name, status.upper(), duration))
    return {
        "name": name,
        "status": status,
        "duration_seconds": round(duration, 3),
        "command": command,
        "log": str(log_path),
        "return_code": return_code,
    }


def markdown_report(metadata, started_at, duration, dataset_results, scenario_results, validations, changed):
    passed = sum(1 for result in scenario_results if result["status"] == "passed")
    failed = len(scenario_results) - passed
    differences = [
        (result["id"], difference)
        for result in scenario_results
        for difference in result["differences"]
    ]
    lines = [
        "# BookmarkBridge QA Report",
        "",
        "- Date : `{}`".format(started_at.astimezone().isoformat(timespec="seconds")),
        "- Version : `{}` (build `{}`)".format(metadata["version"], metadata["build"]),
        "- Commit : `{}`".format(metadata["commit"]),
        "- Branche : `{}`".format(metadata["branch"]),
        "- Scénarios : `{}`".format(len(scenario_results)),
        "- Succès : `{}`".format(passed),
        "- Échecs : `{}`".format(failed),
        "- Temps total : `{:.3f} s`".format(duration),
        "",
        "## Datasets",
        "",
        "| Dataset | Favoris Safari | Favoris Chrome | Dossiers/navigateur | Round-trip |",
        "|---|---:|---:|---:|---|",
    ]
    for result in dataset_results:
        lines.append(
            "| {name} | {safari_bookmarks} | {chrome_bookmarks} | "
            "{folders_per_browser} | {roundtrip} |".format(
                roundtrip="OK" if result["roundtrip_valid"] else "ÉCHEC",
                **result
            )
        )
    lines.extend(
        [
            "",
            "## Scénarios",
            "",
            "| Scénario | Dataset | Statut | Durée |",
            "|---|---|---|---:|",
        ]
    )
    for result in scenario_results:
        lines.append(
            "| `{}` | {} | {} | {:.3f} s |".format(
                result["id"],
                result["dataset"],
                "OK" if result["status"] == "passed" else "ÉCHEC",
                result["duration_seconds"],
            )
        )
    lines.extend(
        [
            "",
            "## Validations",
            "",
            "| Validation | Statut | Durée | Journal |",
            "|---|---|---:|---|",
        ]
    )
    for result in validations:
        log_name = Path(result["log"]).name if result.get("log") else "—"
        lines.append(
            "| {} | {} | {:.3f} s | `{}` |".format(
                result["name"],
                result["status"].upper(),
                result["duration_seconds"],
                log_name,
            )
        )
    lines.extend(["", "## Écarts", ""])
    if differences:
        for scenario_id, difference in differences:
            lines.append("- `{}` : {}".format(scenario_id, difference))
    else:
        lines.append("Aucun écart détecté.")
    lines.extend(["", "## Contrôle de périmètre", ""])
    if changed:
        lines.append("Fichiers non commités observés au lancement :")
        lines.append("")
        lines.extend("- `{}`".format(path) for path in changed)
    else:
        lines.append("Aucun fichier non commité.")
    lines.extend(
        [
            "",
            "Le garde-fou a confirmé qu'aucun changement observé ne se trouvait hors de `QA/`.",
            "",
        ]
    )
    return "\n".join(lines)


def main():
    script_root = Path(__file__).resolve().parent
    qa_root = script_root.parent
    repository_root = qa_root.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scenario",
        action="append",
        help="Run only this declarative scenario (repeatable)",
    )
    parser.add_argument(
        "--qa-only",
        action="store_true",
        help="Generate datasets and run scenarios without Xcode builds/tests",
    )
    parser.add_argument(
        "--unit-only",
        action="store_true",
        help="Run unit tests but skip graphical UI tests",
    )
    parser.add_argument(
        "--keep-workdir",
        action="store_true",
        help="Keep generated datasets and Xcode DerivedData under QA/.work",
    )
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=qa_root / "Reports",
        help="Directory for ignored Markdown reports and logs",
    )
    args = parser.parse_args()
    if args.qa_only and args.unit_only:
        parser.error("--unit-only has no effect with --qa-only")

    started_at = datetime.datetime.now().astimezone()
    started = time.monotonic()
    metadata = repository_metadata(repository_root)
    report_directory = args.report_dir.resolve()
    report_directory.mkdir(parents=True, exist_ok=True)
    timestamp = started_at.strftime("%Y%m%d-%H%M%S")
    run_directory = report_directory / "{}-{}".format(timestamp, metadata["commit"][:8])
    log_directory = run_directory / "Logs"
    log_directory.mkdir(parents=True, exist_ok=True)
    report_path = run_directory / "report.md"
    result_path = run_directory / "results.json"
    changed = []
    dataset_results = []
    scenario_results = []
    validations = []
    temporary = None
    exit_code = 0

    try:
        changed = validate_change_scope(repository_root)
        if args.keep_workdir:
            work_root = qa_root / ".work"
            if work_root.exists():
                shutil.rmtree(str(work_root))
            work_root.mkdir(parents=True)
        else:
            temporary = tempfile.TemporaryDirectory(prefix="bookmarkbridge-qa-")
            work_root = Path(temporary.name)

        print("Generating deterministic datasets in {}".format(work_root / "Datasets"))
        generated = generate_all_datasets(qa_root / "Datasets", work_root / "Datasets")
        dataset_results = [validate_dataset(generated[name]) for name in sorted(generated)]
        for result in dataset_results:
            print(
                "  {name}: Safari={safari_bookmarks}, Chrome={chrome_bookmarks}, "
                "folders={folders_per_browser}, round-trip=OK".format(**result)
            )

        scenario_results = run_scenarios(
            qa_root / "Scenarios" / "catalog.json",
            generated,
            args.scenario,
        )
        for result in scenario_results:
            print(
                "[{}] {} ({:.3f}s)".format(
                    result["status"].upper(),
                    result["id"],
                    result["duration_seconds"],
                )
            )
            for difference in result["differences"]:
                print("  - {}".format(difference))
        if any(result["status"] == "failed" for result in scenario_results):
            exit_code = 1

        if not args.qa_only:
            common_build = [
                "xcodebuild",
                "build",
                "-project",
                "BookmarkBridge.xcodeproj",
                "-scheme",
                "BookmarkBridge",
                "-destination",
                "platform=macOS",
                "CODE_SIGNING_ALLOWED=NO",
            ]
            validations.append(
                run_logged(
                    "build-debug",
                    common_build
                    + [
                        "-configuration",
                        "Debug",
                        "-derivedDataPath",
                        str(work_root / "DerivedData" / "Debug"),
                    ],
                    repository_root,
                    log_directory,
                )
            )
            validations.append(
                run_logged(
                    "build-release",
                    common_build
                    + [
                        "-configuration",
                        "Release",
                        "-derivedDataPath",
                        str(work_root / "DerivedData" / "Release"),
                    ],
                    repository_root,
                    log_directory,
                )
            )
            validations.append(
                run_logged(
                    "unit-tests",
                    [
                        "xcodebuild",
                        "test",
                        "-project",
                        "BookmarkBridge.xcodeproj",
                        "-scheme",
                        "BookmarkBridge",
                        "-destination",
                        "platform=macOS",
                        "-only-testing:BookmarkBridgeTests",
                        "-derivedDataPath",
                        str(work_root / "DerivedData" / "Tests"),
                        "CODE_SIGNING_ALLOWED=NO",
                    ],
                    repository_root,
                    log_directory,
                )
            )
            if not args.unit_only:
                validations.append(
                    run_logged(
                        "ui-tests",
                        [
                            "xcodebuild",
                            "test",
                            "-project",
                            "BookmarkBridge.xcodeproj",
                            "-scheme",
                            "BookmarkBridge",
                            "-destination",
                            "platform=macOS",
                            "-only-testing:BookmarkBridgeUITests",
                            "-derivedDataPath",
                            str(work_root / "DerivedData" / "UITests"),
                        ],
                        repository_root,
                        log_directory,
                    )
                )
            if any(result["status"] == "failed" for result in validations):
                exit_code = 1
    except KeyboardInterrupt:
        exit_code = 130
        print("QA platform interrupted by user", file=sys.stderr)
        validations.append(
            {
                "name": "platform",
                "status": "failed",
                "duration_seconds": round(time.monotonic() - started, 3),
                "log": "",
                "error": "KeyboardInterrupt",
            }
        )
    except Exception as error:
        exit_code = 1
        print("QA platform failure: {}: {}".format(type(error).__name__, error), file=sys.stderr)
        validations.append(
            {
                "name": "platform",
                "status": "failed",
                "duration_seconds": round(time.monotonic() - started, 3),
                "log": "",
                "error": "{}: {}".format(type(error).__name__, error),
            }
        )
    finally:
        duration = time.monotonic() - started
        report = markdown_report(
            metadata,
            started_at,
            duration,
            dataset_results,
            scenario_results,
            validations,
            changed,
        )
        report_path.write_text(report, encoding="utf-8")
        result_path.write_text(
            json.dumps(
                {
                    "metadata": metadata,
                    "datasets": dataset_results,
                    "scenarios": scenario_results,
                    "validations": validations,
                    "duration_seconds": round(duration, 3),
                    "exit_code": exit_code,
                },
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        if temporary is not None:
            temporary.cleanup()
        print("\nQA report: {}".format(report_path))
        print("QA result: {}".format("PASSED" if exit_code == 0 else "FAILED"))
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
