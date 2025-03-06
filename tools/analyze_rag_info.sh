#!/usr/bin/env bash
set -e

# @describe Analyze RAG information from aichat for a given input string using bash.
# @option --input-string! The input string to analyze with aichat RAG.
# @meta require-tools aichat yq

# @env LLM_OUTPUT=/dev/stdout The output path

main() {
    aichat --rag "$argc_input_string" --info | \
    yq '. + {"files_count": .files | length} | del(.files)' >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
