#!/usr/bin/env bats
# vim: ft=sh:sw=2:et


# Variables
load helpers

# @test "CLIENT: List his existing keys" {
#     run cassh status
#     [ "${status}" -eq 0 ]
# }

# @test "CLIENT: Add client's key into server" {
#     run cassh add
#     [ "${status}" -eq 0 ]
# }

# @test "ADMIN: Active key" {
#     run cassh admin user active
#     [ "${status}" -eq 0 ]
# }

# @test "CLIENT: Sign the key" {
#     run cassh sign
#     [ "${status}" -eq 0 ]
# }