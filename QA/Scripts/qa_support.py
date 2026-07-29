#!/usr/bin/env python3
"""Deterministic dataset generation and scenario oracle for BookmarkBridge QA."""

import copy
import json
import plistlib
import shutil
import time
import uuid
from collections import Counter
from pathlib import Path


SCHEMA_VERSION = 1
CHROME_DATE_ADDED = "13317004800000000"


class QAError(Exception):
    """An explicit QA platform validation failure."""


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")


def stable_identifier(seed, value):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "{}:{}".format(seed, value)))


def _folder_title(index, pathological):
    if pathological:
        special = [
            "Dossier",
            "Dossier",
            "Café et thé ☕️",
            "日本語の資料",
            "Résumé — Ω",
            "📚 Références",
            "Nom presque identique",
            "Nom presque identiqué",
        ]
        if index < len(special):
            return special[index]
    return "Folder {:04d}".format(index + 1)


def _make_folders(spec):
    count = spec["folder_count"]
    maximum_depth = spec["maximum_depth"]
    pathological = spec["pathological"]
    seed = spec["seed"]
    folders = []

    for index in range(count):
        if index == 0:
            parent_path = []
        elif pathological and index < maximum_depth:
            parent_path = folders[index - 1]["path"] + [folders[index - 1]["title"]]
        elif index < maximum_depth and index % 3 == 1:
            parent_path = folders[index - 1]["path"] + [folders[index - 1]["title"]]
        else:
            parent_index = max(0, (index - maximum_depth) % max(1, index))
            candidate = folders[parent_index]
            candidate_path = candidate["path"] + [candidate["title"]]
            parent_path = candidate_path[: max(0, maximum_depth - 1)]

        folders.append(
            {
                "id": stable_identifier(seed, "folder-{}".format(index)),
                "title": _folder_title(index, pathological),
                "path": parent_path,
                "revision": 1,
                "intentionally_empty": pathological and index % 17 == 0,
            }
        )
    return folders


def _bookmark(seed, identity, ordinal, folders, pathological, unique_side=None):
    usable_folders = [folder for folder in folders if not folder["intentionally_empty"]]
    folder = usable_folders[ordinal % len(usable_folders)]
    title = "Bookmark {:06d}".format(ordinal + 1)
    url = "https://dataset.qa.invalid/{}/item/{:06d}".format(seed, ordinal + 1)
    if unique_side:
        title = "{} [{}]".format(title, unique_side.capitalize())
        url += "?source={}".format(unique_side)

    if pathological:
        if ordinal == 0:
            title = "Café ☕️ 日本語 — Ω"
            url = "https://unicode.qa.invalid/café/日本語/☕️"
        elif ordinal == 1:
            title = "Emoji 🚀🧪🔐"
            url = "https://emoji.qa.invalid/🚀/🧪"
        elif ordinal in (2, 3):
            title = "Favori strictement identique"
            url = "https://duplicate.qa.invalid/same"
        elif ordinal == 4:
            title = "URL très longue"
            url = "https://long.qa.invalid/{}".format("segment-" * 700)
        elif ordinal == 5:
            title = "Nom presque identique"
        elif ordinal == 6:
            title = "Nom presque identiqué"

    return {
        "id": stable_identifier(seed, identity),
        "title": title,
        "url": url,
        "path": folder["path"] + [folder["title"]],
        "revision": 1,
    }


def generate_dataset(spec):
    if spec.get("schema_version") != SCHEMA_VERSION:
        raise QAError("Unsupported dataset schema in {}".format(spec.get("name", "<unknown>")))
    bookmark_count = spec["bookmark_count_per_browser"]
    shared_count = int(bookmark_count * spec["shared_ratio"])
    folders = _make_folders(spec)
    shared = [
        _bookmark(
            spec["seed"],
            "shared-{}".format(index),
            index,
            folders,
            spec["pathological"],
        )
        for index in range(shared_count)
    ]
    safari_unique = [
        _bookmark(
            spec["seed"],
            "safari-{}".format(index),
            shared_count + index,
            folders,
            spec["pathological"],
            "safari",
        )
        for index in range(bookmark_count - shared_count)
    ]
    chrome_unique = [
        _bookmark(
            spec["seed"],
            "chrome-{}".format(index),
            bookmark_count + index,
            folders,
            spec["pathological"],
            "chrome",
        )
        for index in range(bookmark_count - shared_count)
    ]
    return {
        "schema_version": SCHEMA_VERSION,
        "name": spec["name"],
        "generated_from": spec,
        "browsers": {
            "safari": {
                "folders": copy.deepcopy(folders),
                "bookmarks": shared + safari_unique,
            },
            "chrome": {
                "folders": copy.deepcopy(folders),
                "bookmarks": copy.deepcopy(shared) + chrome_unique,
            },
        },
    }


