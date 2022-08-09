#!/usr/bin/env bash

set -xeuo pipefail

envDir=$1
configFile=$2
chdir=env/$envDir

[[ -e $chdir/config.tf.json ]] && rm -f $chdir/config.tf.json

cp $configFile $chdir/config.tf.json &&
    terraform -chdir=$chdir init &&
    terraform -chdir=$chdir apply &&
    terraform -chdir=$chdir output -json >$chdir/output.json &&
    git update-index --assume-unchanged $chdir/output.json
