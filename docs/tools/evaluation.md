# Evaluation

The evaluation tool measures how well a fine-tuned model follows this dataset, by asking it to answer every row of a held-out split and judging each reply with the dataset rules. It is a tool for consumers of the dataset, not a dataset feature: the dataset itself is defined by [validation](../features/validation.md) and [conversion](../features/conversion.md).

## Usage

```bash
bundle exec ruby bin/evaluate test.csv --endpoint http://127.0.0.1:8888/v1 [--json-schema] [--report report.jsonl]
```

| Option          | Purpose                                                                 |
|-----------------|-------------------------------------------------------------------------|
| `--endpoint`    | OpenAI-compatible base URL serving the model                            |
| `--json-schema` | Send the reply schema of each call as `response_format` (guided decoding) |
| `--report`      | Write each row's reply, rule errors, and actions as JSONL               |

The prompt is built by the same system prompt as [conversion](../features/conversion.md). Replies use greedy decoding (`temperature: 0`) so runs are reproducible.

## Metrics

| Metric         | A row counts when                                                       |
|----------------|-------------------------------------------------------------------------|
| `json_valid`   | The reply parses as a JSON object                                       |
| `rule_pass`    | The reply passes every [validation](../features/validation.md) rule for the row     |
| `action_match` | The reply's `action` equals the reference output's `action`             |
| `friendship_match` | The reply's `friendship_change` equals the reference value          |
| `message_clean` | The reply's `message` uses only CJK ideographs, digits, and full-width punctuation |
| `message_traditional` | The reply's `message` contains no simplified-only character |
| `intent_match` | Bargaining rows: the extraction reply's `intent` equals the `intent` column |
| `rude_match`   | Bargaining rows: the extraction reply's `rude` equals the `rude` column |
| `offer_match`  | Bargaining rows: the extraction reply's `player_offer` equals the `player_offer` column |
| `deal_match`   | Bargaining rows whose reference action is `sell`: the reply sells at the reference price |

A [bargaining](../features/bargaining.md#evaluation) row takes two calls: the extraction call, then the response call built from the row's reference labels. The response reply counts toward the first six metrics like a single-turn reply. Each metric is reported as a rate between 0 and 1 together with `total`; the extraction metrics and `deal_match` count bargaining rows only. The summary also reports `latency_mean` and `latency_p95`, the seconds each row took including the HTTP round trips, so a bargaining row's latency is a whole turn of two calls.

The summary repeats `total` and the first six metrics under `single` and `bargaining`, because a checkpoint can gain on bargaining while losing single-turn accuracy, and the overall rate hides it.

`message_clean` catches the foreign-script or Latin fragments a small model drifts into (`這枚 embl850`, `水밑上`); the dataset's messages never contain them, and the rules do not read the message. The NPC reply schema carries the same character set as a `pattern` on `message`, so with `--json-schema` guided decoding cannot emit them.

`message_traditional` counts simplified characters (`这`, `随`), which the pattern cannot exclude because Unicode interleaves simplified and traditional ideographs in one range. Spelling out every allowed character as a pattern was measured to nearly double decoding time, so they are counted instead, and a game converts them with the same table, `lib/evaluation/simplified_characters.tsv`: simplified-only characters from OpenCC mapped to their Taiwan forms, without any character the dataset writes. Converting only the entries with a single Taiwan form keeps the meaning (`这罐` → `這罐`).

`action_match` is a proxy: a different action can still be reasonable, so a low rate calls for reading the report rather than failing the model outright.

## Acceptance Criteria

- `bin/evaluate` prints the summary as JSON, including reply latency.
- A reply that is not a JSON object counts as failing `json_valid` and `rule_pass`.
- Rule errors use the same validators as `bin/validate`.
- Bargaining rows report `intent_match`, `rude_match`, and `offer_match` from the extraction call; an extraction reply that is not a JSON object fails all three.
- With `--json-schema`, the extraction call is constrained by the extraction reply schema and the response call by the NPC reply schema, whose `message` pattern allows only the characters `message_clean` accepts.
- A reply whose message contains any other character, or that has no string message, fails `message_clean`.
- A reply whose message contains a character listed in `simplified_characters.tsv`, or that has no string message, fails `message_traditional`; no character in the dataset is listed.
- The summary reports the response metrics separately for single-turn and bargaining rows, and `deal_match` for bargaining rows that should sell.
- An unreachable endpoint or a non-success response prints an error and exits with code `1`.
