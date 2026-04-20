# Course Overview

## Audience

This lab sequence is designed for undergraduate university students taking an
introductory operating systems course. It assumes basic programming experience,
command line familiarity, and exposure to processes and memory in lecture.

## Learning Outcomes

By the end of the sequence, students should be able to:

- Explain how processes are created, replaced, and synchronized with `fork`,
  `exec`, and `waitpid`.
- Distinguish threads from processes and diagnose a race condition with runtime
  evidence.
- Connect memory experiments to virtual memory concepts such as locality,
  mapping, and protection.
- Explain how file descriptors, redirection, and pipes drive shell behavior.
- Describe what the operating system is doing underneath a running program.

## Recommended Schedule

- `Week 1`: Lab 1 - processes, signals, and process trees
- `Week 2`: Lab 2 - threads, scheduling intuition, and synchronization
- `Week 3`: Lab 3 - memory maps, locality, and `mmap`
- `Week 4`: Lab 4 - pipes, redirection, and a tiny shell
- `Optional`: capstone extension or demo day

Each lab fits a 2-3 hour section:

1. 15-20 minute theory refresh
2. 20-30 minute observation task
3. 60-75 minute implementation task
4. 20-30 minute write-up and discussion

## Environment

Students should work on Linux or a Linux-compatible environment such as WSL.
Recommended tools:

- `zig` `0.16.x`
- `strace`
- `ps`, `top`, `lsof`
- `/proc`

## Submission Model

For each lab, require:

- modified source code
- a short observation log or reflection write-up
- answers to the checkpoint questions in the handout
- screenshots or command output for the required runtime checks

## Assessment

- `40%` implementation correctness
- `25%` systems reasoning
- `20%` debugging and measurement evidence
- `15%` extension challenge or bonus task

## Teaching Notes

- Keep the implementation target small enough that students spend most of their
  time reasoning about behavior, not fighting boilerplate.
- Encourage side-by-side use of `strace`, `/proc`, and source code during labs.
- Use the Zig type system and standard library as support, but keep attention on
  the underlying OS primitives being exercised.
- Treat reflection questions as part of the technical deliverable, not extra
  prose.
