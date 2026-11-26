# NPC Calls

The model plays one NPC through two calls per turn: extract reads the player's line, and render phrases the NPC's reply. The game holds every rule and number between them, so the model never decides what happens.

| Call    | Reads                         | Writes                       |
|---------|-------------------------------|------------------------------|
| Extract | Player line and turn context  | Intent, attitude, offer      |
| Render  | Player line and the game's turn result | NPC message         |

## Turn Flow

The game calls extract, resolves the turn with its own rules, then calls render with the result. Resolve is game code, not a model call.

```
Player         Game              Model
  │   line       │                  │
  │─────────────▶│  extract prompt  │
  │              │─────────────────▶│
  │              │◀─────────────────│
  │              │  intent JSON     │
  │              │──┐               │
  │              │  │ resolve       │
  │              │◀─┘               │
  │              │  render prompt   │
  │              │─────────────────▶│
  │              │◀─────────────────│
  │   reply      │  npc line        │
  │◀─────────────│                  │
```

## Prompt Layout

Both system prompts are Markdown sections in a fixed order. The first two sections are identical in both calls, so the game reuses their KV cache.

| Section    | Holds                          | Shared |
|------------|--------------------------------|--------|
| `# World`  | Terms the game uses            | Yes    |
| `# NPC`    | The NPC's identity             | Yes    |
| `# Task`   | `extract` or `render`          | No     |
| `# Turn`   | Fields of that call            | No     |

The task is a fixed label because the calls are a fixed set. Prompts carry no output format; the game constrains each reply with its JSON schema. Sections avoid `< >`, since Gemma reserves angle-bracket tokens such as `<start_of_turn>` and HTML tags.

### Shared Sections

World holds concrete terms only. A genre label such as fantasy does not fix a game's terms, so it is left out.

```
# World
currency: 銀幣
# NPC
role: merchant
```

| Field      | Value                                    |
|------------|------------------------------------------|
| `currency` | The game's currency word                 |
| `role`     | `merchant`, the only NPC the data covers |

A field joins World or NPC only when the training data varies it. A field that never varies is learned as a constant.

## Extract Call

Extract reads the player's line against the negotiation so far. The player's line is the user message.

```
# Task
extract
# Turn
item: 林語豎琴
price: 5170
previous_player: 聽說你拿到林語豎琴了，想問問價錢。
previous_npc: 你消息真靈通，這把要5170銀幣。
```

| Field             | Value                                         |
|-------------------|-----------------------------------------------|
| `item`            | Item name                                     |
| `price`           | The NPC's current price                       |
| `previous_player` | Player line of the previous turn              |
| `previous_npc`    | NPC message of the previous turn              |

On the first turn the two previous fields become one line, `previous: none`.

### Extract Reply

The reply names what the player does, never what the NPC does about it.

```json
{"intent":"offer","attitude":"plain","offer":3619}
```

| Field      | Values                                        |
|------------|-----------------------------------------------|
| `intent`   | `offer`, `haggle`, `chat`, `threat`           |
| `attitude` | `polite`, `plain`, `mild`, `severe`           |
| `offer`    | Price written in the line, else `null`        |

Attitude is one field because politeness and rudeness never occur in the same line. Mild is disparaging the goods or a sharp tone; severe is insults or demanding it free.

## Render Call

Render phrases the action the game chose. The player's line is the user message.

```
# Task
render
# Turn
item: 林語豎琴
relationship: allied
action: counter
price: 4606
player_offer: 3619
emotion: neutral
```

| Field          | Value                                          |
|----------------|------------------------------------------------|
| `relationship` | `hostile`, `neutral`, `friendly`, `allied`     |
| `action`       | `sell`, `counter`, `leave`, `talk`             |
| `price`        | Price for `sell` or `counter`, else `none`     |
| `player_offer` | The player's offer, else `none`                |
| `emotion`      | `pleased`, `neutral`, `annoyed`, `angry`       |

Action is what the NPC does now; emotion is how the player's line made it feel. They are separate, so a polite player can still meet an NPC who leaves.

### Render Reply

The reply is the NPC's line only.

```json
{"message":"差太多了啦，4606銀幣，這已經很低了。"}
```

## Reply Schemas

The game sends each call's JSON schema as `response_format`, so decoding cannot leave the shape. `lib/npc_schema.rb` holds both, and the game and evaluation use the same ones.

| Call    | Schema                                                        |
|---------|---------------------------------------------------------------|
| Extract | `intent` and `attitude` enums; `offer` a positive integer or null |
| Render  | `message`, a string of the message characters                 |

