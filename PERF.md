# aadc Performance Analysis

> Performance profiling and optimization findings for the ASCII Art Diagram Corrector.

## Performance Baseline (2026-01-21)

### Test Environment
- Platform: Linux (remote compilation via rch)
- Binary size: 1.9 MB (release build with size optimizations)
- Rust edition: 2024, nightly toolchain

### Benchmark Results

| Test Case | Lines | User Time | System Time | Wall Clock |
|-----------|-------|-----------|-------------|------------|
| Small (simple_box) | 5 | ~5ms | ~20ms | 25-200ms* |
| Medium (100_lines) | 115 | ~6ms | ~17ms | 17-260ms* |
| CJK content | 33 | ~5ms | ~18ms | 11-255ms* |

*Wall clock has high variance due to remote compilation environment (rch). User time is the reliable metric.

### Key Findings

1. **User time is consistently fast**: 5-10ms for all test cases
2. **System overhead dominates**: ~20ms for I/O operations
3. **Wall clock variance**: High due to network latency in remote build setup
4. **Binary size**: 1.9 MB (target was <5 MB) ✓

### Performance Goals vs Actual

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Small files (<100 lines) | <50ms | ~5ms user | ✅ Exceeds |
| Medium files (<1000 lines) | <200ms | ~6ms user | ✅ Exceeds |
| Large files (<10000 lines) | <2s | Not tested | - |
| Memory usage | <50MB | Not measured | - |
| Binary size | <5MB | 1.9 MB | ✅ Exceeds |

## Architecture Analysis

### Time Complexity

```
Total: O(B × I × L × W)

Where:
  B = number of diagram blocks
  I = iterations per block (typically 1-3, max 10)
  L = lines per block
  W = average line width (for visual_width)
```

### Hot Paths (from code review)

1. **`visual_width()`** - Called for every line, every iteration
   - Currently O(n) per line using char iteration
   - Simple heuristic for CJK detection

2. **`classify_line()`** - Called during block detection and analysis
   - Multiple char iterations for box character detection
   - Could be optimized with early termination

3. **`is_box_char()`** - Called for every character in boxy lines
   - Uses pattern matching (efficient)
   - Could use lookup table for marginal gains

4. **`find_diagram_blocks()`** - Single pass O(n) scan
   - Already efficient

5. **`correct_block()`** - Core correction loop
   - Creates new Vec<AnalyzedLine> each iteration
   - Could reuse buffer

### Memory Allocation Patterns

- Lines stored as `Vec<String>` (necessary for mutation)
- `AnalyzedLine` created per iteration (optimization opportunity)
- Revisions collected in `Vec` (small, acceptable)

## Optimization Opportunities

### Tier 1: Low-Hanging Fruit

1. **Reuse AnalyzedLine buffer**
   - Current: Creates new `Vec<AnalyzedLine>` each iteration
   - Proposed: Clear and reuse existing buffer
   - Expected gain: Reduced allocations

2. **Early termination in block detection**
   - Skip file if no box chars in first N lines
   - Already partially implemented (`QuickScanResult`)

### Tier 2: Algorithm Improvements

1. **Skip already-aligned blocks**
   - If all borders at same column, skip correction loop
   - Expected gain: Avoid unnecessary iterations

2. **Batch file processing**
   - Process multiple files with single process startup
   - Reduces startup overhead for bulk operations

### Tier 3: Advanced (Not Recommended Yet)

1. **SIMD for box char detection** - Overkill for current performance
2. **Parallel block processing** - Complexity vs benefit unclear
3. **Lookup table for `is_box_char()`** - Marginal gains

## Benchmarking Infrastructure

### Available Tools

1. **Shell script** (`benches/benchmark.sh`)
   - Uses hyperfine for real-world binary benchmarks
   - Tests small, medium, and CJK files
   - Portable across environments

2. **Criterion benchmarks** (`benches/correction.rs`)
   - Subprocess benchmarks (tests full binary)
   - HTML reports available
   - Run with: `cargo bench`

### Running Benchmarks

```bash
# Quick real-world benchmark
./benches/benchmark.sh

# Criterion benchmarks with HTML reports
cargo bench

# Direct timing (for debugging)
time ./target/release/aadc tests/fixtures/large/100_lines.input.txt

# With hyperfine (recommended)
hyperfine --warmup 5 --runs 20 -N './target/release/aadc file.txt'
```

## Recommendations

1. **Current performance is excellent** - No immediate optimizations needed
2. **Monitor regressions** - Add CI performance checks
3. **Profile before optimizing** - Use flamegraph when investigating issues
4. **Avoid premature optimization** - Current architecture is maintainable

## Future Work

- [ ] Add large file test (10000+ lines)
- [ ] Measure memory usage with heaptrack
- [ ] Generate flamegraph for hot path analysis
- [ ] Add CI performance regression tests

---

*Document created by WildRaven (Opus 4.5) as part of bd-3ie*
