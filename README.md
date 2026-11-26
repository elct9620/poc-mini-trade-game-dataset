---
language:
- zh
language_bcp47:
- zh-TW
task_categories:
- text-generation
tags:
- game
- trading
- npc-behavior
- json-output
- synthetic
- conversational
pretty_name: Mini Trade Game NPC Dataset
size_categories:
- 1K<n<10K
license: apache-2.0
configs:
- config_name: default
  data_files:
  - split: train
    path: train.csv
  - split: validation
    path: validation.csv
  - split: test
    path: test.csv
---

# Mini Trade Game NPC Dataset

Bargaining turns in Traditional Chinese (zh-TW) for fine-tuning a small model to play a merchant NPC. The model only reads the player and phrases replies; the game keeps every rule and number.

| Call    | Model reads                       | Model writes             |
|---------|-----------------------------------|--------------------------|
| Extract | Player line and turn context      | Intent, attitude, offer  |
| Render  | Player line and the game's result | The NPC's message        |

The prompts, fields, and conversion rules are in [NPC Calls](docs/features/npc-calls.md).

## Intended Use

The dataset trains an on-device NPC whose game supplies its terms, such as the currency word. It suits a game that decides actions and prices itself.

| Use                         | Fit                                  |
|-----------------------------|--------------------------------------|
| A merchant NPC in a game    | Yes                                  |
| Other NPC roles             | No, the rows cover a merchant only   |
| Languages other than zh-TW  | No                                   |
| Real trading or commerce    | No                                   |

## Data Fields

Each row is one bargaining turn. Prompt fields copy these columns, and conversion swaps the currency word.

| Column                              | Holds                                      |
|-------------------------------------|--------------------------------------------|
| `id`, `item_name`                   | Row identity and item                      |
| `relationship`                      | `hostile`, `neutral`, `friendly`, `allied` |
| `currency`                          | The currency word in the row's text        |
| `price`                             | The NPC's price before the turn            |
| `previous_player`, `previous_npc`   | The previous turn, empty on the first      |
| `input`                             | The player's line                          |
| `intent`, `attitude`, `offer`       | What the player does                       |
| `action`, `action_price`            | What the game decided                      |
| `message`                           | The NPC's reply                            |

## Data Splits

Validation and test use currencies that never appear in training, so they measure whether replies follow an unseen currency.

| Split      | Rows | Use                  |
|------------|------|----------------------|
| train      | 1586 | Fine-tuning          |
| validation | 309  | Checkpoint selection |
| test       | 248  | Final scoring        |

Items never repeat across splits.

## Usage

Convert each split into chat-format JSONL. Train is rebalanced per call; validation and test keep every row once.

```bash
bundle exec ruby bin/validate train.csv
bundle exec ruby bin/convert train.csv --split train -o train.jsonl
bundle exec ruby bin/convert test.csv --split test -o test.jsonl
```

## Data Creation

Labels came first and text second. A script fixed each turn's labels and the game's decision, then Claude Sonnet wrote the player line and the reply to match.

| Step   | Source                               |
|--------|--------------------------------------|
| Labels | Simulated negotiations               |
| Text   | Claude Sonnet, checked for Taiwan usage |
| Check  | `bin/validate`                       |

## Limitations

The text is synthetic and written by one model. Real players differ in measurable ways.

| Limitation       | Evidence                                    |
|------------------|---------------------------------------------|
| Long lines       | Median 16 characters; few offers are short  |
| Offers with units | Most offers write a currency word          |
| One NPC voice    | Every reply is the same merchant            |
| Fantasy items    | Item names and small talk are fantasy       |

## Contact

Open an issue in the [GitHub repository](https://github.com/elct9620/poc-mini-trade-game-dataset/issues).