def _tree_nodes(browser_state):
    folders_by_path = {}
    for folder in sorted(browser_state["folders"], key=lambda item: (len(item["path"]), item["path"], item["id"])):
        full_path = tuple(folder["path"] + [folder["title"]])
        folders_by_path[full_path] = folder
    bookmarks_by_path = {}
    for bookmark in browser_state["bookmarks"]:
        bookmarks_by_path.setdefault(tuple(bookmark["path"]), []).append(bookmark)
    return folders_by_path, bookmarks_by_path


def _safari_folder(path, folders_by_path, bookmarks_by_path):
    folder = folders_by_path[path]
    children = []
    child_paths = sorted(
        candidate
        for candidate in folders_by_path
        if tuple(folders_by_path[candidate]["path"]) == path
    )
    for child_path in child_paths:
        children.append(_safari_folder(child_path, folders_by_path, bookmarks_by_path))
    for bookmark in sorted(bookmarks_by_path.get(path, []), key=lambda item: item["id"]):
        children.append(
            {
                "WebBookmarkType": "WebBookmarkTypeLeaf",
                "URLString": bookmark["url"],
                "URIDictionary": {"title": bookmark["title"]},
                "WebBookmarkUUID": bookmark["id"],
            }
        )
    return {
        "WebBookmarkType": "WebBookmarkTypeList",
        "Title": folder["title"],
        "WebBookmarkUUID": folder["id"],
        "Children": children,
    }


def safari_property_list(browser_state):
    folders_by_path, bookmarks_by_path = _tree_nodes(browser_state)
    children = []
    for path in sorted(path for path, folder in folders_by_path.items() if not folder["path"]):
        children.append(_safari_folder(path, folders_by_path, bookmarks_by_path))
    for bookmark in sorted(bookmarks_by_path.get((), []), key=lambda item: item["id"]):
        children.append(
            {
                "WebBookmarkType": "WebBookmarkTypeLeaf",
                "URLString": bookmark["url"],
                "URIDictionary": {"title": bookmark["title"]},
                "WebBookmarkUUID": bookmark["id"],
            }
        )
    return {
        "WebBookmarkType": "WebBookmarkTypeList",
        "Title": "",
        "WebBookmarkUUID": stable_identifier("bookmarkbridge-qa", "safari-root"),
        "WebBookmarkFileVersion": 1,
        "Children": [
            {
                "WebBookmarkType": "WebBookmarkTypeList",
                "Title": "BookmarksBar",
                "WebBookmarkUUID": stable_identifier("bookmarkbridge-qa", "safari-bar"),
                "Children": children,
            }
        ],
    }


def _chrome_folder(path, folders_by_path, bookmarks_by_path, id_counter):
    folder = folders_by_path[path]
    children = []
    child_paths = sorted(
        candidate
        for candidate in folders_by_path
        if tuple(folders_by_path[candidate]["path"]) == path
    )
    for child_path in child_paths:
        children.append(_chrome_folder(child_path, folders_by_path, bookmarks_by_path, id_counter))
    for bookmark in sorted(bookmarks_by_path.get(path, []), key=lambda item: item["id"]):
        id_counter[0] += 1
        children.append(
            {
                "type": "url",
                "id": str(id_counter[0]),
                "guid": bookmark["id"],
                "name": bookmark["title"],
                "url": bookmark["url"],
                "date_added": CHROME_DATE_ADDED,
            }
        )
    id_counter[0] += 1
    return {
        "type": "folder",
        "id": str(id_counter[0]),
        "guid": folder["id"],
        "name": folder["title"],
        "date_added": CHROME_DATE_ADDED,
        "date_modified": CHROME_DATE_ADDED,
        "children": children,
    }


