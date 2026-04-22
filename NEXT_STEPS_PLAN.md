# aadc — Bridge Plan to v0.1.0 and a Defensible, Provable, Category-Definer Release

> Working document for the reality-check bridge plan. Revised in-place across ambition rounds.
> Created: 2026-04-22 | Status: DRAFT v4 (Ambition Round 3 — esoteric mathematics injection)

---

## Reality-Check Summary

aadc is **functionally complete** vs its README/AGENTS.md vision. All documented CLI flags work, all 5 exit codes wired, the core algorithm (heuristic block detection → iterative confidence-scored revision → insert-only padding) is verified end-to-end. Build is clean. 290 tests pass. Beads backlog is fully drained: 0 open / 0 in_progress / 52 closed. Last commit was 2026-03-21.

**The remaining gaps are not features — they are the difference between "the code works on the maintainer's machine" and "this is a tool people stake their pipelines on."** That gap is wider than it looks.

The plan below is organised top-down: **ship → formalize → harden → expand the moat → make it a category-definer.** Each workstream is independently shippable; later workstreams depend on earlier ones being defensibly done.

---

## Workstream 0 — Formalization of the Algorithm (Priority P0, prerequisite to v0.1.0)

**Goal:** Pin down what aadc is *actually computing* with mathematical precision so that everything downstream — tests, benches, comparisons, future work — has unambiguous ground truth. Right now the spec lives in code; that's a fragile bus-factor.

A diagram corrector that can't articulate *what makes a corrected diagram correct* will accumulate weird edge-case bugs forever. This workstream is the foundation everyone else stands on.

### 0.1 — Formal model
- Define a diagram block `B` as a tuple `(L, C, T)` where `L` is the line set, `C` is the column lattice (visual columns), `T ⊆ C` is the target column set
- Define `correct(B)` as the unique fixed point of the iterative revision operator `R: B → B`
- Prove (or empirically demonstrate to a CI-enforced confidence) that `R` is **contractive** under the metric `d(B₁, B₂) = Σ |right_border(line_i) - target|` — i.e., the loop must converge in ≤ N iterations where N is bounded by `max_misalignment`
- Document the convergence proof in `docs/ALGORITHM-FORMAL.md` with a worked example

### 0.2 — Invariant catalog
Every invariant gets: (a) prose statement, (b) formal predicate, (c) proptest, (d) per-block runtime assertion behind a `--check-invariants` debug flag.

| # | Invariant | Predicate |
|---|-----------|-----------|
| I1 | Insert-only | `∀i: input_line[i] is_subsequence_of output_line[i]` |
| I2 | Line count preserved | `count(input.lines) == count(output.lines)` |
| I3 | Idempotence | `correct(correct(x)) == correct(x)` |
| I4 | Out-of-block bytes preserved | `∀line ∉ any_block: output[line] == input[line]` |
| I5 | Width convergence | `∀Strong line in block: visual_width(output) == target_col` |
| I6 | UTF-8 well-formedness | `output.is_utf8()` |
| I7 | Confidence monotonicity | scoring function is monotone in `(strong_ratio, size_bonus)` |
| I8 | Quick-passthrough soundness | if `box_char_ratio < threshold` and `--all` not set, `output == input` |

### 0.3 — Refinement-types-style spec in code
- Adopt newtype wrappers carrying invariants in their type: `BoxyLine`, `StrongLine`, `TargetCol(NonZeroUsize)`, `RevisionScore` (newtype around `f64` with `0.0..=1.0` invariant)
- Use `nutype` crate for compile-time-checked invariants on these
- Eliminates entire bug classes (e.g., score >1.0, target_col == 0)

### 0.4 — Reference implementation in another language
- 50-line Python reference implementation under `reference/aadc.py`
- Differential test in CI: same inputs, byte-identical outputs
- The Python implementation is *deliberately* the slowest, most readable possible — it serves as executable spec, not as a competitor
- Discrepancies become bugs in *one* of the implementations; we discuss which

### 0.5 — Property-based testing as primary correctness story
- `proptest` strategies for: arbitrary diagrams, arbitrary CJK content, arbitrary tab widths, arbitrary line-mix
- Property tests for every invariant in 0.2
- Shrinking minimizes counterexamples to ≤5 line repros
- Counterexample corpus committed and re-tested on every CI run (regression-by-construction)

