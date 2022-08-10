#!/usr/bin/env bash

set -euo pipefail

k3d cluster list k1 2>/dev/null || k3d cluster create k1 --servers 1
