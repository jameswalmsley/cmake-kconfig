#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

import sys
import os
import random
import time

# Add the directory containing this script to sys.path to allow importing kconfiglib
script_dir = os.path.dirname(os.path.realpath(__file__))
sys.path.append(script_dir)

import kconfiglib

def main():
    # Set up random seed
    seed = os.environ.get("KCONFIG_SEED")
    if seed:
        try:
            seed = int(seed)
        except ValueError:
            sys.exit(f"Invalid KCONFIG_SEED: {seed}")
    else:
        seed = int(time.time())

    random.seed(seed)
    print(f"KCONFIG_SEED={seed}")

    kconfig_file = sys.argv[1] if len(sys.argv) > 1 else "Kconfig"

    # We need to respect KCONFIG_CONFIG if set, or default to .config
    config_out = os.environ.get("KCONFIG_CONFIG", ".config")

    kconf = kconfiglib.Kconfig(kconfig_file)

    # Randomize symbols
    # kconfiglib.unique_defined_syms includes all defined symbols
    for sym in kconf.unique_defined_syms:
        # We generally only want to randomize bools and tristates.
        # Ints/Hex/Strings are harder to randomize meaningfully without more context,
        # but typically randconfig focuses on enabling/disabling features.

        if not sym.choice and sym.type in (kconfiglib.BOOL, kconfiglib.TRISTATE):
            # Calculate assignable values?
            # If we just pick random y/m/n, kconfiglib will enforce dependencies.
            # e.g. if we set y but it depends on something that is n, it will effectively be n.
            # However, we want to simulate user input.

            # For tristate, we have n, m, y. For bool, n, y.
            vals = ["n", "y"]
            if sym.type == kconfiglib.TRISTATE:
                vals.append("m")

            # Pick a random value.
            # In Linux randconfig, there's often probability tuning (e.g. 50% chance of y/m).
            # Here we do uniform random choice from valid types.
            val = random.choice(vals)

            # We set the user value. Kconfiglib calculates the actual value based on dependencies.
            sym.set_value(val)

    # Randomize choices
    for choice in kconf.unique_choices:
        # Choices are tricky. We want to pick one of the symbols to be selected.
        # Or if optional, maybe none.

        # Gather valid symbols for the choice
        syms = [s for s in choice.syms if s.type != kconfiglib.UNKNOWN]

        if not syms:
            continue

        # If choice is optional, we might want to have "no selection" as an option.
        options = list(syms)
        if choice.is_optional:
            options.append(None)

        selection = random.choice(options)

        if selection:
            # Setting a choice symbol to 'y' selects it.
            selection.set_value("y")
        else:
            # Deselect the choice (for optional choices)
            # Setting mode to n.
            choice.set_value("n")

    kconf.write_config(config_out)
    print(f"Configuration saved to '{config_out}'")

if __name__ == "__main__":
    main()
