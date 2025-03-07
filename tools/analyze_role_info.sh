#!/usr/bin/env bash
set -e

# @describe Analyze Role information from aichat using bash, if role_name not specified, get all roles using 'aichat --list-roles'.
# @option --role-name Optionally specify the role name to analyze.

# @env LLM_OUTPUT=/dev/stdout The output path

main() {
    if [ -n "$argc_role_name" ]; then
        aichat --role "$argc_role_name" --info >> "$LLM_OUTPUT"
    else
        aichat --list-roles | xargs -I {} bash "$0" --role-name "{}"
    fi
}

eval "$(argc --argc-eval "$0" "$@")"
