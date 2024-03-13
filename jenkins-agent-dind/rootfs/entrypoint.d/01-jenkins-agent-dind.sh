# shellcheck shell=bash

if [[ $# -eq 0 ]]; then
    # If JENKINS_URL is preset, assume we are running as a Kubernetes Pod template agent
    if [[ -n "${JENKINS_URL:-}" ]]; then
        set -- jenkins-agent
    fi
fi
