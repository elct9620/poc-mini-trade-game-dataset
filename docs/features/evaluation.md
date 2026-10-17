# Evaluation

The evaluation feature measures whether a fine-tuned model is usable as an NPC merchant, by asking it to answer every row of a held-out dataset and judging each reply with the dataset rules.

## Usage

```bash
bundle exec ruby bin/evaluate test.csv --endpoint http://127.0.0.1:8888/v1 [--json-schema] [--report report.jsonl]
```

| Option          | Purpose                                                                 |
|-----------------|-------------------------------------------------------------------------|
| `--endpoint`    | OpenAI-compatible base URL serving the model                            |
| `--json-schema` | Send the NPC reply schema as `response_format` (guided decoding)        |
| `--report`      | Write each row's reply, rule errors, and actions as JSONL               |

The prompt is built by the same system prompt as [conversion](conversion.md). Replies use greedy decoding (`temperature: 0`) so runs are reproducible.

## Metrics

| Metric         | A row counts when                                                       |
|----------------|-------------------------------------------------------------------------|
| `json_valid`   | The reply parses as a JSON object                                       |
| `rule_pass`    | The reply passes every [validation](validation.md) rule for the row     |
| `action_match` | The reply's `action` equals the reference output's `action`             |

Each metric is reported as a rate between 0 and 1 together with `total`. The summary also reports `latency_mean` and `latency_p95`, the seconds each reply took including the HTTP round trip.

`action_match` is a proxy: a different action can still be reasonable, so a low rate calls for reading the report rather than failing the model outright.

## Usability Threshold

A model is usable in the game when, on `test.csv`:

| Metric         | Threshold | Note                                              |
|----------------|-----------|---------------------------------------------------|
| `json_valid`   | 1.00 with `--json-schema`; ≥ 0.98 without | The game deploys with guided decoding |
| `rule_pass`    | ≥ 0.90    |                                                   |
| `action_match` | ≥ 0.85    |                                                   |
| `latency_mean` | < 1.0 s   | Served by llama.cpp on CPU only (`-ngl 0`)        |
| `latency_p95`  | < 2.0 s   | Same CPU-only setup                               |

The deliverable is a Q4_K_M GGUF, so thresholds are checked against that file served by llama.cpp; a faster backend passing does not count.

## Acceptance Criteria

- `bin/evaluate` prints the summary as JSON, including reply latency.
- A reply that is not a JSON object counts as failing `json_valid` and `rule_pass`.
- Rule errors use the same validators as `bin/validate`.
- An unreachable endpoint or a non-success response prints an error and exits with code `1`.
