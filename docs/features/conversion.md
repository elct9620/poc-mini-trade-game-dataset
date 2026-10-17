# Conversion

The conversion feature turns a dataset CSV into chat-format JSONL that Unsloth Studio accepts for fine-tuning.

## Usage

```bash
bundle exec ruby bin/convert path/to/input.csv -o path/to/output.jsonl
```

## Output

Each CSV row becomes one JSON line holding a `messages` array:

| Role        | Content                                                      |
|-------------|--------------------------------------------------------------|
| `system`    | The system prompt template filled with the row's item and relationship |
| `user`      | The `input` column                                           |
| `assistant` | The `output` column, unchanged                               |

```json
{"messages":[{"role":"system","content":"You are trading with player..."},{"role":"user","content":"我想買這個生命藥水"},{"role":"assistant","content":"{\"action\":\"sell\",...}"}]}
```

The system prompt is the template in `CLAUDE.md`. Training and evaluation share it, so the model is trained on the same prompt the game sends.

### Asking Price

The prompt carries an `Asking Price` that the game computes, because a small model cannot reliably multiply prices. It is the expected price times the ratio for the item's rarity and relationship, rounded up:

| Rarity | Hostile | Neutral | Friendly | Allied |
|--------|---------|---------|----------|--------|
| Common | 1.3     | 1.0     | 0.8      | 0.7    |
| Rare   | 1.5     | 1.0     | 1.0      | 0.85   |
| Epic   | 2.0     | 1.2     | 1.0      | 1.0    |

Every asking price satisfies the minimum price rules in [validation](validation.md).

## Acceptance Criteria

- `bin/convert` writes one JSON line per CSV row.
- The `system` message contains the row's item name, rarity, expected price, asking price, and relationship status.
- The `assistant` message equals the row's `output` column.
- Missing arguments or a missing input file print an error and exit with code `1`.
