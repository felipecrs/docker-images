#!/bin/bash
# This wraps jenkins-agent in order to work around https://issues.jenkins.io/browse/JENKINS-67062
# It should be used with the retry command preceding it

set -euo pipefail

jenkins_agent() {
    local logs_file
    logs_file="$(mktemp --dry-run)"

    local exit_code

    if jenkins-agent "$@" 2>&1 | tee "${logs_file}"; then
        if grep -q "java.lang.NoClassDefFoundError: jenkins/slaves/restarter/JnlpSlaveRestarterInstaller" "${logs_file}"; then
            exit_code=65
        else
            exit_code=0
        fi
    else
        exit_code=$?
    fi

    rm -f "$logs_file"
    return $exit_code
}

readonly delay=5

for attempt in $(seq 1 5); do
    if jenkins_agent "$@"; then
        exit_code=0
        break
    else
        exit_code=$?
        if [[ $exit_code -eq 65 ]]; then
            echo "The jenkins-agent seems to have failed due to JENKINS-67062, retrying in ${delay} seconds... (attempt number ${attempt})" >&2
            sleep $delay
        else
            break
        fi
    fi
done

exit ${exit_code}
