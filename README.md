# OS Lab

`os-lab` is a university-friendly operating systems lab repo built around Linux
user-space challenges. The sequence focuses on concepts students can observe on
their own machines first, then explain and extend in Zig.

## Lab Sequence

1. `Lab 1` - processes, syscalls, signals, and process trees
2. `Lab 2` - scheduling intuition, threads, race conditions, and mutexes
3. `Lab 3` - memory maps, locality, `mmap`, and isolation
4. `Lab 4` - file descriptors, redirection, pipes, and a tiny shell

## Repo Layout

- `build.zig` root build for all starter executables
- `docs/course-overview.md` course goals, logistics, and assessment
- `docs/verification.md` how each lab is checked
- `docs/labs/` student-facing lab handouts
- `starter/` starter Zig programs for each lab
- `scripts/smoke_test.sh` build-and-run check for the starter projects

## Quick Start

```bash
bash scripts/smoke_test.sh
```

Build only:

```bash
zig build -p zig-out
```

## Teaching Model

Each lab follows the same rhythm:

1. Observe real OS behavior with Linux tools.
2. Modify or extend a small Zig program.
3. Measure and explain what happened.
4. Tackle one stretch challenge if time permits.

The starter code is intentionally compact. It is meant to give students a
working base they can inspect, break, extend, and reason about during the lab.
