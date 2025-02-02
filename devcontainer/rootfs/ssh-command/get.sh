#!/bin/bash

# This script outputs the ssh command to connect to the container

set -euo pipefail

function log_color() {
    color_code="$1"
    shift

    printf "\033[${color_code}m%s\033[0m\n" "$*" >&2
}

function log_red() {
    log_color "0;31" "$@"
}

function log_blue() {
    log_color "0;34" "$@"
}

function log_yellow() {
    log_color "1;33" "$@"
}

function log_task() {
    log_blue "🔃" "$@"
}

function log_manual_action() {
    log_red "⚠️" "$@"
}

function log_c() {
    log_yellow "👉" "$@"
}

function log_info() {
    log_blue "ℹ️" "$@"
}

function log_tip() {
    log_blue "💡" "$@"
}

function log_error() {
    log_red "❌" "$@"
}

function error() {
    log_error "$@"
    exit 1
}

function handle_exit() {
    if [[ "$?" -ne 0 && "${IGNORE_FAILURE:-true}" == true ]]; then
        log_manual_action "Exiting with success code as this step is not very important, but if you need the SSH command, check the logs for the possible root cause."
        exit 0
    fi
}

trap handle_exit EXIT

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
readonly script_dir

readonly podinfo_dir="${script_dir}/podinfo"

if [[ -d "${podinfo_dir}" ]]; then
    readonly as_pod="true"
else
    log_info "Assuming not running as a pod, because the '${podinfo_dir}' was not found."
    readonly as_pod="false"
fi

if [[ "${as_pod}" == "false" ]]; then
    readonly node_host="${NODE_NAME:-}"
    if [[ -z "${node_host}" ]]; then
        error "Cannot infer hostname because the NODE_NAME env var is not set. Ensure this script is being called from Jenkins."
    fi

    readonly sshd_port="${SSHD_PORT:-}"
    if [[ -z "${sshd_port}" ]]; then
        error "Cannot infer the SSHD port because the SSHD_PORT env var is not set. Check that you have set the SSHD_PORT in the Jenkinsfile."
    fi
else
    sshd_port_file="${podinfo_dir}/sshd-port"
    node_fqdn_file="${podinfo_dir}/node-fqdn"

    for file in "${sshd_port_file}" "${node_fqdn_file}"; do
        if [[ ! -f "${file}" ]]; then
            error "File not found: '${file}'. Check the pod configuration."
        fi
    done

    # Wait for 30s until the sshd_port_file and node_fqdn_file are populated
    for attempt in {1..30}; do
        if [[ -s "${sshd_port_file}" && -s "${node_fqdn_file}" ]]; then
            break
        elif [[ "${attempt}" -eq 5 ]]; then
            log_task "Waiting 25s more for the '${sshd_port_file}' and '${node_fqdn_file}' files to be populated"
        elif [[ "${attempt}" -eq 30 ]]; then
            error "The '${sshd_port_file}' and '${node_fqdn_file}' files were not populated after 30s. Check the dynamic-hostports installation." >&2
        fi
        sleep 1
    done

    sshd_port="$(cat "${sshd_port_file}")"
    readonly sshd_port
    unset sshd_port_file

    node_host="$(cat "${node_fqdn_file}")"
    readonly node_host
    unset node_fqdn_file
fi

user_file="${script_dir}/user"
# Wait for 30 seconds until the user file is created
for attempt in {1..30}; do
    if [[ -f "${user_file}" ]]; then
        break
    elif [[ "${attempt}" -eq 5 ]]; then
        log_task "Waiting 25s more for the '${user_file}' file to be created"
    elif [[ "${attempt}" -eq 30 ]]; then
        error "The '${user_file}' file was not created after 30s. Did the entrypoint script run?" >&2
    fi
    sleep 1
done

user="$(cat "${user_file}")"
readonly user
unset user_file

domain_file="${script_dir}/domain"
if [[ -f "${domain_file}" ]]; then
    domain="$(cat "${domain_file}")"
elif [[ -n "${DOMAIN:-}" ]]; then
    domain="${DOMAIN}"
else
    domain=""
fi
readonly domain
unset domain_file

# Check if node_host is a fully qualified domain name (have a dot)
if [[ "${node_host}" == *.* ]]; then
    readonly node_fqdn="${node_host}"
    if [[ -n "${domain}" ]]; then
        log_info "Ignoring the DOMAIN env var because the inferred node hostname seems to be a fully qualified domain name."
    fi
elif [[ -n "${domain}" ]]; then
    readonly node_fqdn="${node_host}.${domain}"
    log_info "Using the DOMAIN env var to build the node's fully qualified domain name."
else
    readonly node_fqdn="${node_host}"
    log_manual_action "Inferred node hostname does not seem to be a fully qualified domain name and the DOMAIN env var is not set. The SSH command may not work."
fi

readonly ssh_host="${user}@${node_fqdn}:${sshd_port}"

log_info "The SSH host is: ${ssh_host}"
echo

log_tip "Copy the following command and paste in your terminal to access the container:"
log_c "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR ssh://${ssh_host} -t 'cd ${PWD} && exec \$0'"
echo

log_tip "You can also open the build container in VS Code (via the Remote - SSH extension) by opening the following link in your browser:"
log_c "vscode://vscode-remote/ssh-remote+${ssh_host}${PWD}"
echo

if [[ -n "${BUILD_URL:-}" ]]; then
    log_manual_action "Don't forget that the container will be automatically deleted once the build is finished." >&2
fi
