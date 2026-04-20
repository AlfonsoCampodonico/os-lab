# Lab 2: Threads, Scheduling, and Synchronization

## Guiding Question

Why can the same multithreaded program produce different answers across runs?

## Concepts

- thread creation with `std.Thread.spawn`
- race conditions
- mutexes and spinlocks
- scheduling intuition and interleaving
- fairness and contention

## Scenario

You are testing a shared counter service. The first version is fast but
incorrect under concurrency. Your job is to reproduce the bug, explain it, and
repair it with synchronization.

Starter project: `starter/lab2-counter-lab`

## Observation Tasks

Run the starter several times in race mode:

```bash
./counter_lab race 8 50000
```

Then compare against mutex mode:

```bash
./counter_lab mutex 8 50000
```

Record:

- expected counter value
- actual counter value
- whether the result changes across runs
- whether runtime changes with synchronization enabled

## Implementation Tasks

Extend the starter so that it supports:

1. A reproducible race demonstration.
2. A correct synchronized counter path.
3. Timing output for each run.
4. One explanation of how a thread interleaving causes lost updates.
5. One additional synchronization challenge such as a bounded queue or barrier.

## Checkpoints

- Why does `counter++` fail as an atomic operation?
- Why can a race disappear temporarily and still be a real bug?
- What trade-off does the mutex version make?
- What would starvation or unfairness look like in this program?

## Deliverables

- updated `counter_lab.zig`
- one short table of observed results
- answers to the checkpoint questions

## Stretch Goals

- implement a producer-consumer queue with a condition variable
- compare coarse-grained and fine-grained locking
- add a simple fairness experiment

## Suggested Verification

```bash
zig build -p zig-out
./zig-out/bin/counter_lab race 8 50000
./zig-out/bin/counter_lab mutex 8 50000
```

## Grading Focus

- correct identification of the race
- correct synchronization logic
- evidence-based explanation of observed scheduling behavior
