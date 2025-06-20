#!/usr/bin/env python3
#
# Utility to generate from Hatari C-code Python code for mapping
# Hatari configuration variable names and types of those variables.
#
# Copyright (C) 2012-2025 by Eero Tamminen
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

import os, re, sys

# match first two items (variable name and type) from lines like:
# { "bConfirmQuit", Bool_Tag, &ConfigureParams.Log.bConfirmQuit }
reg = re.compile("\"([a-zA-Z0-9_]+)\",\\s*([BFIKS][a-z]+)_Tag\\s*,")

vartypes = {}
for line in sys.stdin.readlines():
    match = reg.search(line)
    if not match:
        continue
    key,value = match.groups()
    if key not in vartypes:
        vartypes[key] = value
        continue
    if vartypes[key] != value:
        print(f"ERROR: variable '{key}' already with type '{vartypes[key]}', not '{value}'!")
        sys.exit(1)

print(f"# content generated by {os.path.basename(sys.argv[0])}")
print("conftypes = {")
for key in sorted(vartypes.keys(), key=str.casefold):
    print(f"""    "{key}": "{vartypes[key]}",""")
print("}")