def chrome_property_list(browser_state):
    folders_by_path, bookmarks_by_path = _tree_nodes(browser_state)
    counter = [10]
    children = []
    for path in sorted(path for path, folder in folders_by_path.items() if not folder["path"]):
        children.append(_chrome_folder(path, folders_by_path, bookmarks_by_path, counter))
    for bookmark in sorted(bookmarks_by_path.get((), []), key=lambda item: item["id"]):
        counter[0] += 1
        children.append(
            {
                "type": "url",
                "id": str(counter[0]),
                "guid": bookmark["id"],
                "name": bookmark["title"],
                "url": bookmark["url"],
                "date_added": CHROME_DATE_ADDED,
            }
        )

    def root(identifier, guid_seed, name, root_children):
        return {
            "type": "folder",
            "id": identifier,
            "guid": stable_identifier("bookmarkbridge-qa", guid_seed),
            "name": name,
            "date_added": CHROME_DATE_ADDED,
            "date_modified": CHROME_DATE_ADDED,
            "children": root_children,
        }

    return {
        "checksum": "00000000000000000000000000000000",
        "version": 1,
        "roots": {
            "bookmark_bar": root("1", "chrome-bar", "Bookmarks bar", children),
            "other": root("2", "chrome-other", "Other bookmarks", []),
            "synced": root("3", "chrome-synced", "Mobile bookmarks", []),
        },
    }


def write_dataset(dataset, destination):
    dataset_root = destination / dataset["name"]
    if dataset_root.exists():
        shutil.rmtree(str(dataset_root))
    safari_path = dataset_root / "Safari" / "Bookmarks.plist"
    chrome_path = dataset_root / "Chrome" / "Default" / "Bookmarks"
    canonical_path = dataset_root / "canonical.json"
    safari_path.parent.mkdir(parents=True, exist_ok=True)
    chrome_path.parent.mkdir(parents=True, exist_ok=True)
    with safari_path.open("wb") as handle:
        plistlib.dump(
            safari_property_list(dataset["browsers"]["safari"]),
            handle,
            fmt=plistlib.FMT_BINARY,
            sort_keys=False,
        )
    write_json(chrome_path, chrome_property_list(dataset["browsers"]["chrome"]))
    write_json(canonical_path, dataset)
    return dataset_root


def generate_all_datasets(definitions_root, output_root):
    generated = {}
    for spec_path in sorted(definitions_root.glob("*/dataset.json")):
        spec = load_json(spec_path)
        dataset = generate_dataset(spec)
        generated[dataset["name"]] = write_dataset(dataset, output_root)
    expected = {"Small", "Medium", "Large", "Extreme", "Pathological"}
    if set(generated) != expected:
        raise QAError("Dataset catalog mismatch: {}".format(sorted(generated)))
    return generated


def _extract_safari(state_path):
    with state_path.open("rb") as handle:
        root = plistlib.load(handle)
    bookmarks = []
    folders = []

    def visit(node, path, skip_container=False):
        node_type = node.get("WebBookmarkType")
        if node_type == "WebBookmarkTypeLeaf":
            bookmarks.append((node.get("URIDictionary", {}).get("title", ""), node.get("URLString", ""), tuple(path)))
            return
        if node_type != "WebBookmarkTypeList":
            return
        title = node.get("Title", "")
        next_path = list(path)
        if not skip_container and title:
            folders.append(tuple(path + [title]))
            next_path.append(title)
        for child in node.get("Children", []):
            visit(child, next_path)

    for child in root.get("Children", []):
        visit(child, [], child.get("Title") == "BookmarksBar")
    return Counter(bookmarks), Counter(folders)


def _extract_chrome(state_path):
    root = load_json(state_path)
    bookmarks = []
    folders = []

    def visit(node, path, skip_container=False):
        if node.get("type") == "url":
            bookmarks.append((node.get("name", ""), node.get("url", ""), tuple(path)))
            return
        if node.get("type") != "folder":
            return
        title = node.get("name", "")
        next_path = list(path)
        if not skip_container and title:
            folders.append(tuple(path + [title]))
            next_path.append(title)
        for child in node.get("children", []):
            visit(child, next_path)

    visit(root["roots"]["bookmark_bar"], [], True)
    return Counter(bookmarks), Counter(folders)


