#!/bin/bash
# Unit tests for pure logic (aggregator, categories, crypto).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
SRCS=$(find Sources -name '*.swift' ! -name 'LumenApp.swift' ! -name 'MacsyncApp.swift')
swiftc -sdk "$SDK" -target arm64-apple-macosx14.0 $SRCS Tests/*.swift -o /tmp/lumen-tests
/tmp/lumen-tests
