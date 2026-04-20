# Lab 4: Files, Pipes, and a Tiny Shell

## Guiding Question

How do Unix shells connect programs together with file descriptors and pipes?

## Concepts

- file descriptors
- standard input and output
- redirection
- pipes
- process creation and command launch

## Scenario

You are implementing a tiny shell for students who need to see how commands are
connected underneath the terminal. The shell should run simple commands, support
output redirection, and support a one-pipe pipeline.

Starter project: `starter/lab4-tiny-shell`

## Observation Tasks

Before modifying the starter:

1. Run `printf 'echo hi | wc -c\n' | strace -f sh`
2. Run `lsof -p <shell-pid>` on a real shell process
3. Explain what happens to file descriptors during redirection

## Implementation Tasks

Extend the starter so that it supports:

1. launching a simple external command
2. output redirection with `>`
3. a single `cmd1 | cmd2` pipeline
4. a helpful error when parsing fails
5. one explanation of why `dup2()` is necessary

## Checkpoints

- What does a pipe connect?
- Why does each side of a pipeline close different descriptors?
- Why is file descriptor `1` important for redirection?
- What changes between the parent shell process and child command process?

## Deliverables

- updated `tinysh.zig`
- one transcript with a simple command, a redirected command, and a pipeline
- answers to the checkpoint questions

## Stretch Goals

- add input redirection with `<`
- add background execution with `&`
- add a `jobs` builtin

## Suggested Verification

```bash
zig build -p zig-out
printf 'help\nquit\n' | ./zig-out/bin/tinysh
printf 'echo hi | wc -c\nquit\n' | ./zig-out/bin/tinysh
printf 'echo hi > out.txt\nquit\n' | ./zig-out/bin/tinysh
```

## Grading Focus

- correct descriptor handling
- correct child process setup
- clear explanation of how the shell uses OS primitives
