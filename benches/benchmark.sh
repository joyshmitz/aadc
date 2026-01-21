#!/usr/bin/env bash
# aadc Performance Benchmarks
# Run: ./benches/benchmark.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "=== aadc Performance Benchmarks ==="
echo ""

# Build release binary
echo "[1/4] Building release binary..."
cargo build --release 2>/dev/null
AADC="./target/release/aadc"

if ! command -v hyperfine &> /dev/null; then
    echo "Warning: hyperfine not installed. Using basic timing."
    USE_HYPERFINE=false
else
    USE_HYPERFINE=true
fi

# Test fixtures
SMALL_FILE="tests/fixtures/ascii/simple_box.input.txt"
MEDIUM_FILE="tests/fixtures/large/100_lines.input.txt"
CJK_FILE="tests/fixtures/large/cjk_content.input.txt"

echo ""
echo "[2/4] Checking test fixtures..."
for f in "$SMALL_FILE" "$MEDIUM_FILE" "$CJK_FILE"; do
    if [[ -f "$f" ]]; then
        lines=$(wc -l < "$f")
        bytes=$(wc -c < "$f")
        echo "  ✓ $f ($lines lines, $bytes bytes)"
    else
        echo "  ✗ $f (not found)"
    fi
done

echo ""
echo "[3/4] Running benchmarks..."

run_benchmark() {
    local name="$1"
    local file="$2"
    local warmup="${3:-3}"
    local runs="${4:-10}"

    if [[ ! -f "$file" ]]; then
        echo "  Skip: $name (file not found)"
        return
    fi

    if $USE_HYPERFINE; then
        echo ""
        echo "--- $name ---"
        hyperfine \
            --warmup "$warmup" \
            --runs "$runs" \
            --export-json "/tmp/bench_${name}.json" \
            "$AADC $file > /dev/null"
    else
        echo ""
        echo "--- $name (basic timing) ---"
        # Warmup
        for _ in $(seq 1 "$warmup"); do
            $AADC "$file" > /dev/null
        done
        # Timed runs
        total=0
        for _ in $(seq 1 "$runs"); do
            start=$(date +%s%N)
            $AADC "$file" > /dev/null
            end=$(date +%s%N)
            elapsed=$(( (end - start) / 1000000 ))  # ms
            total=$((total + elapsed))
        done
        avg=$((total / runs))
        echo "  Average: ${avg}ms over $runs runs"
    fi
}

# Run benchmarks
run_benchmark "small_file" "$SMALL_FILE" 3 20
run_benchmark "medium_file" "$MEDIUM_FILE" 3 10
run_benchmark "cjk_content" "$CJK_FILE" 3 10

echo ""
echo "[4/4] Binary size..."
ls -lh "$AADC" | awk '{print "  Binary size:", $5}'

echo ""
echo "=== Benchmark Complete ==="

# Summary
if $USE_HYPERFINE; then
    echo ""
    echo "JSON results saved to /tmp/bench_*.json"
    echo "Run 'jq .results[].mean /tmp/bench_*.json' to see mean times"
fi
