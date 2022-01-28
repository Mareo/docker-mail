#!/usr/bin/env python3

import yaml
from copy import deepcopy

def open_defs(path):
    with open(path, "r") as f:
        return yaml.load(f, Loader=yaml.FullLoader)

def envconf(environ, defs, prefix, separator):
    prefix = prefix + "_"

    data = { f"{prefix}{k.upper()}": v for k, v in defs.items() }
    data.update(environ)
    exact_case = { k.lower(): k for k in defs }

    found = {}
    for key, value in data.items():
        if not key.startswith(prefix) or value is None:
            continue
        key = key[len(prefix):].lower()
        found[exact_case.get(key, key)] = value
    return "\n".join(f"{k} {separator} {v}" for k, v in found.items())


if __name__ == "__main__":
    from sys import argv, exit, stderr
    from os import environ

    if len(argv) < 4:
        print(f"Usage: {argv[0]} DEFS PREFIX SEPARATOR", file=stderr)
        exit(1)

    dpath, prefix, separator = argv[1:4]

    defs = open_defs(dpath)
    print(envconf(environ, defs, prefix, separator))
