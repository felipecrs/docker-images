# shellcheck shell=bash

if [[ $# -eq 0 ]]; then
    # If JENKINS_AGENT_NAME is preset, assume we are running as a Kubernetes Pod template agent
    if [[ -n "${JENKINS_AGENT_NAME:-}" ]]; then
        set -- jenkins-agent
    fi
fi
