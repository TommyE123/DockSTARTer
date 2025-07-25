# Bats Test Guide

This folder contains Bats Core tests for DockSTARTer scripts.

## How to Add a Test

1. **Create a new test file**
   Name it `<scriptname>.bats` (e.g., `request_reboot.bats`).

2. **Write your test**
   Example:

   ```bash
   @test "request_reboot prints reboot notice" {
     run bash ../../.scripts/request_reboot.sh
     [ "$status" -eq 0 ]
     [[ "$output" == *"reboot"* ]]
   }
   ```

3. **Run all tests**
   From this directory, run:

   ```sh
   bats .
   ```

## Tips

- Each test file should start with `#!/usr/bin/env bats`.
- Use `run` to execute scripts and check their output.
- See [Bats documentation](https://github.com/bats-core/bats-core)
