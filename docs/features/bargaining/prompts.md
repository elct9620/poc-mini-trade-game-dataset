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

You must respond with a JSON object with the following format:
{
  "intent": "offer" | "haggle" | "chat" | "threat",
  "rude": boolean (true if the message is rude or disrespectful),
  "player_offer": number (the price the player offers, the counter price when the player accepts it, or null unless intent is "offer")
}
```

## Extraction Output

The reply carries the row's stage-1 labels. Each field takes its value from the matching column.

| Field          | Column         | Value                                      |
|----------------|----------------|--------------------------------------------|
| `intent`       | `intent`       | `offer`, `haggle`, `chat`, or `threat`     |
| `rude`         | `rude`         | `true` or `false`                          |
| `player_offer` | `player_offer` | Positive integer for `offer`, else `null`  |

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
- Last Exchange: {last_exchange}

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
| `last_offer` filled    | `Player last offered {last_offer}. You countered at {counter_price}.` |
