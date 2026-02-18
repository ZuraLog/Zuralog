# ADR 001: Selection of Primary LLM (Kimi K2.5)

**Status:** Accepted
**Date:** 2026-02-18
**Author:** AI Solutions Architect (Senior Engineer Persona)

## Context
The "Life Logger" project requires a highly reliable, cost-effective LLM to serve as the "Cloud Brain". The model must handle:
1.  **Complex Orchestration:** Selecting and executing MCP tools with strict schema adherence.
2.  **Health Data Integrity:** Writing to Apple Health/Google Health Connect without corruption.
3.  **Reasoning:** Analyzing cross-app data (nutrition vs. sleep vs. activity) to provide "Tough Love" coaching.
4.  **Unit Economics:** Fitting within a $9.99/mo B2C subscription model with healthy margins.

Calculated Volume per User: ~30 turns/day, ~1.35M Input / ~450k Output tokens per month.

## Options Evaluated

### 1. Kimi K2.5 (Selected)
*   **Pros:**
    *   **Reliability King:** Community consensus highlights superior "English analysis" and instruction following (essential for MCP).
    *   **Interleaved Reasoning:** Effectively "pauses" to verify logic, reducing hallucinations in critical data write paths.
    *   **Cost:** ~$2.16/user/month (Moderate), yielding ~78% gross margin.
*   **Cons:**
    *   Slower than MiniMax (higher latency).
    *   More expensive than MiniMax (~2x).

### 2. MiniMax M2.5
*   **Pros:**
    *   **Benchmark King:** High scores on SWE-Bench.
    *   **Cost:** ~$0.90/user/month (Extremely Cheap), yielding ~91% gross margin.
*   **Cons:**
    *   **"Lazy Coder" Syndrome:** Tendency to hardcode solutions or hallucinate parameters in long contexts.
    *   **High Risk:** Data corruption (e.g., writing 5000 calories instead of 500) would destroy user trust.

### 3. Claude Opus 4.6
*   **Pros:** Smartest model available.
*   **Cons:** **Bankruptcy Risk.** Est. cost ~$18.00/user/month (Negative margin).

### 4. Gemini 3 Pro
*   **Pros:** Massive context window (1M+).
*   **Cons:** Overkill for the immediate "Action Layer" needs; potentially higher latency/cost structure than Kimi for short-burst agentic tasks.

## Decision
We choose **Kimi K2.5** as the primary driver for the MVP.

## Justification (The "Superpower" Analysis)

### 1. The "Peace of Mind" Dividend
In a health application, **Data Integrity is the Product**.
*   If MiniMax saves $1.20 but corrupts one user's Health database, the support cost and churn risk > $100.
*   Kimi's "Interleaved Reasoning" acts as an insurance policy against "lazy" tool calls.
*   The "Senior Engineer" behavior of Kimi ensures that complex MCP interactions (e.g., getting data from Oura, correlating with Strava, writing to HealthKit) are executed with strict adherence to the schema.

### 2. Unit Economics vs. Churn
*   **MiniMax Margin (91%)** vs **Kimi Margin (78%)**.
*   In SaaS, a 78% gross margin is excellent.
*   Optimizing for the last 13% of margin at the expense of reliability is a "premature optimization" trap.
*   **Verdict:** The $1.26/user premium for Kimi is negligible compared to the retention value of a bug-free experience.

### 3. Strategic Fit
*   The "Tough Love Coach" persona requires nuance. Kimi is better at detecting subtle patterns (e.g., "You ran, but your pace was slow due to lack of sleep") without hallucinating fake correlations.

## Consequences
*   **Positive:** High reliability for MCP tool use; reduced risk of data corruption; strong adherence to user instructions.
*   **Negative:** Higher latency per interactions; lower theoretical maximum margin.
*   **Mitigation:**
    *   Implement **Optimistic UI** in Flutter to mask latency.
    *   Isolate Kimi for "Write/Reasoning" tasks.
    *   (Future Phase) Offload simple summarization tasks to MiniMax to improve blended margins.
