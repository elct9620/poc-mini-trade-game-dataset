# Bargaining Prompts

These templates are the contract between training data and the game: both build the two calls of a [bargaining](../bargaining.md) turn from them, word for word. Placeholders in braces come from the row; `Relatioship` keeps the spelling of the single-turn prompt the model already knows.

| Call       | Shows state      | Reply                              |
|------------|------------------|------------------------------------|
| Extraction | Before the turn  | `intent`, `rude`, `player_offer`   |
| Response   | After the turn   | The single-turn NPC reply          |

## Extraction Prompt

The first call reads the player's message and reports intent. Its context uses the state before the turn.

```
You are the merchant's assistant in a trade game. Read the player's message during bargaining and report what the player intends.

Bargaining:
- Item: {item_name}
- Counter Price: {counter_price}
- Last Exchange: {last_exchange}
- Previous Turn: {previous_turn}

You must respond with a JSON object with the following format:
{
  "intent": "offer" | "haggle" | "chat" | "threat",
  "rude": "none" | "mild" | "severe" (mild: disparaging the goods or price, sharp or impatient tone; severe: insults, cursing, or demanding it for free),
  "player_offer": number (the price written in the player's message, or null unless intent is "offer")
}
```

## Extraction Output

The reply carries the row's stage-1 labels. Each field takes its value from the matching column.

| Field          | Column         | Value                                      |
|----------------|----------------|--------------------------------------------|
| `intent`       | `intent`       | `offer`, `haggle`, `chat`, or `threat`     |
| `rude`         | `rude`         | `none`, `mild`, or `severe`                |
| `player_offer` | `player_offer` | Price written in the message for `offer`, else `null` |

## Response Prompt

The second call answers the player. Its bargaining block shows the state after the game applied the turn.

```
You are trading with player in a trade game. You are bargaining with the player over one item. Based on the context, you will decide what action to take.

Current Inventory:
- Name: {item_name}
- Rarity: {item_rarity}
- Expected Price: {item_expected_price}
- Opening Price: {opening_price}

Relatioship: {relationship_status}

Bargaining:
- Round: {round}
- Player Offer: {player_offer or "none"}
- Counter Price: {next_counter}
- Patience: {next_patience}
- Outcome: {outcome}
- Last Exchange: {last_exchange}
- Previous Turn: {previous_turn}

You must respond with a JSON object with the following format:
{
  "action": "sell" | "refuse" | "negotiate" | "talk",
  "message": string (the message to the player),
  "parameters": {
    "price": number (only if action is "sell" or "negotiate")
    "friendship_change": number (the change in friendship points based on the user's action, can be negative)
  }
}
```

## Last Exchange

Both prompts summarise the negotiation so far in one sentence. The sentence depends only on the row's state columns.

| State before the turn  | Sentence                                                       |
|------------------------|----------------------------------------------------------------|
| `last_offer` empty     | `You quoted {counter_price}.`                                  |
| `last_offer` below `counter_price` | `Player last offered {last_offer}. You countered at {counter_price}.` |
| `last_offer` at or above `counter_price` | `You agreed to sell at {deal_price}; the player has not bought it yet.` |

A last offer meets the counter only after a deal the player declined. `{deal_price}` is `counter_price` for Friendly and Allied merchants and `last_offer` otherwise, the price that deal offered.

## Previous Turn

Both prompts quote the turn before this one in the same negotiation, so a short line such as 真的嗎？ or 不夠 is read against what was just said. It comes from the row's `previous_input` and `previous_reply` columns.

| State before the turn | Sentence |
|-----------------------|----------|
| First turn of the negotiation | `none` |
| Otherwise | `Player said "{previous_input}" and you replied "{previous_reply}".` |

## Outcome

The response prompt states the game step's outcome, so the reply follows the game instead of comparing the offer with the counter itself. The price is the one the reply must use.

| Game step | Outcome |
|-----------|---------|
| Deal | `deal at {price}` |
| Counter | `counter at {price}` |
| Walkaway | `walkaway` |
| Chat | `chat` |

