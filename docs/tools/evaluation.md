# Evaluation

The evaluation tool scores a served model on a split by making both [NPC calls](../features/npc-calls.md) for every row and comparing each reply with the row. It is a tool for using the dataset and adds no requirement to the data.

| Call    | Reply compared with                 |
|---------|-------------------------------------|
| Extract | The row's intent, attitude, offer   |
| Render  | The row's action, price, currency   |

## Usage

The model must be served on an OpenAI-compatible endpoint.

```bash
bundle exec ruby bin/evaluate test.csv --endpoint http://127.0.0.1:8080/v1 --json-schema --no-cache-prompt --report report.jsonl
```

| Option              | Purpose                                              |
|---------------------|------------------------------------------------------|
| `--endpoint`        | Base URL serving the model                           |
| `--json-schema`     | Send each call's reply schema as `response_format`   |
| `--no-cache-prompt` | Send `cache_prompt: false` to llama-server           |
| `--report`          | Write each row's replies and checks as JSONL         |

Prompts use the test currencies, as a test conversion does. Replies use greedy decoding so runs repeat.

### Prompt Cache

llama-server reuses the previous request's cache for a shared prefix by default. Numerics then depend on row order, so one changed reply shifts every later row.

| Comparing                       | Cache |
|---------------------------------|-------|
| Two models or two settings      | Off   |
| One model against itself        | Either |

## Metrics

Each row is scored in three steps. A metric counts the rows where its check holds.

1. Send the extract prompt built from the row's turn.
2. Send the render prompt built from the row's game decision.
3. Check each reply against the row.

### Extract Metrics

Extract metrics compare the reply's fields with the row's columns.

| Metric           | A row counts when                          |
|------------------|--------------------------------------------|
| `json_valid`     | The reply parses as a JSON object          |
| `intent_match`   | `intent` equals the row's                  |
| `attitude_match` | `attitude` equals the row's                |
| `offer_match`    | `offer` equals the row's, null when empty  |
| `extract_match`  | All three fields match                     |

### Render Metrics

Render metrics read the reply's message. Two metrics count only the rows they apply to.

| Metric                | Rows                    | A row counts when                            |
|-----------------------|-------------------------|----------------------------------------------|
| `json_valid`          | All                     | The reply parses as a JSON object            |
| `message_clean`       | All                     | The message uses only message characters and slots |
| `message_traditional` | All                     | The message has no simplified character      |
| `currency_foreign`    | All                     | The message writes a currency word instead of the slot |
| `price_said`          | `sell` or `counter`     | The message has the `{price}` slot           |
| `currency_own`        | Reference names a currency | The message has the `{currency}` slot     |

`currency_foreign` is the only metric where lower is better. Known currencies are the train and test lists.

Whether the message carries out the action, such as leaving instead of selling, is read by hand in the report.

### Simplified Characters

`lib/evaluation/simplified_characters.tsv` lists simplified-only characters and their Taiwan forms, derived from OpenCC. A game converts the one-to-one entries after decoding.

| Rule              | Reason                                    |
|-------------------|-------------------------------------------|
| No dataset character | A listed character is always an error  |
| No currency character | A currency word never counts as simplified |

## Summary

`bin/evaluate` prints JSON with each metric's rate, its 95% Wilson lower bound, and the rows it counts. A release gate reads the lower bound, so a small sample cannot pass on luck.

```json
{"extract": {"intent_match": {"rate": 0.98, "lower": 0.95, "total": 248}},
 "render": {"price_said": {"rate": 0.99, "lower": 0.96, "total": 172}},
 "latency_mean": 0.41, "latency_p95": 0.6}
```

Latency is the seconds a row took for both calls, a whole turn.

## Acceptance Criteria

The tool is complete when these hold:

1. `bin/evaluate` prints the summary with every metric above and latency.
2. A reply that is not a JSON object fails every metric of its call.
3. With `--json-schema`, each call sends its schema from `lib/npc_schema.rb`.
4. `price_said` and `currency_own` report their own totals.
5. An unreachable endpoint or a failed response prints an error and exits with code 1.
