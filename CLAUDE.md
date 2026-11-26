# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dataset for fine-tuning a small on-device model to play a merchant NPC in a trade game, hosted as a Hugging Face Dataset. The model makes two calls per turn: extract reads what the player does, and render phrases the NPC's reply to the action the game chose. The game holds every rule and number; the model never decides what happens.

**Language Requirement**: All text is Traditional Chinese (zh-TW) with Taiwan usage.

The contract for both calls — prompt layout, fields, row columns, currency swap, rebalancing, and the game's duties — is `docs/features/npc-calls.md`. Rows, code, and conversion must follow it.

## Dataset Rows

`train.csv`, `validation.csv`, and `test.csv` hold one bargaining turn per row:

- `id`, `item_name`, `relationship` (`hostile`, `neutral`, `friendly`, `allied`), `currency` (the currency word the text uses)
- `price`, `previous_player`, `previous_npc`: extract context
- `input`: the player's line
- `intent` (`offer`, `haggle`, `chat`, `threat`), `attitude` (`polite`, `plain`, `mild`, `severe`), `offer`: the extract reply
- `action` (`sell`, `counter`, `leave`, `talk`), `action_price`: the game's decision given to render
- `message`: the render reply

Emotion is not stored; conversion maps attitude to emotion by the table in the contract.

## Architecture

```
|- bin/
    |- validate              # Check rows against the row rules
    |- convert               # Write extract and render samples as JSONL
|- lib/
    |- dataset.rb            # CSV loader
    |- validation.rb         # Validation use case
    |- validator.rb          # The validator set
    |- validator/            # Row validators
    |- conversion.rb         # Conversion use case
    |- npc_prompt.rb         # Messages of the extract and render calls
    |- currency.rb           # Train and test currencies
    |- rebalancing.rb        # Cell caps and copies for training
|- spec/                     # RSpec tests mirror lib/
|- docs/features/            # Dataset features with acceptance criteria
|- docs/rubrics/             # Code review criteria
```

**Design Pattern:**
- **Dataset** (`lib/dataset.rb`): Loads and parses CSV files
- **Validators** (`lib/validator/*.rb`): Each inherits from `BaseValidator` and implements `validate(row)`, raising `ValidationError` with a descriptive message or returning `true`
- **Use cases** (`lib/validation.rb`, `lib/conversion.rb`): Take their dependencies (dataset, validators, IO) through the constructor

**Principles:**
- Dependency injection for loose coupling
- Single responsibility per validator class
- Simple data structures (arrays, hashes)
- Early failure with descriptive error messages

## Development Commands

```bash
# Install dependencies
bundle install

# Run all tests with coverage (reports in coverage/)
bundle exec rspec

# Validate a split; exit code 0 = valid, 1 = errors with row numbers
bundle exec ruby bin/validate train.csv

# Convert a split: train rebalances with train currencies; validation and test use --split test
bundle exec ruby bin/convert train.csv --split train -o train.jsonl
bundle exec ruby bin/convert test.csv --split test -o test.jsonl
```
