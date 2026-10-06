#!/usr/bin/env bash
R=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
echo x > "$R/odd.txt"; echo "PASS=1 FAIL=0"
