#!/usr/bin/env bash
set -e

GENERATE_HTML=false
SWIFT_ARGS=()

for arg in "$@"; do
    if [ "$arg" == "--html" ]; then
        GENERATE_HTML=true
    else
        SWIFT_ARGS+=("$arg")
    fi
done

# Run tests with code coverage enabled
echo "==> Running swift test --enable-code-coverage..."
swift test --enable-code-coverage "${SWIFT_ARGS[@]}"

# Locate profdata file
PROFDATA=$(find .build -name "default.profdata" | head -n 1)
if [ -z "$PROFDATA" ]; then
    echo "Error: default.profdata not found in .build"
    exit 1
fi

# Locate test executable inside .xctest package
TEST_BIN=$(find .build -name "SwiftTexMathPackageTests" -type f | grep -v "\.dSYM" | head -n 1)
if [ -z "$TEST_BIN" ]; then
    echo "Error: SwiftTexMathPackageTests binary not found in .build"
    exit 1
fi

echo ""
echo "==> Generating Code Coverage Summary Report..."
echo ""

xcrun llvm-cov report "$TEST_BIN" \
    -instr-profile="$PROFDATA" \
    -ignore-filename-regex="Tests/|\.build/|Examples/"

if [ "$GENERATE_HTML" = true ]; then
    HTML_DIR=".build/coverage_html"
    echo ""
    echo "==> Generating HTML Coverage Report in ${HTML_DIR}..."
    xcrun llvm-cov show "$TEST_BIN" \
        -instr-profile="$PROFDATA" \
        -ignore-filename-regex="Tests/|\.build/|Examples/" \
        -format=html \
        -output-dir="${HTML_DIR}"
    echo "==> HTML report available at ${HTML_DIR}/index.html"
fi

echo ""
echo "==> Coverage Report Complete."
