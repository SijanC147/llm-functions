#!/usr/bin/env bash
set -e

# @describe Analyze RAG information from aichat using bash, if rag not specified, get all rags using 'aichat --list-rags'.
# @option --rag-name Represents the name of the rag to analyze, if not provided, execute the command once for each rag.

# @env LLM_OUTPUT=/dev/stdout The output path

main() {
    if [ -n "$argc_rag_name" ]; then
        aichat --rag "$argc_rag_name" --info | \
        yq '. + {"files_count": .files | length} | del(.files)' >> "$LLM_OUTPUT"
    else
        aichat --list-rags | xargs -I {} bash "$0" --rag-name "{}"
    fi
}

eval "$(argc --argc-eval "$0" "$@")"