### 0.6 — Metamorphic testing
- Apply [metamorphic relations](references/testing-metamorphic): permuting block order shouldn't change output; doubling tab width then halving should round-trip; appending whitespace-only lines shouldn't move the target column
- Catches behavioral inconsistencies the linear test suite would miss

---

## Workstream A — Documentation Sync (Priority P1)

**Goal:** README + AGENTS.md describe exactly what the binary actually does. Zero surprises.

### A.1 — Test-count truth
- Replace stale "138 unit / 20 integration" claims with live counts
- Add a CI check (`scripts/check-test-counts.sh`) that diffs `cargo test --lib 2>&1 | grep "test result"` against README; fail CI on drift
- Add the same check for the bash E2E suites (parse `e2e_runner.sh` output)

### A.2 — Document every flag and subcommand
- README CLI table: add `-L/--lines RANGES` (with grammar: `N`, `N-M`, `N-`, `-M`, comma-separated)
- README CLI table: add `--color {auto|always|never}`
- README CLI table: add `--config FILE`, `--no-config`
- New "Subcommands" section: `aadc hook {install|uninstall|status} [--auto-fix]`, `aadc config {init|show|path}`
- AGENTS.md "CLI Arguments" table: same updates
- Generate the README CLI table directly from `clap` introspection so it can never drift again (build-time `cargo run -- --markdown-help > docs/cli.md`)

### A.3 — Configuration file deep-dive
- New `docs/CONFIGURATION.md`: complete TOML schema, every key, default, type, example
- Discovery order: project `.aadcrc` → walk-up to repo root → `$XDG_CONFIG_HOME/aadc/config.toml` → `$HOME/.aadcrc`
- Precedence: CLI flags > env vars (`AADC_*`) > project config > user config > built-in defaults
- Sample `.aadcrc.example` committed to repo root; install.sh `--easy-mode` offers to drop a starter copy

