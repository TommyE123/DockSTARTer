#!/usr/bin/env bats

@test "prints Hello World" {
  run echo "Hello World"
  [ "$status" -eq 0 ]
  [ "$output" = "Hello World" ]
}
