#!/usr/bin/env bash

TASK_PATH="$1"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Add mocks to the beginning of task step script
# Our task has 5 steps: process-helm-charts is at index 2
yq -i '.spec.steps[2].script = load_str("'$SCRIPT_DIR'/mocks.sh") + .spec.steps[2].script' "$TASK_PATH" 
