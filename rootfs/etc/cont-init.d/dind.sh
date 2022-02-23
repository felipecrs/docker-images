#!/usr/bin/with-contenv bash

set -euo pipefail

# https://github.com/jieyu/docker-images/blob/b80dc4787d47d2690eb68cd088ca38eca470dff8/dind/entrypoint.sh#L21-L64

# Check if cgroupfs is mounted
if [[ ! -d "/sys/fs/cgroup/" ]]; then
    exit 0
fi

echo "Applying countermeasures to cgroupfs leaks..." >&2

# Determine cgroup parent for docker daemon.
# We need to make sure cgroups created by the docker daemon do not
# interfere with other cgroups on the host, and do not leak after this
# container is terminated.
if [[ -f "/sys/fs/cgroup/systemd/release_agent" ]]; then
    # This means the user has bind mounted host /sys/fs/cgroup to the
    # same location in the container (e.g., using the following docker
    # run flags: `-v /sys/fs/cgroup:/sys/fs/cgroup`). In this case, we
    # need to make sure the docker daemon in the container does not
    # pollute the host cgroups hierarchy.
    # Note that `release_agent` file is only created at the root of a
    # cgroup hierarchy.
    CGROUP_PARENT="$(grep systemd /proc/self/cgroup | cut -d: -f3)/docker"
else
    CGROUP_PARENT="/docker"

    # For each cgroup subsystem, Docker does a bind mount from the
    # current cgroup to the root of the cgroup subsystem. For instance:
    #   /sys/fs/cgroup/memory/docker/<cid> -> /sys/fs/cgroup/memory
    #
    # This will confuse some system software that manipulate cgroups
    # (e.g., kubelet/cadvisor, etc.) sometimes because
    # `/proc/<pid>/cgroup` is not affected by the bind mount. The
    # following is a workaround to recreate the original cgroup
    # environment by doing another bind mount for each subsystem.
    CURRENT_CGROUP=$(grep systemd /proc/self/cgroup | cut -d: -f3)
    CGROUP_SUBSYSTEMS=$(findmnt -lun -o source,target -t cgroup | grep "${CURRENT_CGROUP}" | awk '{print $2}')

    echo "${CGROUP_SUBSYSTEMS}" |
        while IFS= read -r SUBSYSTEM; do
            mkdir -p "${SUBSYSTEM}${CURRENT_CGROUP}"
            mount --bind "${SUBSYSTEM}" "${SUBSYSTEM}${CURRENT_CGROUP}"
        done
fi

jq --arg c "${CGROUP_PARENT}" '."cgroup-parent" = $c' /etc/docker/daemon.json >/etc/docker/daemon.json.jq

mv -f /etc/docker/daemon.json.jq /etc/docker/daemon.json
