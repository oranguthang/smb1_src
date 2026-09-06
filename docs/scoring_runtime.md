# Scoring Runtime Contract

The scoring evidence layer proves complete state transitions rather than only
routine reachability. It uses the canonical JU ROM and deterministic World 1-1
movie declared in `scenarios/scoring_runtime_scenarios.json`.

Run the complete layer with:

```text
make trace-scoring-runtime
```

The six scenarios cover a normal coin award, the 99-to-100 coin extra-life
boundary, decimal score carry, a natural enemy stomp, a controlled shell-chain
award, and the natural flagpole award. Every score-producing scenario records:

1. the six internal player-score digits before and after the transaction;
2. raw coin and life counters plus the two coin-display digits;
3. the six score tiles written to the status-bar VRAM packet, including leading-zero suppression;
4. the subsequent six-digit top-score update.

Controlled scenarios declare every RAM patch in the manifest. The shared
runtime validator rejects undeclared or missing patches, unexpected event
frames or details, forbidden execution, and incomplete traces. Patches only
establish boundary state; the original scoring routines perform every tested
transaction.

Generated CSV traces live under `build/evidence/scoring/` and remain ignored
inspection artifacts. The JSON manifest, Lua capture script, validator tests,
and this document form the tracked contract.
