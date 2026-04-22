#!/usr/bin/env python3
"""
Fetch and convert the Free Exercise DB into Zuralog's exercises.json format.

Outputs:
  tools/exercises_output.json  — drop into zuralog/assets/data/exercises.json after review
  tools/exercises_review.csv   — open in Excel to review and annotate

Usage:
  pip install requests
  python tools/process_exercises.py
"""

import json
import csv
import re
import sys
import requests

SOURCE_URL = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db"
    "/main/dist/exercises.json"
)

EQUIPMENT_MAP = {
    "body only":     "bodyweight",
    "machine":       "machine",
    "dumbbell":      "dumbbell",
    "barbell":       "barbell",
    "kettlebells":   "kettlebell",
    "cable":         "cable",
    "bands":         "resistance_band",
    "e-z curl bar":  "ez_bar",
    "exercise ball": "other",
    "foam roll":     "other",
    "other":         "other",
}

MUSCLE_MAP = {
    "abdominals":            "abs",
    "hamstrings":            "hamstrings",
    "adductors":             "quads",
    "shoulders":             "shoulders",
    "biceps":                "biceps",
    "quadriceps":            "quads",
    "chest":                 "chest",
    "calves":                "calves",
    "glutes":                "glutes",
    "lower back":            "back",
    "middle back":           "back",
    "lats":                  "back",
    "triceps":               "triceps",
    "forearms":              "forearms",
    "traps":                 "back",
    "neck":                  "other",
    "cardiovascular system": "cardio",
}


def to_snake(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = re.sub(r"_+", "_", text)
    return text.strip("_")


def map_muscle(name: str) -> str:
    return MUSCLE_MAP.get(name.strip().lower(), "other")


def map_equipment(name) -> str:
    if name is None:
        return "other"
    return EQUIPMENT_MAP.get(name.strip().lower(), "other")


def main():
    print(f"Fetching {SOURCE_URL} ...")
    try:
        resp = requests.get(SOURCE_URL, timeout=30)
        resp.raise_for_status()
    except Exception as e:
        print(f"ERROR: Could not fetch dataset: {e}", file=sys.stderr)
        sys.exit(1)

    raw = resp.json()
    print(f"Fetched {len(raw)} raw exercises.")

    exercises = []
    seen_ids: set = set()

    for entry in raw:
        # Skip stretching — not relevant for workout logging
        if entry.get("category") == "stretching":
            continue

        exercise_id = to_snake(entry.get("id", ""))
        if not exercise_id or exercise_id in seen_ids:
            continue
        seen_ids.add(exercise_id)

        name = entry.get("name", "").strip()
        primary_raw = entry.get("primaryMuscles") or []
        secondary_raw = entry.get("secondaryMuscles") or []
        equipment_raw = entry.get("equipment")
        instructions_parts = entry.get("instructions") or []

        primary = map_muscle(primary_raw[0]) if primary_raw else "other"
        if entry.get("category") == "cardio":
            primary = "cardio"

        secondaries_mapped = [map_muscle(m) for m in secondary_raw]
        # Remove duplicates and entries that match the primary muscle
        secondaries = list(dict.fromkeys(
            m for m in secondaries_mapped if m != primary
        ))

        equipment = map_equipment(equipment_raw)
        instructions = " ".join(instructions_parts)

        exercises.append({
            "id": exercise_id,
            "name": name,
            "muscleGroup": primary,
            "secondaryMuscles": secondaries,
            "equipment": equipment,
            "instructions": instructions,
        })

    # Merge in existing exercises not covered by the source dataset.
    # This preserves curated entries like EZ-bar and cardio exercises.
    existing_path = "zuralog/assets/data/exercises.json"
    try:
        with open(existing_path, "r", encoding="utf-8") as f:
            existing = json.load(f)
        merged = 0
        for ex in existing:
            if ex.get("id") not in seen_ids:
                ex.setdefault("secondaryMuscles", [])
                exercises.append(ex)
                seen_ids.add(ex["id"])
                merged += 1
        print(f"Merged {merged} existing exercises not found in source.")
    except FileNotFoundError:
        print(f"Note: {existing_path} not found — skipping merge.")

    exercises.sort(key=lambda e: e["name"].lower())
    print(f"Total exercises: {len(exercises)}")

    # Write JSON
    out_json = "tools/exercises_output.json"
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(exercises, f, indent=2, ensure_ascii=False)
    print(f"Written: {out_json}")

    # Write CSV for Excel review
    out_csv = "tools/exercises_review.csv"
    fieldnames = [
        "id", "name", "muscleGroup", "secondaryMuscles",
        "equipment", "instructions", "imageStatus", "notes",
    ]
    with open(out_csv, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for ex in exercises:
            writer.writerow({
                "id": ex["id"],
                "name": ex["name"],
                "muscleGroup": ex["muscleGroup"],
                "secondaryMuscles": ", ".join(ex.get("secondaryMuscles", [])),
                "equipment": ex["equipment"],
                "instructions": ex["instructions"],
                "imageStatus": "pending",
                "notes": "",
            })
    print(f"Written: {out_csv}")
    print("\nNext steps:")
    print("  1. Open tools/exercises_review.csv in Excel to review.")
    print("  2. When satisfied, copy tools/exercises_output.json")
    print("     to zuralog/assets/data/exercises.json")


if __name__ == "__main__":
    main()
