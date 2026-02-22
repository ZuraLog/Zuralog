"""
Life Logger Cloud Brain — Performance Test Suite.

Contains latency benchmarks and throughput tests for critical API
endpoints.  Tests in this package use ``time.perf_counter`` for
high-resolution timing and assert against the project-wide p95
latency target of 200 ms.
"""
