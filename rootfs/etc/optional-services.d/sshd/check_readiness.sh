#!/bin/bash

exec ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null jenkins@127.0.0.1 true &>/dev/null