def _canonical_counters(browser_state):
    bookmarks = Counter(
        (item["title"], item["url"], tuple(item["path"]))
        for item in browser_state["bookmarks"]
    )
    folders = Counter(tuple(item["path"] + [item["title"]]) for item in browser_state["folders"])
    return bookmarks, folders


def validate_dataset(dataset_root):
    canonical = load_json(dataset_root / "canonical.json")
    safari_actual = _extract_safari(dataset_root / "Safari" / "Bookmarks.plist")
    chrome_actual = _extract_chrome(dataset_root / "Chrome" / "Default" / "Bookmarks")
    safari_expected = _canonical_counters(canonical["browsers"]["safari"])
    chrome_expected = _canonical_counters(canonical["browsers"]["chrome"])
    if safari_actual != safari_expected:
        raise QAError("{} Safari serialization mismatch".format(canonical["name"]))
    if chrome_actual != chrome_expected:
        raise QAError("{} Chrome serialization mismatch".format(canonical["name"]))
    return {
        "name": canonical["name"],
        "safari_bookmarks": len(canonical["browsers"]["safari"]["bookmarks"]),
        "chrome_bookmarks": len(canonical["browsers"]["chrome"]["bookmarks"]),
        "folders_per_browser": len(canonical["browsers"]["safari"]["folders"]),
        "roundtrip_valid": True,
    }


def _indexed(collection, index):
    ordered = sorted(collection, key=lambda item: item["id"])
    if not ordered:
        raise QAError("Scenario selector targets an empty collection")
    return ordered[index % len(ordered)]


