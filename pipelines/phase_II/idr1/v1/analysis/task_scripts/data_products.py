#! /usr/bin/env python
"""Finds a night's files of each [DATA_PRODUCTS] entry in the toml, so that what happens to them once the night is
done -- bundled for cold storage, deleted, or kept -- is decided by each product's retention there, rather than by
lists written down again in do_CLEANUP.sh and operations/prune.sh.

A night's files of a product are found from its filename, relative to the night's folder, with {JD} the integer JD
and every other token ({ant1}, {source}, ...) a wildcard; or, for a product with only a suffix, as the per-sum-file
zen.{JD}.?????.{suffix}. No file may belong to two products, since then it would be bundled, kept, or deleted by
the wrong one's retention.

Every product in the night's folder -- everything this workflow writes, and the inputs linked into it (anything
with a suffix) -- says what becomes of it; inputs from elsewhere (a sky model, a catalog) don't.

usage (from the night's folder; the bash functions in _common.sh call these):
    data_products.py names TOML RETENTION            the products with that retention, after checking that every
                                                     product in the night's folder has one
    data_products.py files TOML JD PRODUCT           that product's files, one per line
    data_products.py undeclared TOML JD [GLOB ...]   files in the products' folders that no product (and no GLOB)
                                                     accounts for
"""
import argparse
import fnmatch
import os
import re
import sys

import toml

RETENTIONS = ('keep', 'archive', 'delete')


def load(toml_file):
    return toml.load(toml_file).get('DATA_PRODUCTS', {})


def in_night(spec):
    """Whether the product's files are in the night's folder: written by this workflow, or an input linked into it."""
    return bool(spec.get('produced_by')) or 'suffix' in spec


def check(products):
    """Every product in the night's folder says what becomes of it, and can be found; inputs from elsewhere don't."""
    problems = []
    for name, spec in products.items():
        if in_night(spec):
            if spec.get('retention') not in RETENTIONS:
                problems.append(f'{name} has retention = {spec.get("retention")!r}, not one of {", ".join(RETENTIONS)}')
            if 'filename' not in spec and 'suffix' not in spec:
                problems.append(f'{name} has neither a filename nor a suffix, so its files cannot be found')
            if not spec.get('produced_by') and spec.get('retention') == 'archive':
                problems.append(f'{name} is an input, linked into the night\'s folder, so it cannot be archived')
        elif 'retention' in spec:
            problems.append(f'{name} is an input from elsewhere, not in the night\'s folder, so it takes no retention')
    if problems:
        raise ValueError('[DATA_PRODUCTS] ' + '; '.join(problems))


def night_glob(spec, jd):
    """A night's files of the product, as a glob relative to the night's folder (None if they aren't in it)."""
    if spec.get('produced_by') and 'filename' in spec:
        return re.sub(r'\{(\w+)\}', lambda token: str(jd) if token.group(1) == 'JD' else '*', spec['filename'])
    if 'suffix' in spec:  # a per-sum-file product, or a raw input linked into the night's folder
        return f'zen.{jd}.?????.{spec["suffix"]}'
    return None  # an input from elsewhere: a sky model, a catalog, ...


def matches(path, pattern):
    """Whether a path relative to the night's folder matches a glob, as the shell would (* stays within a folder)."""
    folder, name = os.path.split(pattern)
    return os.path.dirname(path) == folder and fnmatch.fnmatchcase(os.path.basename(path), name)


def listing(folder, root='.'):
    """The files (not folders) in one folder under root, relative to root; none if there is no such folder."""
    try:
        with os.scandir(os.path.join(root, folder)) as entries:  # no stat per file: Lustre folders can be big
            return [os.path.join(folder, entry.name) for entry in entries
                    if not entry.is_dir(follow_symlinks=False) and not entry.name.startswith('.')]
    except FileNotFoundError:
        return []


def files(products, jd, name, root='.'):
    """A night's files of one product, sorted, checking that none of them also belongs to another product."""
    if name not in products:
        raise ValueError(f'there is no {name} in [DATA_PRODUCTS]')
    pattern = night_glob(products[name], jd)
    if pattern is None:
        raise ValueError(f'{name} has no files in the night\'s folder')
    found = sorted(path for path in listing(os.path.dirname(pattern), root) if matches(path, pattern))
    for other, spec in products.items():
        other_pattern = night_glob(spec, jd)
        if other == name or other_pattern is None:
            continue
        clash = [path for path in found if matches(path, other_pattern)]
        if clash:
            raise ValueError(f'{clash[0]} (and {len(clash) - 1} more) would be both {name} ({pattern}) and {other} '
                             f'({other_pattern}) in [DATA_PRODUCTS]')
    return found


def undeclared(products, jd, ignore=(), root='.'):
    """The files in the night's folder, and in any folder its products are in, that no product or ignore glob claims."""
    patterns = [pattern for pattern in (night_glob(spec, jd) for spec in products.values()) if pattern] + list(ignore)
    folders = sorted({os.path.dirname(pattern) for pattern in patterns} | {''})
    return sorted(path for folder in folders for path in listing(folder, root)
                  if not any(matches(path, pattern) for pattern in patterns))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    names = commands.add_parser('names')
    names.add_argument('toml_file')
    names.add_argument('retention', choices=RETENTIONS)
    for command in ('files', 'undeclared'):
        sub = commands.add_parser(command)
        sub.add_argument('toml_file')
        sub.add_argument('jd')
        if command == 'files':
            sub.add_argument('product')
        else:
            sub.add_argument('ignore', nargs='*')
    args = parser.parse_args(argv)

    products = load(args.toml_file)
    try:
        check(products)
        if args.command == 'names':
            found = [name for name, spec in products.items()
                     if in_night(spec) and spec['retention'] == args.retention]
        elif args.command == 'files':
            found = files(products, args.jd, args.product)
        else:
            found = undeclared(products, args.jd, args.ignore)
    except ValueError as error:
        sys.exit(f'ERROR: {error}')
    if found:
        print('\n'.join(found))


if __name__ == '__main__':
    main()
