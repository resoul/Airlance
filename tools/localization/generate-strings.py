#!/usr/bin/env python3
"""Generates typed Swift accessors for Localizable.strings.

Every language must have the same keys and the same placeholders as the base
language, otherwise generation fails and so does the build.
"""

import argparse
import os
import re
import sys

ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.MULTILINE)
COMMENTS = re.compile(r'/\*.*?\*/|//[^\n]*', re.DOTALL)
PLACEHOLDER = re.compile(r'%(?:\d+\$)?(@|d|ld|lld|f)')
SWIFT_TYPES = {"@": "String", "d": "Int", "ld": "Int", "lld": "Int", "f": "Double"}


def fail(message):
    print(f"generate-strings: {message}", file=sys.stderr)
    sys.exit(1)


def language_of(path):
    directory = os.path.basename(os.path.dirname(path))
    if not directory.endswith(".lproj"):
        fail(f"{path} is not inside an .lproj directory")
    return directory[: -len(".lproj")]


def parse(path):
    with open(path, encoding="utf-8") as file:
        text = COMMENTS.sub("", file.read())
    entries = {}
    for key, value in ENTRY.findall(text):
        if key in entries:
            fail(f"{path}: duplicate key {key}")
        entries[key] = value
    return entries


def placeholders(value):
    return [SWIFT_TYPES[match] for match in PLACEHOLDER.findall(value)]


def identifier(key):
    parts = [part for part in re.split(r"[._\-\s]+", key) if part]
    if not parts:
        fail(f"key {key!r} has no name")
    name = parts[0][0].lower() + parts[0][1:] + "".join(part[0].upper() + part[1:] for part in parts[1:])
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
        fail(f"key {key!r} doesn't make a Swift name")
    return name


def validate(tables, base):
    base_entries = tables[base]
    for language, entries in tables.items():
        missing = sorted(base_entries.keys() - entries.keys())
        extra = sorted(entries.keys() - base_entries.keys())
        if missing:
            fail(f"{language} is missing keys: {', '.join(missing)}")
        if extra:
            fail(f"{language} has keys missing in {base}: {', '.join(extra)}")
        for key, value in entries.items():
            if placeholders(value) != placeholders(base_entries[key]):
                fail(f"{language}: placeholders of {key} differ from {base}")


def accessor(key, value):
    name = identifier(key)
    types = placeholders(value)
    if not types:
        return [
            f"    var {name}: String {{",
            f'        pack.string("{key}")',
            "    }",
        ]

    parameters = ", ".join(f"_ value{index}: {kind}" for index, kind in enumerate(types, start=1))
    arguments = ", ".join(f"value{index}" for index in range(1, len(types) + 1))
    return [
        f"    func {name}({parameters}) -> String {{",
        f'        pack.format("{key}", {arguments})',
        "    }",
    ]


def generate(entries):
    lines = [
        "import Localization",
        "",
        "final class AppStrings: Sendable {",
        "    let pack: LanguagePack",
        "",
        "    init(pack: LanguagePack) {",
        "        self.pack = pack",
        "    }",
    ]
    names = set()
    for key in sorted(entries):
        name = identifier(key)
        if name in names:
            fail(f"several keys make the name {name}")
        names.add(name)
        lines.append("")
        lines.extend(accessor(key, entries[key]))
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("files", nargs="+")
    arguments = parser.parse_args()

    tables = {}
    for path in arguments.files:
        if not path.endswith(".strings"):
            continue
        tables[language_of(path)] = parse(path)

    if arguments.base not in tables:
        fail(f"no strings for the base language {arguments.base}")

    validate(tables, arguments.base)

    with open(arguments.output, "w", encoding="utf-8") as file:
        file.write(generate(tables[arguments.base]))


if __name__ == "__main__":
    main()
