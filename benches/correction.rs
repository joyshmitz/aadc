//! Criterion benchmarks for aadc performance testing.
//!
//! These benchmarks measure the performance of the aadc binary by invoking
//! it as a subprocess. This approach tests real-world performance including
//! process startup, file I/O, and the complete correction pipeline.
//!
//! For micro-benchmarks of internal functions, the code would need to be
//! refactored to expose a library interface.

use criterion::{criterion_group, criterion_main, Criterion};
use std::process::Command;

/// Benchmark processing a small ASCII diagram file
fn bench_small_file(c: &mut Criterion) {
    let input_file = "tests/fixtures/ascii/simple_box.input.txt";

    // Skip if file doesn't exist
    if !std::path::Path::new(input_file).exists() {
        eprintln!("Skipping bench_small_file: {} not found", input_file);
        return;
    }

    c.bench_function("small_file", |b| {
        b.iter(|| {
            Command::new("./target/release/aadc")
                .arg(input_file)
                .output()
                .expect("Failed to execute aadc")
        })
    });
}

/// Benchmark processing a medium-sized file (100 lines)
fn bench_medium_file(c: &mut Criterion) {
    let input_file = "tests/fixtures/large/100_lines.input.txt";

    if !std::path::Path::new(input_file).exists() {
        eprintln!("Skipping bench_medium_file: {} not found", input_file);
        return;
    }

    c.bench_function("medium_file", |b| {
        b.iter(|| {
            Command::new("./target/release/aadc")
                .arg(input_file)
                .output()
                .expect("Failed to execute aadc")
        })
    });
}

/// Benchmark processing CJK content (tests visual_width complexity)
fn bench_cjk_content(c: &mut Criterion) {
    let input_file = "tests/fixtures/large/cjk_content.input.txt";

    if !std::path::Path::new(input_file).exists() {
        eprintln!("Skipping bench_cjk_content: {} not found", input_file);
        return;
    }

    c.bench_function("cjk_content", |b| {
        b.iter(|| {
            Command::new("./target/release/aadc")
                .arg(input_file)
                .output()
                .expect("Failed to execute aadc")
        })
    });
}

/// Benchmark verbose mode (tests console output overhead)
fn bench_verbose_mode(c: &mut Criterion) {
    let input_file = "tests/fixtures/large/100_lines.input.txt";

    if !std::path::Path::new(input_file).exists() {
        eprintln!("Skipping bench_verbose_mode: {} not found", input_file);
        return;
    }

    c.bench_function("verbose_mode", |b| {
        b.iter(|| {
            Command::new("./target/release/aadc")
                .arg("-v")
                .arg(input_file)
                .output()
                .expect("Failed to execute aadc")
        })
    });
}

criterion_group!(
    benches,
    bench_small_file,
    bench_medium_file,
    bench_cjk_content,
    bench_verbose_mode
);
criterion_main!(benches);
