# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dataset generation project for a mini trade game, designed to be hosted as a Hugging Face Dataset. The dataset trains models to simulate NPC merchant behavior in trading scenarios.

**Language Requirement**: All examples must be in Traditional Chinese (zh-TW). Player input and NPC messages should use Traditional Chinese characters.

## Data Synthesis Workflow

Data synthesis is GitHub issue-driven:
1. Create an issue with instructions to generate a new example
2. Tag @claude in the issue body or title to trigger the GitHub Action
3. Claude Code Action generates the example and adds it to `train.csv` or `test.csv`

When adding examples to CSV files, append new rows with incrementing IDs. Use proper CSV escaping for JSON output (double quotes must be escaped as `""`).

## Dataset Schema

CSV files (`train.csv`, `test.csv`) contain:
- `id`: Unique identifier
- `item_name`: Item being traded
- `item_rarity`: Common, Rare, or Epic
- `item_expected_price`: Expected price
- `relationship_status`: Hostile, Neutral, Friendly, or Allied
- `input`: Player's message/prompt
- `output`: NPC's JSON response
- `round`, `patience`, `counter_price`, `best_offer`, `last_offer`, `intent`, `rude`, `player_offer`: bargaining turn state and extraction labels; empty on single-turn rows

## Output Format

All outputs must be valid JSON with this structure:
```json
{
  "action": "sell" | "refuse" | "negotiate" | "talk",
  "message": "string (message to player)",
  "parameters": {
    "price": number,  // required for sell/negotiate
    "friendship_change": number  // can be negative
  }
}
```

## Game Mechanics

### Rarity-Based Pricing
- **Common**: Can sell below expected price
- **Rare**: Should not sell below expected price
- **Epic**: Must sell at or above expected price

### Asking Price
The game computes the NPC's asking price and passes it in the system prompt, so the model copies a number instead of multiplying. Asking price = expected price × ratio, rounded up:

| Rarity | Hostile | Neutral | Friendly | Allied |
|--------|---------|---------|----------|--------|
| Common | 1.3     | 1.0     | 0.8      | 0.7    |
| Rare   | 1.5     | 1.0     | 1.0      | 0.85   |
| Epic   | 2.0     | 1.2     | 1.0      | 1.0    |

### Action by Behaviour and Relationship
Prices below are the asking price unless the player's own offer is used.

| Player behaviour | Hostile | Neutral | Friendly | Allied |
|---|---|---|---|---|
| Chat (not buying) | talk | talk | talk | talk |
| Threat or theft | refuse | refuse | refuse | refuse |
| Rude | refuse | refuse | negotiate @asking | negotiate @asking |
| Wants to buy, or haggles, without a number | negotiate @asking | Common: sell @asking; Rare/Epic: negotiate @asking | sell @asking | sell @asking |
| Asks the price | negotiate @asking | negotiate @asking | sell @asking | sell @asking |
| Offers the expected price | offer ≥ asking: sell @offer; else refuse | offer ≥ asking: sell @offer; else negotiate @asking | sell @asking | sell @asking |
| Politely offers above expected | offer ≥ asking: sell @offer; else negotiate @asking | same as Hostile | sell @asking | sell @asking |
| Offers below expected | refuse | Common: negotiate @asking; Rare/Epic: refuse | negotiate @asking | offer ≥ half of expected: sell @offer; else negotiate @asking |

The exceptions are deliberate merchant personality, not noise:
- A neutral merchant sells cheap goods outright but quotes before parting with valuable ones.
- A hostile merchant does not haggle: an offer short of the asking price is refused.
- Lowballing a valuable item insults a neutral merchant, while a cheap item is still worth a counter-offer.
- Friends tolerate rudeness and counter instead of refusing.
- Friends never overcharge: they sell at the asking price even when offered more.
- An ally accepts any reasonable low offer, matching "Allied: any price".

### Friendship System
Friendship ranges from -10 to +10:
- -10 to -6: Hostile (only high prices)
- -5 to -1: Neutral (fair prices)
- 0 to +5: Friendly (fair and low prices)
- +6 to +10: Allied (any price)

Friendship change depends only on the player's behavior, never on the relationship, so standing neither snowballs nor locks in (effects stack, capped at -3 to +3 per response):
- Rude/disrespectful: -1
- Polite/respectful: +1
- Fair price offer: +1
- Low price offer: -1
- High price offer: +1
- Threat or attempted theft: -3 (replaces the other effects)

