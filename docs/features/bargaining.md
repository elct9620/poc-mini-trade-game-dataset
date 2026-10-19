# Bargaining

Bargaining rows teach the single-turn NPC model to haggle across turns. The game keeps the negotiation state and computes every price; each row is one turn that gives the model that state. The feature spans three documents:

| Document                                      | Defines                              |
|-----------------------------------------------|--------------------------------------|
| This page                                     | Rows, rules, validation, conversion  |
| [Prompts](bargaining/prompts.md)              | Templates for both model calls       |
| [Bargain.tla](bargaining/Bargain.tla)         | The game step as a checked model     |

## Users

Three roles read this feature. Each relies on a different part of it.

| User               | Relies on                                             |
|--------------------|-------------------------------------------------------|
| Dataset author     | Row columns and turn outcomes to write valid turns    |
| Model trainer      | Conversion of each turn into two training examples    |
| Game developer     | The same rules, prompts, and two calls per turn       |

## Impacts

A model trained on bargaining rows changes the game in observable ways:

1. The merchant counters a raise with a smaller price in the same turn.
2. Prices stay within the floor, so rarity guarantees hold across any number of turns.
3. Stalling, lowballing, and threats end a negotiation instead of dragging it on.

## Non-goals

These stay outside bargaining rows.

| Excluded                        | Handled by                         |
|---------------------------------|------------------------------------|
| Choosing an item in conversation | The player picks it in the game UI |
| Deciding how much to concede    | The game, never the model          |
| Several items in one negotiation | One negotiation per item           |

## Terminology

Every rule below uses these names for the negotiation over one item.

| Term        | Meaning                                                   |
|-------------|-----------------------------------------------------------|
| Negotiation | All turns over one item, until the player buys or the merchant walks away |
| Deal        | The merchant agrees to sell at the deal price; the game offers the player a purchase |
| Turn        | One player message and the merchant's reply               |
| Floor       | Lowest price the merchant accepts                         |
| Opening     | The merchant's first counter price                        |
| Counter     | The merchant's current price                              |
| Best offer  | Highest price the player has offered so far               |
| Progress    | A turn that raises the best offer enough                  |
| Patience    | Turns without progress the merchant still tolerates       |
| Settlement  | Applying the negotiation's friendship change at its end   |

## Turn Flow

Each turn makes two model calls around one game step. Templates for both calls are in [prompts](bargaining/prompts.md).

```
player message
     |
     v
[extraction call] --> intent, rude, player_offer
     |
     v
[game step] --> next counter, next patience, outcome
     |
     v
[response call] --> action, message, price, friendship_change
```

## Row Columns

A bargaining row is a dataset row with `round` filled; single-turn rows leave every column below empty. State columns hold the negotiation before the turn, and label columns hold the extraction reply.

| Column          | Kind  | Value                                        |
|-----------------|-------|----------------------------------------------|
| `round`         | State | Turn number from 1; chat does not advance it |
| `patience`      | State | 1 to the relationship's patience             |
| `counter_price` | State | Counter before the turn                      |
| `best_offer`    | State | Best offer so far, empty before any offer    |
| `last_offer`    | State | Most recent offer, empty before any offer    |
| `previous_input` | State | Player line of the previous turn, empty on the first turn |
| `previous_reply` | State | Merchant message of the previous turn, empty on the first turn |
| `intent`        | Label | `offer`, `haggle`, `chat`, or `threat`       |
| `rude`          | Label | `none`, `mild`, or `severe`                  |
| `player_offer`  | Label | Offer for intent `offer`, else empty         |

`relationship_status` is the relationship when the negotiation started, and `output` is the response call's reply.

## Locked Prices

Prices are fixed when a negotiation starts, so friendship changes inside it never move them. The floor is the single-turn asking price, which keeps every [validation](validation.md) minimum.

```
asking  = ChatFormat asking price (expected price x ratio, rounded up)
floor   = asking, except Allied: ceil(expected price x 0.5)
opening = ceil(asking x (1 + markup))
```

## Parameters

The relationship at the start of a negotiation sets how the merchant concedes.

| Relationship | Markup | Concession (α, min step) | Patience |
|--------------|--------|--------------------------|----------|
| Hostile      | 30%    | 0.3, 5%                  | 2        |
| Neutral      | 25%    | 0.5, 10%                 | 3        |
| Friendly     | 15%    | 0.7, 15%                 | 4        |
| Allied       | 10%    | 0.9, 20%                 | 5        |

Steps are shares of the range, `opening − floor`, counted in whole coins.

## Concession Rule

An offer turn computes the next counter as below; all values are integers. Measuring raises from the best offer stops a lowball or a drop-back from earning a concession.

```
range         = opening - floor
min_step      = ceil(min step share x range)
max_step      = max(min_step, floor(0.25 x range))
progress_step = ceil(0.05 x opening)
raise         = offer - max(best_offer, ceil(floor / 2))     (0 before any offer)
progress      = no best_offer yet, or raise >= progress_step
step          = progress ? clamp(floor(α x raise), min_step, max_step) : 0
next counter  = offer >= counter ? counter : max(floor, counter - step)
cost          = offer < floor / 2 ? 2 : (progress ? 0 : 1)
```