All fields are required. The message pattern is `^[一-鿿0-9，。、！？：；「」『』（）…—～]+$`: CJK ideographs, digits, and full-width punctuation.

The pattern blocks the foreign-script and Latin fragments a small model drifts into. It cannot block simplified characters, which share the CJK range.

## Dataset Rows

A row of `train.csv`, `validation.csv`, or `test.csv` is one bargaining turn. Each prompt field copies a column, except emotion.

| Column            | Feeds                              |
|-------------------|------------------------------------|
| `id`              | Row identity                       |
| `item_name`       | Both calls' `item`                 |
| `relationship`    | Render `relationship`              |
| `currency`        | The currency word the text uses    |
| `price`           | Extract `price`                    |
| `previous_player` | Extract `previous_player`          |
| `previous_npc`    | Extract `previous_npc`             |
| `input`           | Both calls' user message           |
| `intent`          | Extract reply                      |
| `attitude`        | Extract reply                      |
| `offer`           | Extract reply, render `player_offer` |
| `action`          | Render `action`                    |
| `action_price`    | Render `price`                     |
| `message`         | Render reply                       |

### Row Validation

`bin/validate` checks each row and prints one message per failure with the row number.

| Message                                             | Raised when                        |
|-----------------------------------------------------|------------------------------------|
| `Missing '{column}'`                                | A required column is empty         |
| `Invalid {column} '{value}'`                        | A label outside its values         |
| `'{column}' must be a positive integer`             | A number column is malformed       |
| `'offer' must be set only for intent 'offer'`       | Offer and intent disagree          |
| `'action_price' must be set only for sell or counter` | Price and action disagree        |
| `Threat must have attitude 'severe'`                | A threat with another attitude     |
| `'previous_player' and 'previous_npc' must be set together` | Half a previous turn       |

Required columns are all but `previous_player`, `previous_npc`, `offer`, and `action_price`.

### Emotion Table

Emotion follows the attitude. A plain line that reaches a sale pleases the NPC.

| Attitude         | Emotion   |
|------------------|-----------|
| `polite`         | `pleased` |
| `plain`          | `neutral`, or `pleased` on `sell` |
| `mild`           | `annoyed` |
| `severe`, threat | `angry`   |

## Currency Swap

Every occurrence of the row's `currency` in its line, message, and previous turn becomes the sample's currency. A negotiation keeps one currency, picked by item name.

| Split | Currencies                       |
|-------|----------------------------------|
| Train | 金幣 銀幣 銅幣 晶石 貝殼         |
| Train | 靈石 銀兩 代幣 寶石 點數         |
| Test  | 信用點 星幣 能量幣                |

Test currencies never appear in training, so test measures whether replies follow an unseen currency. Validation uses them too, so checkpoint selection rewards the same skill.

## Rebalancing

Each call's training samples are rebalanced by cell: intent × attitude for extract, action × emotion for render. Validation and test are not rebalanced.

| Rule  | Behaviour                                                  |
|-------|------------------------------------------------------------|
| Cap   | A cell keeps at most 15% of the call's rebalanced samples  |
| Floor | A cell under a quarter of the mean cell is copied          |
| Copy  | At most 3 copies, each in the next train currency          |
| Keep  | A capped cell keeps rows with rare features first          |

Rare features are a line of at most 6 characters, an offer without a unit, a first-turn offer, and a Hostile NPC.

## Game Duties

The contract holds only if the game does its part. Each duty keeps a decision out of the model.

| Duty                 | Rule                                            |
|----------------------|-------------------------------------------------|
| Offer check          | The world's currency counts as a coin unit      |
| Resolve              | Action and price come from the game's rules     |
| Emotion              | The game maps attitude to emotion by the table  |
| Friendship           | The game computes it from attitude and offer    |

## Conversion

`bin/convert` writes chat-format JSONL, one sample per line. The split decides currencies and rebalancing.

```bash
bundle exec ruby bin/convert train.csv --split train -o train.jsonl
bundle exec ruby bin/convert test.csv --split test -o test.jsonl
```

| `--split`  | Currencies | Rebalanced |
|------------|------------|------------|
| `train`    | Train      | Yes        |
| `test`     | Test       | No         |

Convert `validation.csv` with `--split test`.

## Acceptance Criteria

The feature is complete when these hold:

1. `bin/validate` passes every row of the three splits.
2. Each validation failure prints its message with the row number.
3. A test conversion writes one extract and one render sample per row.
4. Test samples use only test currencies.
5. After rebalancing, no cell exceeds 15% of its call.
6. No two training samples are identical.
