#!/usr/bin/env bash
set -o errexit -o pipefail -o posix

# Copyright (c) 2019-2024 Cosmin Truta.
#
# Use, modification and distribution are subject to the MIT License.
# Please see the accompanying file LICENSE_MIT.txt
#
# SPDX-License-Identifier: MIT

# shellcheck source=ci/lib/ci.lib.sh
source "$(dirname "$0")/lib/ci.lib.sh"
cd "$CI_TOPLEVEL_DIR"

# Initialize the global constants CI_{...}{CHECK,CHECKER,LINT}.
CI_SHELLCHECK="${CI_SHELLCHECK:-shellcheck}"
CI_EDITORCONFIG_CHECKER="${CI_EDITORCONFIG_CHECKER:-editorconfig-checker}"
CI_YAMLLINT="${CI_YAMLLINT:-yamllint}"

# Initialize the global lint counter.
CI_LINT_COUNTER=0

function ci_init_lint {
    ci_info "## START OF LINTING ##"
    local my_program
    # Complete the initialization of CI_SHELLCHECK.
    # Set it to the empty string if the shellcheck program is unavailable.
    my_program="$(command -v "$CI_SHELLCHECK")" || {
        ci_warn "program not found: '$CI_SHELLCHECK'"
    }
    CI_SHELLCHECK="$my_program"
    # Complete the initialization of CI_EDITORCONFIG_CHECKER.
    # Set it to the empty string if the editorconfig-checker program is unavailable.
    my_program="$(command -v "$CI_EDITORCONFIG_CHECKER")" || {
        ci_warn "program not found: '$CI_EDITORCONFIG_CHECKER'"
    }
    CI_EDITORCONFIG_CHECKER="$my_program"
    # Complete the initialization of CI_YAMLLINT.
    # Set it to the empty string if the yamllint program is unavailable.
    my_program="$(command -v "$CI_YAMLLINT")" || {
        ci_warn "program not found: '$CI_YAMLLINT'"
    }
    CI_YAMLLINT="$my_program"
}

function ci_finish_lint {
    ci_info "## END OF LINTING ##"
    if [[ $CI_LINT_COUNTER -eq 0 ]]
    then
        ci_info "## SUCCESS ##"
        return 0
    else
        ci_info "linting failed"
        return 1
    fi
}

function ci_lint_ci_scripts {
    [[ -x $CI_SHELLCHECK ]] || {
        ci_warn "## NOT LINTING: CI scripts ##"
        return 0
    }
    ci_info "## LINTING: CI scripts ##"
    {
        local my_file
        ci_spawn "$CI_SHELLCHECK" --version
        find ./ci -maxdepth 1 -name "*.sh" |
            while IFS="" read -r my_file
            do
                ci_spawn "$CI_SHELLCHECK" -x "$my_file"
            done
    } || CI_LINT_COUNTER=$((CI_LINT_COUNTER + 1))
}

function ci_lint_text_files {
    [[ -x $CI_EDITORCONFIG_CHECKER ]] || {
        ci_warn "## NOT LINTING: text files ##"
        return 0
    }
    ci_info "## LINTING: text files ##"
    ci_spawn "$CI_EDITORCONFIG_CHECKER" --version
    ci_spawn "$CI_EDITORCONFIG_CHECKER" || {
        CI_LINT_COUNTER=$((CI_LINT_COUNTER + 1))
    }
}

function ci_lint_yaml_files {
    [[ -x $CI_YAMLLINT ]] || {
        ci_warn "## NOT LINTING: YAML files ##"
        return 0
    }
    ci_info "## LINTING: YAML files ##"
    {
        local my_file
        ci_spawn "$CI_YAMLLINT" --version
        find . \( -iname "*.yml" -o -iname "*.yaml" \) -not -path "./out/*" |
            while IFS="" read -r my_file
            do
                ci_spawn "$CI_YAMLLINT" --strict "$my_file"
            done
    } || CI_LINT_COUNTER=$((CI_LINT_COUNTER + 1))
}

function ci_lint {
    ci_init_lint
    ci_lint_ci_scripts
    ci_lint_text_files
    ci_lint_yaml_files
    # TODO: ci_lint_png_files, etc.
    ci_finish_lint
}

function usage {
    echo "usage: $CI_SCRIPT_NAME [<options>]"
    echo "options: -?|-h|--help"
    exit "${@:-0}"
}

function main {
    local opt
    while getopts ":" opt
    do
        # This ain't a while-loop. It only pretends to be.
        [[ $1 == -[?h]* || $1 == --help || $1 == --help=* ]] && usage 0
        ci_err "unknown option: '$1'"
    done
    shift $((OPTIND - 1))
    [[ $# -eq 0 ]] || {
        echo >&2 "error: unexpected argument: '$1'"
        usage 2
    }
    # And... go!
    ci_lint
}

main "$@"
