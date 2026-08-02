#!/usr/bin/env python3
"""
Overturn Spy — bundle.py
Concatenates src/ modules in manifest order (bundle.json) into overturn.lua.

Usage:
    python scripts/bundle.py [--strip-returns] [--output PATH]

Options:
    --strip-returns    Remove bare "return X" lines at end of modules
    --output PATH      Override output path (default: overturn.lua from bundle.json)
"""

import json
import os
import re
import argparse
import sys

ROOT   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MFPATH = os.path.join(ROOT, "scripts", "bundle.json")


def load_manifest():
    with open(MFPATH, "r", encoding="utf-8") as f:
        return json.load(f)


def read_file(rel_path: str) -> str:
    abs_path = os.path.join(ROOT, rel_path.replace("/", os.sep))
    if not os.path.exists(abs_path):
        sys.exit(f"[bundle] ERROR: file not found: {abs_path}")
    with open(abs_path, "r", encoding="utf-8") as f:
        return f.read()


def strip_module_return(src: str) -> str:
    """Remove a bare 'return <table>' statement at the very end of a module."""
    # Match: optional whitespace, 'return', optional '{...}' or 'identifier'
    return re.sub(r"\n\s*return\s+\{[^}]*\}\s*$", "", src, flags=re.DOTALL)


def strip_module_return_simple(src: str) -> str:
    """Remove the last 'return X' line if it is the final non-blank line."""
    lines = src.rstrip().splitlines()
    if lines and re.match(r"^\s*return\s+\w", lines[-1]):
        lines = lines[:-1]
    return "\n".join(lines)


def build(strip_returns: bool, output_override: str | None = None):
    manifest = load_manifest()
    out_path  = os.path.join(ROOT, output_override or manifest.get("output", "overturn.lua"))
    parts     = []

    # Optional header file
    header_rel = manifest.get("header")
    if header_rel:
        header_abs = os.path.join(ROOT, header_rel.replace("/", os.sep))
        if os.path.exists(header_abs):
            parts.append(read_file(header_rel))
            parts.append("\n\n")

    do_strip = strip_returns or manifest.get("strip_module_returns", False)

    for rel in manifest["modules"]:
        src = read_file(rel)
        if do_strip:
            src = strip_module_return_simple(src)
        # Add a section divider comment
        section_name = os.path.splitext(os.path.basename(rel))[0]
        divider = f"\n-- {'─' * 74}\n-- § {section_name} ({rel})\n-- {'─' * 74}\n"
        parts.append(divider)
        parts.append(src.strip())
        parts.append("\n")

    combined = "\n".join(parts)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(combined)

    kb = len(combined.encode("utf-8")) / 1024
    print(f"[bundle] ✓  Written {out_path}  ({kb:.1f} KB, {len(manifest['modules'])} modules)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Bundle Overturn Spy modules into a single script")
    parser.add_argument("--strip-returns", action="store_true",
                        help="Strip bare 'return X' at end of each module")
    parser.add_argument("--output", metavar="PATH", default=None,
                        help="Override output file path")
    args = parser.parse_args()
    build(args.strip_returns, args.output)