### A.4 — Pre-commit hook lifecycle docs
- Section in README explaining `aadc hook install [--auto-fix]`, `aadc hook uninstall`, `aadc hook status`
- Compare/contrast with [pre-commit.com](https://pre-commit.com) framework integration (we should also ship a `pre-commit-hooks.yaml` snippet so users of that framework can adopt aadc trivially)
- FAQ: "How do I run aadc only on staged Markdown files?" with the exact one-liner

### A.5 — "How it actually works" deep-dive
- New `docs/ALGORITHM.md`: walk a worked example through detection → classification → scoring → revision → convergence
- Diagrams of the state machine in actual aadc-corrected ASCII (eat your own dog food, embed in CI)
- Complexity analysis: O(n) detection, O(b·k) correction where b=blocks, k=iterations
- Failure modes: when the heuristic *should* refuse (e.g., Markdown tables, code, decorative banners) and how `--all` / `--min-score` overrides

### A.6 — Migrate README badges and copy
- CI badge, codecov badge, crates.io version badge, downloads badge, MSRV badge, license badge — all present and accurate
- Hero asset: GitHub social preview already exists (gh_og_share_image.png) — confirm it's set as the repo's social preview image
- Add an animated `vhs` cassette demo (recorded with `vhs`/`asciinema-agg`) replacing the static "Quick Example" with something users can paste in their terminal

---

## Workstream B — Release v0.1.0 (Priority P0)

**Goal:** A user reading the README can install aadc *from any of the documented channels* and have it work today.

### B.1 — Pre-release CI verification
- All jobs green on `main`: build (Linux x86_64, Linux aarch64, macOS x86_64, macOS aarch64), clippy, fmt, test, llvm-cov ≥80%, bash E2E suites
- If any are red, file a bug bead and block release

### B.2 — Version bump and CHANGELOG finalize
- Bump `Cargo.toml` version to `0.1.0`
- Move all "Unreleased" CHANGELOG content under `## [0.1.0] — 2026-04-XX` with the actual release date
- Use `git-cliff` or `release-plz` to generate the section from conventional commits going forward (set up but don't enforce yet)

### B.3 — Annotated tag
- `git tag -a v0.1.0 -m "aadc v0.1.0 — first stable release"`
- Push to `origin/main` AND `origin/master` (per AGENTS.md)
- Verify the tag appears on GitHub and triggers the release workflow

### B.4 — Crates.io publish
- `cargo publish --dry-run` first; verify `Cargo.toml` has `description`, `repository`, `homepage`, `documentation`, `keywords`, `categories`, `readme`, `license`
- Verify `package.include`/`exclude` keeps the artifact under 500 KB (no fixtures, no PNG)
- `cargo publish`; record the publish timestamp; verify on https://crates.io/crates/aadc
- Smoke-test from clean container: `docker run --rm rust:1.83 sh -c 'cargo install aadc && aadc --version'`

### B.5 — Cross-platform release binaries
- GitHub Actions matrix: `x86_64-unknown-linux-gnu`, `x86_64-unknown-linux-musl`, `aarch64-unknown-linux-gnu`, `aarch64-unknown-linux-musl`, `x86_64-apple-darwin`, `aarch64-apple-darwin`
- Strip + UPX (or `cargo-strip`); document final binary sizes
- SHA-256 checksums file (`SHA256SUMS`) covering every artifact
- Sign with `cosign sign-blob --bundle ... ` AND `minisign -S` (provide both for users who only have one tool)
- SBOM (`cargo cyclonedx`) attached to the release

### B.6 — install.sh hardening + smoke
- Add `set -euo pipefail` audit; ensure every error path tells the user what to do
- Add `--check` flag that downloads + verifies SHA but doesn't install (for CI)
- Smoke test on: ubuntu:22.04, ubuntu:24.04, debian:12, fedora:40, alpine:3.20, archlinux:latest, macOS 14, macOS 15
- Test every documented option: `--system`, `--easy-mode`, `--version v0.1.0`, `--from-source`, default
- Verify `which aadc && aadc --version` after install on every target

### B.7 — Distribution channels beyond crates.io
- **Homebrew tap**: create `Dicklesworthstone/homebrew-tap` with `aadc.rb` formula; bottle for x86_64+aarch64 macOS
- **AUR**: `aadc-bin` PKGBUILD targeting the GitHub release binary
- **Nix**: package definition for nixpkgs; PR upstream
- **Scoop** (Windows-as-stretch): bucket entry pointing at the GitHub release
- **Snap/Flatpak**: stretch — only if there's user pull
- Each channel gets an install row in the README install table

---

## Workstream C — Proof Hardening (Priority P2)

**Goal:** Every promise in the README is defensible with a recent automated artifact users can audit.

### C.1 — Coverage discipline
- Confirm `codecov/codecov-action` configured; verify badge currently ≥80% line
- Add CI gate: line ≥80% AND branch ≥70% AND function ≥85%
- Per-file gate: any file under 60% line coverage fails CI (so dead corners can't hide behind aggregate)
- Coverage trend graph in README pulling from codecov API

### C.2 — Property-based tests with `proptest`
- **Insert-only invariant**: `output.lines().count() == input.lines().count()`, and for every line `i`, `output_line[i].starts_with(input_line[i])` after stripping trailing whitespace differential
- **Idempotence**: `correct(correct(input)) == correct(input)` for all detected-block inputs
- **Width invariant**: in any post-correction block, every Strong line has visual_width == target_col
- **No-detection invariant**: input with zero box chars passes through byte-identical (modulo trailing newline normalization)
- **CJK width invariant**: inputs containing CJK still produce visually-aligned output when rendered with mono-CJK fonts (test via `unicode-width` crate ground truth)

### C.3 — Fuzzing with `cargo-fuzz`
- Harness 1: `correct_lines(arbitrary UTF-8)` — should never panic, never produce invalid UTF-8
- Harness 2: `expand_tabs(arbitrary UTF-8, 1..=16)` — should never panic, output width ≥ input width
- Harness 3: `find_diagram_blocks(arbitrary UTF-8)` — should never panic, returned ranges must be in-bounds and non-overlapping
- CI: nightly fuzz job, 5 minutes per harness; corpus committed to repo
- Crash repros become regression tests automatically

### C.4 — Snapshot regression suite with `insta`
- Every fixture in `tests/fixtures/` gets a `.snap` file
- `cargo insta test` in CI; snapshot drift fails the build
- Reviewer workflow: `cargo insta review` documented in AGENTS.md
- Snapshot also captures verbose output, JSON output, diff output for the same input — three complementary truth references

### C.5 — Differential testing
- Build a "naive" reference implementation of the algorithm in Python (~50 lines)
- CI job runs both on the same fixtures; output must match byte-for-byte
- This catches regressions in the Rust implementation without trusting only the Rust tests

### C.6 — Mutation testing with `cargo-mutants`
- Nightly CI job: run `cargo mutants` on `src/main.rs`; report mutation kill rate
- Goal: ≥80% mutation kill rate within 90 days of v0.1.0
- Track trend; surfaces tests that pass without actually exercising behavior

### C.7 — Performance budget regression gate
- Wire `cargo bench` into CI; serialize results to JSON
- Compare against a baseline JSON committed to repo; fail if any benchmark regresses >15%
- Track the same metric the README touts: lines/sec; assert ≥5,000 lines/sec on a 1MB synthetic corpus on the smallest CI runner

### C.8 — Reproducible build verification
- Document `RUSTFLAGS`, target, toolchain pin needed to produce byte-identical binaries
- `make reproduce` target builds and prints SHA-256 of the result
- CI: build the same binary twice in different jobs; assert SHA-256 match

### C.9 — Supply-chain hardening
- `cargo-audit` in CI: fail on any unhandled CVE
- `cargo-deny`: license whitelist, banned crates list, advisory check
- `cargo-vet`: vet every transitive dep before v0.1.0; commit `supply-chain/audits.toml`
- Pin all GitHub Actions to commit SHAs (not tags) — Tj-actions style attack mitigation
- `actions-permissions` audit; minimize `permissions:` blocks

---

## Workstream D — Tooling & Quality of Life (Priority P2)

### D.1 — Shell completions
- `clap_complete` generation for bash, zsh, fish, elvish, powershell
- Ship as `aadc completions <shell>` subcommand
- install.sh `--easy-mode` offers to install completions in the right system path
- Homebrew formula installs them automatically

### D.2 — Man page
- `clap_mangen` generation for `aadc.1`
- Section also documents config-file format, exit codes, environment variables, files
- Ship in release tarball under `share/man/man1/`
- Homebrew formula installs to `share/man/man1/`

### D.3 — `--explain` flag
- New flag: when set with `--verbose`, prints per-revision rationale ("line 4: padded col 12→18 to match target col 18, score 0.92 = base 0.8 - penalty 0.0 + strength 0.2")
- Useful for understanding why aadc skipped or applied edits
- Enables curriculum content: "here's the algorithm; here's it choosing"

### D.4 — `--review` interactive mode
- TUI built with `ratatui` showing per-block diffs; `y/n/a/q` accept/reject/all/quit
- For users editing a doc and only wanting to fix one block at a time
- Optional dependency behind a `tui` feature flag so the binary stays small for headless users

### D.5 — JSON output schema
- Publish a JSON Schema document for the `--json` output
- CI validates output against schema on every fixture
- Commit `schemas/output.schema.json`; reference from README

### D.6 — Stable-output guarantee
- Document a stability policy: `--json` output keys won't be removed/renamed in 0.x; new keys may be added
- Document an environment variable `AADC_OUTPUT_VERSION` users can pin
- Snapshot tests guard against accidental shape changes

### D.7 — Color and terminal handling
- Respect `NO_COLOR` env var (already there?); verify
- Respect `CLICOLOR_FORCE`; respect `--color` flag override
- Detect dumb terminals and downgrade automatically

### D.8 — Performance: parallel block correction
- When a file has multiple independent blocks, correct them in parallel with `rayon`
- Behind `-j N` flag (default = num_cpus)
- Benchmark on the "large" fixtures; document the speedup

### D.9 — Streaming for huge files
- Today aadc reads the whole file. For large files (>10 MB) stream blocks as they're detected
- Validate with a 100 MB synthetic input; document memory ceiling
- Particularly important for log-file-piping use cases

### D.10 — `aadc lint` mode
- New subcommand: like `--dry-run` but emits SARIF output (https://sarifweb.azurewebsites.net/) so GitHub Code Scanning can show diagram-misalignment "issues" in PRs
- Behind a feature flag if SARIF deps are heavy

---

## Workstream E — Algorithm Improvements (Priority P3, post-v0.1.0)

### E.1 — Left-border alignment
- Today only right-border misalignment is fixed. Mirror the algorithm for left borders
- Detection: a block where the leftmost border column varies across Strong lines
- Insert-only constraint stays: only add leading whitespace, never strip
- Add fixtures + tests; document opt-in flag (`--align-left`) since it's a riskier transformation

### E.2 — Multi-character border support
- Today expects single-char borders. Support `||`, `==`, `~~`, and Unicode pairs like `╔═` etc.
- Generalize `is_vertical_border` from char to grapheme-cluster + lookahead
- Carefully preserve insert-only invariant

### E.3 — Nested box detection
- Diagrams with sub-boxes like `┌─┐│┌─┐│└─┘└──┘` should be understood as nested
- Outer-box correction shouldn't disturb inner boxes
- Build a tree representation; correct depth-first; verify with property test

### E.4 — Markdown-aware processing
- When input file is `.md`, only process content inside fenced code blocks (configurable)
- Avoids false positives on Markdown tables that happen to contain `|`
- Implement via a small `pulldown-cmark` integration behind a `markdown` feature flag

### E.5 — AsciiDoc / RST awareness
- Same idea for `.adoc` and `.rst`
- Each gets a small format-specific preprocessor

### E.6 — Format conversion
- New subcommand `aadc convert --to ascii|unicode-light|unicode-heavy|unicode-double` rewrites a diagram between border styles
- Useful for normalizing docs across teams with different conventions

### E.7 — Diagram generation from spec
- Out of scope for v0.1.0 but worth reserving the surface: `aadc gen` could take a small DSL and emit an ASCII diagram
- Defer; consider once the corrector is rock-solid

---

## Workstream F — Ecosystem & Adoption (Priority P3)

### F.1 — VSCode extension
- Format-on-save runs `aadc -i` on the active file (Markdown only by default)
- Status bar shows last correction count
- Settings for `--min-score`, `--preset`
- Publish to marketplace; ship via `vsce publish`

### F.2 — JetBrains plugin
- Same surface, packaged for IntelliJ family
- Stretch — only if the VSCode plugin gets traction

### F.3 — Neovim plugin
- `null-ls` / `none-ls` integration so aadc shows up alongside other formatters
- Or a thin Lua wrapper for users running raw

### F.4 — Helix integration
- Configuration snippet for `languages.toml` adding aadc as a Markdown formatter

### F.5 — pre-commit framework integration
- Publish a `pre-commit-hooks.yaml` snippet so aadc works with the [pre-commit](https://pre-commit.com) Python framework, not just our native hook
- README quick-start section

### F.6 — GitHub Action
- `Dicklesworthstone/aadc-action@v1` that runs `aadc --dry-run` on changed files in a PR and comments with the diff
- Publish to GitHub Marketplace

### F.7 — Web playground
- WASM build via `wasm-pack`
- Static site at `aadc.rs` (or Pages) with a Monaco editor; type → see corrected output live
- Excellent for marketing and onboarding

### F.8 — Library API alongside CLI
- Refactor `src/main.rs` into `src/lib.rs` (algorithm) + `src/main.rs` (CLI shell)
- Expose `aadc::correct(&str, &Config) -> Result<String>` as the stable library API
- Document under `cargo doc`; publish docs on docs.rs
- Enables embedding in editor plugins without shelling out

### F.9 — Telemetry (opt-in only)
- Tiny anonymous beacon for **misdetection cases** (user pressed `n` in `--review` mode): hash the input, send count
- Strictly opt-in via `aadc config set telemetry true`
- Endpoint: simple Cloudflare Worker → R2; we read aggregates monthly to find heuristic gaps
- Stretch and ethically loaded — defer until there's clear demand and a written privacy policy

---

## Workstream G' — Algorithmic Sophistication (Priority P2, post-formalization)

The current scoring formula is a hand-tuned linear combination. That's fine for v0.1.0 but trivially beatable. These items raise the algorithmic ceiling.

### G'.1 — Bayesian confidence calibration
- Treat scoring as a calibration problem: given a labeled corpus (real misalignments + their human-corrected outputs), fit a calibrated probability model (isotonic regression on top of the raw score)
- Result: `--min-score 0.7` actually means "70% probability this edit is what a human would have made," not "this hand-tuned score crosses 0.7"
- Conformal prediction wrapper: when score uncertainty is high, refuse to edit and surface the case to the user

### G'.2 — Conformal prediction sets
- Per [conformal prediction](https://arxiv.org/abs/2107.07511), produce *sets* of plausible corrections with a calibrated guarantee that the truth is in the set with prob ≥ 1−α
- Useful for `--review` mode: show user the top-k options ranked
- Calibrated against a held-out fixture set; CI gates the calibration error

### G'.3 — Joint multi-block optimization
- Today blocks are corrected independently. But blocks within the same file often share an *aesthetic intent* (same width, same border style)
- Frame the multi-block correction as a small ILP / dynamic-programming problem with a "stylistic consistency" term in the objective
- Ablation study: does this actually help on real corpora?

### G'.4 — Edit-distance lower bound via Wagner-Fischer
- For each block, compute the minimum-edit-distance correction that satisfies the invariants
- Use as a *quality oracle*: if our greedy revision produces more edits, log it (and consider why)
- Doesn't change behavior but gives us a defensible "how close to optimal are we?" answer

### G'.5 — Online learning from `--review` feedback
- When a user accepts/rejects in `--review` mode, locally update the score thresholds (or per-feature weights)
- Stored in `~/.aadc/learned_weights.toml`; reset with `aadc config reset-learning`
- Strictly opt-in; never sent off-device

### G'.6 — Detection via Ising / MRF on column lattice
- Esoteric: model the diagram lattice as a Markov Random Field where each cell has a label (border, content, padding, outside)
- Run loopy belief propagation to infer the most-likely labeling
- Compare against the current heuristic detector on the real-world corpus
- If it's substantially better, swap the detector. If not, write up the negative result. Either is a contribution.

### G'.7 — Rope-based representation for streaming
- For huge files (>100 MB), back the working text with a [rope](https://en.wikipedia.org/wiki/Rope_(data_structure)) (`ropey` crate)
- Allows O(log n) edits and incremental block detection over the file
- Required for the streaming-watch use case where files grow continuously

### G'.8 — SIMD-accelerated box-character detection
- The hot loop is "scan a string for box-drawing characters." This is exactly the workload `memchr2`, `memchr3` and SIMD-accelerated codepoint matching are designed for
- Hand-written AVX-512 / NEON routines for the box-char predicate
- Benchmark: target 10 GB/s scanning throughput on Zen 4 / Apple M3
- Behind feature flags so portability stays intact

### G'.9 — Grammar-based input refinement
- Define a tiny PEG grammar for "valid box-drawing diagram"
- Use [parser-combinator parsing](https://docs.rs/winnow) to validate output of corrections
- Outputs that don't parse get rejected and re-attempted with relaxed parameters

### G'.10 — Algorithmic complexity proof + worst-case bound
- Pen-and-paper analysis: O(n) detection, O(b·k·w) correction where b=blocks, k=iterations, w=block width
- Empirical confirmation: micro-benches sweeping each parameter
- Worst-case adversarial input crafted explicitly; documented as "this is the slowest input we know how to make"

---

## Workstream Ω — Esoteric Mathematics & Frontier Techniques (Priority P3, post-v0.1.0)

**Why this exists:** Most diagram tools are dumb regex pipelines. The *defensible moat* for aadc is being the only one with a principled mathematical core. The items below are deliberately ambitious — none are required for v0.1.0, but each is a research-grade improvement that, executed, would make aadc cited as more than just a useful CLI.

Each item names a specific mathematical technique invented in the last ~60 years and shows the wedge into our problem.

### Ω.1 — Monge-Kantorovich optimal transport for revision selection
- The set of possible revisions for a block has structure: each revision shifts characters in column-space. Frame "minimum perceived disruption" as an [optimal transport](https://optimaltransport.github.io/) problem from input column distribution to corrected column distribution
- The Wasserstein-1 distance is the natural cost; the assignment is the revision plan
- Sinkhorn algorithm gives O(n²) approximation in practice
- Result: the revisions selected are provably *minimum disturbance* in the OT sense, beating greedy heuristics on edge cases

### Ω.2 — Persistent homology for block detection
- Treat the file as a 2D grid; compute the [persistent homology](https://www.maths.ox.ac.uk/people/heather.harrington/persistent-homology) of the indicator function of "box character"
- Diagram blocks correspond to connected components (H₀) and "boxes" correspond to 1-dimensional holes (H₁) with high persistence
- Threshold by persistence to filter noise vs signal
- Implementation via the `gudhi`-style algorithm; C++ binding or pure-Rust port
- Eliminates the entire heuristic layer in `classify_line` — replaces it with a topological invariant

### Ω.3 — Submodular set-cover for revision batching
- The set of revisions to apply within an iteration has diminishing returns (applying revision A often makes revision B unnecessary)
- Frame as a [submodular maximization](https://www.cs.cornell.edu/~rdk/papers/maxnonmono.pdf) problem; greedy algorithm achieves (1-1/e) approximation
- Reduces total iterations needed for convergence

### Ω.4 — Information-theoretic confidence via MDL
- A correction is *good* iff it makes the file shorter to describe (MDL principle, [Rissanen 1978](https://en.wikipedia.org/wiki/Minimum_description_length))
- Compute description length pre/post correction using a simple grammar over (literal, repeat, fill) tokens
- Replace the hand-tuned confidence score with `log(p_post) - log(p_pre)`
- Theoretically principled; empirically calibrated against the corpus

### Ω.5 — Tropical algebra for path-cost computation in revision graphs
- The space of possible revision sequences forms a graph with min-plus (tropical) semiring structure
- [Tropical geometry](https://en.wikipedia.org/wiki/Tropical_geometry) gives polynomial-time shortest-path formulations that beat the current iterative loop in pathological cases
- Particularly attractive for joint multi-block optimization (G'.3)

### Ω.6 — Coresets for representative fixture selection
- The fixture corpus will grow unboundedly. Use [coreset](https://arxiv.org/abs/2011.09384) techniques to maintain a small, statistically representative subset that preserves test coverage
- CI runs the full set; pre-commit runs only the coreset
- Coreset is updated weekly via offline job

### Ω.7 — Differential privacy for telemetry (if F.9 ever ships)
- If we ever collect any telemetry, do it via [local differential privacy](https://en.wikipedia.org/wiki/Local_differential_privacy) — randomized response or Laplace mechanism on each report
- ε ≤ 1.0 strict; budget published in the privacy policy
- Per-user noise floor means we can never even in principle deanonymize any individual report

### Ω.8 — Categorical specification of the revision lattice
- Revisions form a partially-ordered set under "edit-strictly-precedes." Identify this as a [bounded lattice](https://en.wikipedia.org/wiki/Lattice_(order)) with meet/join
- The convergence point of the iterative loop is the join of all applicable revisions
- This isn't just academic: it tells us the loop is correct *by construction* and gives free parallelism
- Encode via [category theory](https://www.math3ma.com/blog) primitives in Rust traits; free monad over revisions

### Ω.9 — Reservoir sampling for streaming block selection
- For huge streamed inputs, can't hold all blocks in memory at once. Use [Vitter's reservoir sampling](https://www.cs.umd.edu/~samir/498/vitter.pdf) variant for weighted sampling of which blocks to surface in `--review` mode

### Ω.10 — Spectral analysis of detection heuristic robustness
- Build the confusion matrix of the detector across the real-world corpus; compute its spectral radius and second eigenvalue
- A wide spectral gap = robust detector; narrow gap = brittle
- Track this as a quality metric across releases

### Ω.11 — Verified implementation in Lean / Coq
- The core algorithm is small enough to mechanically verify
- Re-implement `correct_block` and the invariants in Lean 4; prove convergence and insert-only-ness
- Either extract back to Rust or use as a "trusted oracle" in differential testing
- Distinguishes aadc from every comparable tool

### Ω.12 — Quantum-resistant signing on releases
- Cosign / minisign use Ed25519 today (not post-quantum). Migrate to [SLH-DSA / SPHINCS+](https://csrc.nist.gov/pubs/fips/205/final) once tooling lands
- Stretch and somewhat absurd for a CLI of this size, but: the supply-chain story is part of the moat

### Ω.13 — LLM-assisted heuristic refinement
- Generate adversarial inputs by prompting a small LLM to produce "hard cases for ASCII diagram correction"
- Feed into the fuzzing corpus
- Where the heuristic fails, ask the LLM to suggest the rule it's missing; human-review and possibly add as a heuristic refinement
- Strictly offline / off-critical-path; this is a research aid, not a runtime dep

### Ω.14 — Constraint-handling via SMT solver
- For pathological blocks where greedy fails, encode the correction as an SMT problem (border positions as integer variables, invariants as constraints) and solve with Z3
- Behind a `--smt-fallback` flag; only invoked when greedy iterations exceed `--max-iters` without converging
- Provably-optimal correction in the rare cases where it matters

### Ω.15 — Use of [Tarski's fixed-point theorem](https://en.wikipedia.org/wiki/Knaster%E2%80%93Tarski_theorem) for convergence proof
- The iterative correction operator is monotone on a complete lattice (Workstream Ω.8)
- Knaster-Tarski guarantees a least fixed point exists and is reached in ≤ height(lattice) iterations
- This is the *clean* convergence proof that replaces the empirical "it seems to converge in <10 iterations" claim

---

## Workstream G — Benchmarking & Comparative Positioning (Priority P3)

### G.1 — Comparative benchmark suite
- Benchmark against: hand-written `awk` script, hand-written `sed`, Python equivalent, Vim macro
- Publish results table in README; show 100x+ speedup on real workloads
- Re-run quarterly to catch regressions in our edge

### G.2 — Real-world corpus benchmarks
- Mine GitHub for `.md` files containing ASCII diagrams (filter on `┌|┐|└|┘|+----` patterns)
- Build a corpus of 1,000 real-world misaligned diagrams
- Report aadc's "fixed correctly / partially / wrongly / left alone" rates
- This is the most defensible quality claim a tool like this can make

### G.3 — Memory and throughput profiling
- `heaptrack` snapshots for 1MB, 10MB, 100MB inputs
- Document peak RSS in README
- Set a memory budget and add a CI gate

---

## Workstream H — Release Communication (Priority P2)

### H.1 — Launch blog post
- Hosted on author's blog or GitHub Pages
- Cover: motivation, algorithm sketch, comparative benchmarks, distribution
- Link from README "Why" section

### H.2 — HN / Reddit / Lobsters / X submission
- Time the post for a Tuesday-Thursday morning EST
- Have replies ready for the predictable questions: "why not Vim macro?", "what about Mermaid?", "isn't this what `column` does?"

### H.3 — Demo video
- 90-second screencast: install → fix a real diagram → before/after
- Embed in README hero section; cross-post to YouTube

### H.4 — `awesome-rust` and `awesome-cli-apps` PRs
- Submit aadc to relevant curated lists once it's >100 stars
- Be patient; quality over speed

---

## Workstream I — Definition of Done (v0.1.0 specifically)

A v0.1.0 release ships when ALL of these are true:

- [ ] `cargo install aadc` from a clean machine produces a working binary in ≤2 min
- [ ] `curl ...install.sh | bash` from clean Ubuntu 22.04, 24.04, Debian 12, Fedora 40, Alpine 3.20, Arch, macOS 14, macOS 15 — all green
- [ ] Homebrew tap installs aadc (`brew tap Dicklesworthstone/tap && brew install aadc`)
- [ ] CI green on `main`; all badges reflect reality
- [ ] Coverage line ≥80%, branch ≥70%, function ≥85%
- [ ] Every CLI flag and subcommand documented in README
- [ ] CHANGELOG has a dated `## [0.1.0]` section with grouped changes
- [ ] GitHub release v0.1.0 has signed binaries, SBOM, SHA-256 checksums
- [ ] AGENTS.md test counts match actual `cargo test` output (and CI gate prevents drift)
- [ ] No claim in README fails when followed by a fresh user
- [ ] `aadc completions` and `aadc.1` man page exist and install
- [ ] Property tests cover insert-only, idempotence, width invariants
- [ ] Fuzzing harnesses exist and have run for ≥1 hour cumulative
- [ ] JSON output schema published and CI-validated

---

## Out of scope for v0.1.0

Real gaps that are explicitly deferred:

- Left-border alignment (E.1) — opt-in v0.2.0
- Multi-character border support (E.2) — v0.2.0
- Nested box detection (E.3) — v0.2.0
- Markdown/AsciiDoc/RST awareness (E.4, E.5) — v0.2.0
- Format conversion (E.6) — v0.3.0
- Diagram generation (E.7) — separate tool, maybe never
- Editor plugins (F.1–F.4) — v0.2.0+, community contributions OK
- Web playground (F.7) — v0.2.0
- Library API (F.8) — v0.2.0 (refactor cost is real)
- Telemetry (F.9) — v1.0.0+ if at all
- Windows native MSVC support — track separately
