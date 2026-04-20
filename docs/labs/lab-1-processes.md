# Lab 1: Processes, Syscalls, and Process Trees

## Guiding Question

How does one program become many running processes, and how does the operating
system keep track of them?

## Concepts

- process creation with `fork()`
- replacing a process image with the `exec` family
- waiting with `waitpid()`
- exit codes and signals
- parent/child relationships
- `/proc` inspection

## Scenario

You are building a tiny process explorer for a teaching cluster. The tool should
launch worker processes, report their lifecycle, and help the operator explain
what happened during execution.

Starter project: `starter/lab1-process-explorer`

## Observation Tasks

Before changing the starter code:

1. Run `strace -f ./process_explorer 2 4`
2. Run `ps --forest -o pid,ppid,stat,command`
3. Inspect one worker through `/proc/<pid>/status`

Record:

- which system calls appear during creation
- which PID belongs to the parent
- when the child exits and how the parent notices

## Implementation Tasks

Extend the starter so that it supports all of the following:

1. Spawn `N` workers from the command line.
2. Print one structured status line per worker with PID and worker id.
3. Collect every child exit status in the parent.
4. Handle `SIGINT` cleanly and stop launching new workers after interruption.
5. Add one `/proc`-based observation to the parent summary.

## Checkpoints

- What values differ between parent and child immediately after `fork()`?
- Why does the child code path need an explicit process exit?
- What is the difference between a normal exit code and signal termination?
- What would happen if the parent never called `waitpid()`?

## Deliverables

- updated `process_explorer.zig`
- a short write-up answering the checkpoint questions
- one command transcript showing the tool in action

## Stretch Goals

- replace the child worker body with a program launched through the `exec`
  family
- display a compact process tree
- add a timeout for slow workers

## Suggested Verification

```bash
zig build -p zig-out
./zig-out/bin/process_explorer 3 4
strace -f ./zig-out/bin/process_explorer 2 4
```

## Grading Focus

- correct process lifecycle handling
- correct collection of child status
- clear explanation of observed system behavior
