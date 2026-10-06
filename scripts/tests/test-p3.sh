#!/usr/bin/env bash

ms() { perl -MTime::HiRes=time -e 'printf "%d", time*1000'; }
echo "FAIL p3"; echo "PASS=0 FAIL=1"; exit 1
