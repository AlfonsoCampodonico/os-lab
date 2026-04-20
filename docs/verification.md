# Verification Strategy

This repo uses lightweight checks that match the goals of an OS lab: observable
behavior, explanation, and small working programs.

## Repo-Level Check

Run the starter smoke test:

```bash
bash scripts/smoke_test.sh
```

This confirms that all starter projects build and that each one runs a baseline
demo command through the Zig build output in `zig-out/bin/`.

## Lab 1 Verification

- Observe a parent process spawning children with `ps --forest` or `/proc`
- Run the starter with `./zig-out/bin/process_explorer 3 4`
- Explain what changes before and after `fork()`
- Capture exit codes collected by the parent

## Lab 2 Verification

- Run the race mode multiple times and record inconsistent totals
- Run the mutex mode and show that the total matches the expected count
- Explain why the synchronized result is stable
- Compare elapsed time between the two modes

## Lab 3 Verification

- Inspect `/proc/<pid>/maps` or the `maps` mode output
- Run one sequential and one random memory-touch workload
- Explain which access pattern is friendlier to locality and why
- Demonstrate one `mmap` observation in the write-up

## Lab 4 Verification

- Run at least one external command through the tiny shell
- Demonstrate a one-pipe command such as `echo hi | wc -c`
- Demonstrate output redirection such as `echo hi > out.txt`
- Explain the role of `fork`, `dup2`, and the Zig/POSIX process launch path

## Instructor Guidance

The verification model intentionally mixes:

- expected-output checks
- trace-based observations
- short conceptual explanations

That combination keeps the labs grounded in systems behavior instead of only
checking whether a program printed the right line once.