## Turn Outcomes

Rows are checked against the first matching rule. A deal sells at the offer for Hostile and Neutral merchants and at the next counter for Friendly and Allied ones.

A deal does not complete a purchase: `sell` only makes the item available at the deal price, so a line misread as accepting costs the player nothing. Buying ends the negotiation; any other turn declines the purchase and bargaining goes on. A row's last offer meets its counter price only after a declined deal, and accepting again then stalls like a haggle.

| Turn                                    | Outcome  | Expected reply            |
|-----------------------------------------|----------|---------------------------|
| `threat`                                | Walkaway | `refuse`, friendship −3   |
| `rude` severe, Hostile or Neutral       | Walkaway | `refuse`                  |
| `rude` mild, Hostile                    | Walkaway | `refuse`                  |
| `chat`                                  | Chat     | `talk`                    |
| `haggle`, patience ≤ cost               | Walkaway | `refuse`                  |
| `haggle`                                | Counter  | `negotiate` at counter    |
| `offer`, offer ≥ next counter, last offer ≥ counter, patience ≤ 1 | Walkaway | `refuse` |
| `offer`, offer ≥ next counter           | Deal     | `sell` at deal price      |
| `offer`, patience ≤ cost                | Walkaway | `refuse`                  |
| `offer`                                 | Counter  | `negotiate` at next counter |

A haggle costs no patience in round 1 and one patience after it. Rude turns that do not end the negotiation follow their intent: a Hostile merchant walks away at any rudeness, a Neutral one only at severe rudeness (insults, demands for something free), and Friendly and Allied ones never. Mild rudeness is disparaging the goods or the price, a sharp tone, or impatience. The next counter equals the counter unless an offer turn concedes. A deal costs no patience, except one patience when the last offer already met the counter. Next patience is patience minus cost, or 0 on a walkaway.

## Friendship Settlement

The model still scores each reply's `friendship_change` by behaviour, as in single-turn rows. The game sums a negotiation's changes and applies the total when it ends.

| Step       | Rule                                         |
|------------|----------------------------------------------|
| Each turn  | Reply's `friendship_change`, −3 to +3        |
| Settlement | Sum of the turns, capped at −3 to +3         |

## Formal Model

[`Bargain.tla`](bargaining/Bargain.tla) defines the game step for any intent and offer. TLC checks it with one configuration per merchant style:

1. Download `tla2tools.jar` v1.7.4 from the TLA+ releases; Java 17 runs it.
2. In `docs/features/bargaining/`, run `java -cp tla2tools.jar tlc2.TLC -config Neutral.cfg Bargain`.
3. Repeat with `Hostile.cfg`, `Allied.cfg`, and `EpicNeutral.cfg`.

Each run proves floor ≤ counter ≤ opening and a deal at or above the counter. It also proves the counter never rises, rounds stay bounded, and every negotiation ends, even when the player keeps declining deals.

## Validation

`bin/validate` checks bargaining rows besides the rules in [validation](validation.md). Each failure prints one of these messages.

| Message                                                  | Raised when                          |
|----------------------------------------------------------|--------------------------------------|
| `Bargaining row is missing '{column}'`                   | A required column is empty           |
| `Invalid intent '{intent}'`                              | Intent outside the four values       |
| `'{column}' must be a positive integer`                  | A number column is malformed         |
| `'rude' must be none, mild, or severe`                   | Rude is malformed                    |
| `'player_offer' must be set only for intent 'offer'`     | Offer and intent disagree            |
| `'previous_input' and 'previous_reply' must be set together` | Only half of the previous turn is filled |
| `Patience {p} is outside 1 to {limit}`                   | Patience out of range                |
| `Counter price {c} is outside floor {f} to opening {o}`  | Counter out of range                 |
| `Counter price must be the opening {o} before any offer` | Conceded without an offer            |
| `Offers must have best offer {b} at least last offer {l}` | Offer columns disagree              |
| `Expected {reply} from the negotiation state, got {reply}` | Reply differs from the outcome     |
| `Threat must change friendship by -3`                    | Threat reply keeps friendship        |

## Conversion

`bin/convert` writes two lines for each bargaining row and one for each single-turn row. Both lines share the player's message.

| Line       | System message      | Assistant message               |
|------------|---------------------|---------------------------------|
| Extraction | Extraction prompt   | `intent`, `rude`, `player_offer` |
| Response   | Response prompt     | The `output` column             |

## Evaluation

[Evaluation](../tools/evaluation.md) scores bargaining rows in both calls. The response call uses the row's reference labels, so a wrong extraction does not hide response quality. An extraction reply that is not a JSON object fails all three extraction metrics.

| Call       | Measures                                            |
|------------|-----------------------------------------------------|
| Extraction | `intent_match`, `rude_match`, `offer_match`         |
| Response   | The single-turn metrics, judged by the row's rules  |

## Acceptance Criteria

The feature is complete when these hold:

1. `bin/validate` passes every single-turn row unchanged and every bargaining row that follows the turn outcomes.
2. Each validation failure above prints its message with the row number.
3. `bin/convert` writes an extraction and a response line for each bargaining row.
4. `bin/evaluate` reports the extraction metrics for bargaining rows.
5. TLC finds no error in all four configurations.