def _state_signature(state):
    return json.dumps(state, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _record_map(state):
    records = {}
    for kind in ("folders", "bookmarks"):
        for item in state[kind]:
            records[(kind, item["id"])] = item
    return records


def _difference_count(before, after):
    left = _record_map(before)
    right = _record_map(after)
    keys = set(left) | set(right)
    return sum(1 for key in keys if left.get(key) != right.get(key))


class ScenarioMachine:
    def __init__(self, dataset_root):
        canonical = load_json(dataset_root / "canonical.json")
        self.dataset_root = dataset_root
        self.states = copy.deepcopy(canonical["browsers"])
        self.snapshots = {}
        self.metrics = {
            "sync_changes": [],
            "merge_changes": 0,
            "interruption_preserved_target": False,
            "rollback_restored": False,
            "dataset_roundtrip_valid": False,
            "pathological_coverage": False,
        }
        self.revision = max(
            item["revision"]
            for browser in self.states.values()
            for kind in ("folders", "bookmarks")
            for item in browser[kind]
        )

    def _next_revision(self):
        self.revision += 1
        return self.revision

    def _browser(self, step):
        browser = step["browser"]
        if browser not in self.states:
            raise QAError("Unknown browser '{}'".format(browser))
        return self.states[browser]

    def execute(self, step):
        action = step["action"]
        if action == "clear":
            state = self._browser(step)
            state["folders"] = []
            state["bookmarks"] = []
        elif action == "checkpoint":
            self.metrics["sync_changes"] = []
            self.metrics["merge_changes"] = 0
        elif action == "sync":
            source = self.states[step["source"]]
            target_name = step["target"]
            before = copy.deepcopy(self.states[target_name])
            if step["mode"] == "mirror":
                self.states[target_name] = copy.deepcopy(source)
            elif step["mode"] == "additive":
                target = self.states[target_name]
                for kind in ("folders", "bookmarks"):
                    existing = {item["id"] for item in target[kind]}
                    target[kind].extend(copy.deepcopy(item) for item in source[kind] if item["id"] not in existing)
            else:
                raise QAError("Unknown sync mode '{}'".format(step["mode"]))
            self.metrics["sync_changes"].append(_difference_count(before, self.states[target_name]))
        elif action == "rename_bookmark":
            item = _indexed(self._browser(step)["bookmarks"], step["index"])
            item["title"] += step["suffix"]
            item["revision"] = self._next_revision()
        elif action == "move_bookmark":
            state = self._browser(step)
            item = _indexed(state["bookmarks"], step["index"])
            folder = _indexed(state["folders"], step["folder_index"])
            item["path"] = folder["path"] + [folder["title"]]
            item["revision"] = self._next_revision()
        elif action == "delete_bookmark":
            state = self._browser(step)
            item = _indexed(state["bookmarks"], step["index"])
            state["bookmarks"] = [candidate for candidate in state["bookmarks"] if candidate["id"] != item["id"]]
        elif action == "create_bookmark":
            state = self._browser(step)
            folder = _indexed(state["folders"], step["folder_index"])
            state["bookmarks"].append(
                {
                    "id": stable_identifier("bookmarkbridge-qa-scenario", "{}:{}".format(step["browser"], step["url"])),
                    "title": step["title"],
                    "url": step["url"],
                    "path": folder["path"] + [folder["title"]],
                    "revision": self._next_revision(),
                }
            )
        elif action == "move_folder":
            state = self._browser(step)
            folder = _indexed(state["folders"], step["index"])
            target = _indexed(state["folders"], step["target_index"])
            old_full = folder["path"] + [folder["title"]]
            target_full = target["path"] + [target["title"]]
            if target_full[: len(old_full)] == old_full:
                target = min(state["folders"], key=lambda item: len(item["path"]))
                target_full = target["path"] + [target["title"]]
            new_parent = target_full
            self._replace_path_prefix(state, old_full, new_parent + [folder["title"]], folder["id"])
            folder["path"] = new_parent
            folder["revision"] = self._next_revision()
        elif action == "delete_folder":
            state = self._browser(step)
            folder = _indexed(state["folders"], step["index"])
            prefix = folder["path"] + [folder["title"]]
            state["folders"] = [
                candidate
                for candidate in state["folders"]
                if not self._belongs_to_folder(candidate["path"] + [candidate["title"]], prefix)
            ]
            state["bookmarks"] = [
                candidate for candidate in state["bookmarks"] if not self._belongs_to_folder(candidate["path"], prefix)
            ]
        elif action == "merge":
            before_safari = copy.deepcopy(self.states["safari"])
            before_chrome = copy.deepcopy(self.states["chrome"])
            merged = {"folders": [], "bookmarks": []}
            for kind in ("folders", "bookmarks"):
                candidates = {}
                for item in before_safari[kind] + before_chrome[kind]:
                    current = candidates.get(item["id"])
                    if current is None or item["revision"] > current["revision"]:
                        candidates[item["id"]] = copy.deepcopy(item)
                merged[kind] = sorted(candidates.values(), key=lambda item: item["id"])
            self.states["safari"] = copy.deepcopy(merged)
            self.states["chrome"] = copy.deepcopy(merged)
            self.metrics["merge_changes"] = (
                _difference_count(before_safari, merged) + _difference_count(before_chrome, merged)
            )
        elif action == "snapshot":
            key = (step["browser"], step["name"])
            self.snapshots[key] = copy.deepcopy(self._browser(step))
        elif action == "restore":
            key = (step["browser"], step["name"])
            if key not in self.snapshots:
                raise QAError("Missing snapshot '{}'".format(step["name"]))
            self.states[step["browser"]] = copy.deepcopy(self.snapshots[key])
            self.metrics["rollback_restored"] = (
                _state_signature(self.states[step["browser"]]) == _state_signature(self.snapshots[key])
            )
        elif action == "interrupt_sync":
            target = self.states[step["target"]]
            before = _state_signature(target)
            _staged = copy.deepcopy(self.states[step["source"]])
            self.metrics["interruption_preserved_target"] = before == _state_signature(target)
        elif action == "validate_dataset":
            validation = validate_dataset(self.dataset_root)
            self.metrics["dataset_roundtrip_valid"] = validation["roundtrip_valid"]
            canonical = load_json(self.dataset_root / "canonical.json")
            self.metrics["pathological_coverage"] = self._has_pathological_coverage(canonical)
        else:
            raise QAError("Unknown scenario action '{}'".format(action))

    @staticmethod
    def _belongs_to_folder(path, prefix):
        return path[: len(prefix)] == prefix

    @staticmethod
    def _replace_path_prefix(state, old_prefix, new_prefix, moved_folder_id):
        for folder in state["folders"]:
            if folder["id"] == moved_folder_id:
                continue
            full_path = folder["path"] + [folder["title"]]
            if full_path[: len(old_prefix)] == old_prefix:
                folder["path"] = new_prefix + folder["path"][len(old_prefix) :]
        for bookmark in state["bookmarks"]:
            if bookmark["path"][: len(old_prefix)] == old_prefix:
                bookmark["path"] = new_prefix + bookmark["path"][len(old_prefix) :]

    @staticmethod
    def _has_pathological_coverage(canonical):
        safari = canonical["browsers"]["safari"]
        titles = [item["title"] for item in safari["bookmarks"]]
        urls = [item["url"] for item in safari["bookmarks"]]
        folder_titles = [item["title"] for item in safari["folders"]]
        depths = [len(item["path"]) + 1 for item in safari["folders"]]
        pairs = Counter((item["title"], item["url"]) for item in safari["bookmarks"])
        return all(
            [
                max(depths) >= 30,
                max(len(url) for url in urls) >= 3000,
                any("☕️" in title or "🚀" in title for title in titles),
                any("日本語" in title for title in titles),
                any(count > 1 for count in pairs.values()),
                len(folder_titles) != len(set(folder_titles)),
                any(folder["intentionally_empty"] for folder in safari["folders"]),
            ]
        )

    def outcome(self):
        sync_changes = self.metrics["sync_changes"]
        return {
            "browsers_equal": _state_signature(self.states["safari"]) == _state_signature(self.states["chrome"]),
            "last_sync_changes": sync_changes[-1] if sync_changes else 0,
            "sync_changes": sync_changes,
            "nonzero_sync_count": sum(1 for value in sync_changes if value > 0),
            "merge_changes": self.metrics["merge_changes"],
            "interruption_preserved_target": self.metrics["interruption_preserved_target"],
            "rollback_restored": self.metrics["rollback_restored"],
            "dataset_roundtrip_valid": self.metrics["dataset_roundtrip_valid"],
            "pathological_coverage": self.metrics["pathological_coverage"],
        }


def _validate_expected(expected, outcome):
    differences = []
    for key, value in expected.items():
        if key == "last_sync_changes_minimum":
            actual = outcome["last_sync_changes"]
            if actual < value:
                differences.append("{} expected >= {}, got {}".format(key, value, actual))
        elif key == "merge_changes_minimum":
            actual = outcome["merge_changes"]
            if actual < value:
                differences.append("{} expected >= {}, got {}".format(key, value, actual))
        elif key == "nonzero_sync_count_minimum":
            actual = outcome["nonzero_sync_count"]
            if actual < value:
                differences.append("{} expected >= {}, got {}".format(key, value, actual))
        elif key == "sync_changes_sequence_minimum":
            actual = outcome["sync_changes"]
            if len(actual) != len(value) or any(
                actual_item < expected_item
                for actual_item, expected_item in zip(actual, value)
            ):
                differences.append("{} expected minima {}, got {}".format(key, value, actual))
        else:
            actual = outcome.get(key)
            if actual != value:
                differences.append("{} expected {!r}, got {!r}".format(key, value, actual))
    return differences


def run_scenarios(catalog_path, generated_roots, selected=None):
    catalog = load_json(catalog_path)
    if catalog.get("schema_version") != SCHEMA_VERSION:
        raise QAError("Unsupported scenario catalog schema")
    selected_ids = set(selected or [])
    known_ids = {scenario["id"] for scenario in catalog["scenarios"]}
    unknown = selected_ids - known_ids
    if unknown:
        raise QAError("Unknown scenario(s): {}".format(", ".join(sorted(unknown))))
    scenarios = [
        scenario
        for scenario in catalog["scenarios"]
        if not selected_ids or scenario["id"] in selected_ids
    ]
    results = []
    for scenario in scenarios:
        started = time.monotonic()
        differences = []
        outcome = {}
        try:
            machine = ScenarioMachine(generated_roots[scenario["dataset"]])
            for step in scenario["steps"]:
                machine.execute(step)
            outcome = machine.outcome()
            differences = _validate_expected(scenario["expected"], outcome)
        except Exception as error:
            differences = ["{}: {}".format(type(error).__name__, error)]
        results.append(
            {
                "id": scenario["id"],
                "name": scenario["name"],
                "objective": scenario["objective"],
                "dataset": scenario["dataset"],
                "status": "passed" if not differences else "failed",
                "duration_seconds": round(time.monotonic() - started, 3),
                "differences": differences,
                "outcome": outcome,
            }
        )
    return results
