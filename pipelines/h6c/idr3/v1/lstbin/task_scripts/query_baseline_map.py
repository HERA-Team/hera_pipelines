"""Look up one field for one baseline in baseline_map.yaml.

Usage:
    python query_baseline_map.py <yaml_path> <bl_str> <field>

Prints the field value on stdout. Exits with code 0 on success, with code 1
if the yaml file is missing, the baseline isn't in the map, or the requested
field is missing. Used by the do_*.sh task scripts to keep the bash terse.

Values are printed in a shell-friendly form:
    bool   -> "True" / "False"
    None   -> "None"
    int    -> decimal integer
    float  -> repr()
    str    -> the string
"""

import argparse
import os
import sys

import yaml


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("yaml_path")
    parser.add_argument("bl_str")
    parser.add_argument("field")
    args = parser.parse_args()

    if not os.path.isfile(args.yaml_path):
        print(f"ERROR: baseline_map.yaml not found at {args.yaml_path}", file=sys.stderr)
        sys.exit(1)

    with open(args.yaml_path) as f:
        data = yaml.safe_load(f)

    entry = data.get(args.bl_str)
    if entry is None:
        print(
            f"ERROR: baseline {args.bl_str!r} not in {args.yaml_path}",
            file=sys.stderr,
        )
        sys.exit(1)
    if args.field not in entry:
        print(
            f"ERROR: field {args.field!r} not found for baseline {args.bl_str!r}",
            file=sys.stderr,
        )
        sys.exit(1)

    value = entry[args.field]
    if isinstance(value, bool):
        print("True" if value else "False")
    elif value is None:
        print("None")
    else:
        print(value)


if __name__ == "__main__":
    main()