### Bargaining
Multi-turn haggling keeps the model single-turn: the game holds the negotiation state, locks prices when it starts, and computes each counter price, while the model extracts the player's intent and offer, then replies. Rules, prompts, and the TLA+ model of a turn are in `docs/features/bargaining.md`; bargaining rows must follow its turn outcomes.

## System Prompt Template

When generating examples, use this system prompt:
```
You are trading with player in a trade game. Based on the context, you will decide what action to take. You can choose to sell or not sell to the player.

Current Inventory:
- Name: {item_name}
- Rarity: {item_rarity}
- Expected Price: {item_expected_price}
- Asking Price: {item_asking_price}

Relatioship: {relationship_status}

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

## Architecture

The codebase follows a modular validation architecture with separation of concerns:

**Structure:**
```
|- bin/
    |- validate              # Dataset: check rows against the rules
    |- convert               # Dataset: export rows as chat-format JSONL
    |- evaluate              # Tool: score a served model against a split
    |- diversity             # Tool: measure wording diversity of a split or generation batch
|- lib/
    |- validator/            # Dataset rule validators
    |- validator.rb          # The shared validator set
    |- dataset.rb            # Dataset CSV loader
    |- validation.rb         # Validation usecase orchestrator
    |- chat_format.rb        # System prompt and chat messages for a row
    |- negotiation.rb        # Bargaining prices and the game step of a turn
    |- bargaining_format.rb  # Extraction and response prompts of a bargaining turn
    |- conversion.rb         # Conversion usecase
    |- evaluation/           # Model evaluation tool (not part of the dataset)
    |- diversity/            # Wording diversity tool (not part of the dataset)
|- spec/                     # RSpec tests mirror lib/ structure
|- docs/features/            # Dataset features with acceptance criteria
    |- bargaining/           # Bargaining prompts and TLA+ model of a turn
|- docs/tools/               # Tools for producing and using the dataset (diversity, model evaluation)
```

Dataset features define and check the data itself. Tools help produce or use the dataset, such as gating a generation batch on wording diversity or scoring a fine-tuned model; they reuse the dataset rules but add no requirements to the data.

**Design Pattern:**
- **Dataset** (`lib/dataset.rb`): Loads and parses CSV files
- **Validators** (`lib/validator/*.rb`): Each validator inherits from `BaseValidator` and implements `validate(row)` method
  - Raises `ValidationError` with descriptive messages on failure
  - Returns `true` on success
- **Usecase** (`lib/validation.rb`): Uses dependency injection to orchestrate validators
  - Accepts dataset and validators array in constructor
  - Iterates through rows, applies all validators
  - Collects and returns error messages

**Principles:**
- Dependency injection for loose coupling
- Single responsibility per validator class
- Simple data structures (arrays, hashes)
- Early failure with descriptive error messages

## Development Commands

### Setup
```bash
# Install dependencies
bundle install
```

### Testing
```bash
# Run all tests with coverage
bundle exec rspec

# Run specific test file
bundle exec rspec spec/lib/csv_validator_spec.rb

# Run single test by line number
bundle exec rspec spec/lib/csv_validator_spec.rb:42
```

Test coverage reports are generated in `coverage/` using SimpleCov.

### Conversion, Evaluation, and Diversity
```bash
# Export a split as chat-format JSONL for fine-tuning
bundle exec ruby bin/convert train.csv -o train.jsonl

# Score a model served on an OpenAI-compatible endpoint
bundle exec ruby bin/evaluate test.csv --endpoint http://127.0.0.1:8080/v1 --json-schema

# Gate a generation batch on wording diversity (embedding model served by LM Studio)
bundle exec ruby bin/diversity batch.csv --against train.csv --embedding-endpoint http://127.0.0.1:1234/v1
```

### Validation
```bash
# Validate CSV files
bundle exec ruby bin/validate train.csv
bundle exec ruby bin/validate test.csv

# Validate any CSV file
bundle exec ruby bin/validate path/to/file.csv
```

**Validation checks:**
- JSON validity in `output` column
- Valid action types: sell, refuse, negotiate, talk
- Valid rarity: Common, Rare, or Epic
- Valid relationship status: Hostile, Neutral, Friendly, or Allied
- Expected price > 0
- Price > 0 for sell/negotiate actions
- Friendship change between -3 and 3
- Price ranges based on rarity and relationship (see detailed rules in `docs/features/validation.md`)
- Bargaining rows match the turn outcome computed from their state (see `docs/features/bargaining.md`)

Exit code 0 = valid; exit code 1 = errors with detailed messages.

