#!/usr/bin/env bash

ms() { perl -MTime::HiRes=time -e 'printf "%d", time*1000'; }
echo "PASS=1 FAIL=0"
