# Lab 3: Memory Maps, Locality, and Isolation

## Guiding Question

How does the operating system present memory as one address space while still
controlling mapping, protection, and performance?

## Concepts

- stack vs heap
- virtual memory intuition
- memory maps
- locality
- `mmap`
- protection and segmentation faults

## Scenario

You are building a memory probe for students who need to see how address spaces
change at runtime. The tool should expose mappings and let you compare access
patterns.

Starter project: `starter/lab3-memory-probe`

## Observation Tasks

1. Run `./memory_probe maps`
2. Inspect `/proc/self/maps`
3. Compare sequential and random access modes

Record:

- where the executable, stack, heap, and shared libraries appear
- which access pattern is faster
- one example of a mapping created by `mmap`

## Implementation Tasks

Extend the starter so that it supports:

1. Printing selected memory regions with labels.
2. Sequential and random touch workloads.
3. A small `mmap` demo over a file.
4. One controlled experiment that shows protection or isolation behavior.
5. A short explanation of why locality matters.

## Checkpoints

- What is the difference between heap allocation and memory mapping?
- Why does access order matter for performance?
- What information in `/proc/<pid>/maps` reveals shared libraries?
- What does a segmentation fault tell you about memory protection?

## Deliverables

- updated `memory_probe.zig`
- runtime output for at least two experiments
- answers to the checkpoint questions

## Stretch Goals

- compare page-touch cost for different array sizes
- add a CSV output mode for graphing
- show how a child process inherits mappings after `fork()`

## Suggested Verification

```bash
zig build -p zig-out
./zig-out/bin/memory_probe maps
./zig-out/bin/memory_probe touch 8 sequential
./zig-out/bin/memory_probe touch 8 random
```

## Grading Focus

- accurate reasoning about virtual memory concepts
- useful experiments with clear outputs
- clear connection between observed behavior and theory
