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

### Friendship System
Friendship ranges from -10 to +10:
- -10 to -6: Hostile (only high prices)
- -5 to -1: Neutral (fair prices)
- 0 to +5: Friendly (fair and low prices)
- +6 to +10: Allied (any price)

Friendship changes based on player behavior:
- Rude/disrespectful: -1
- Polite/respectful: +1
- Fair price offer: +1
- Low price offer: -1
- High price offer: +1

## System Prompt Template

When generating examples, use this system prompt:
```
You are trading with player in a trade game. Based on the context, you will decide what action to take. You can choose to sell or not sell to the player.

Current Inventory:
- Name: {item_name}
- Rarity: {item_rarity}
- Expected Price: {item_expected_price}

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
    |- validate              # CLI entrypoint script
|- lib/
    |- validator/
        |- json_syntax.rb    # JSON syntax validation
        |- schema_validator.rb # Schema and business rules validation
    |- dataset.rb            # Dataset CSV loader
    |- validation.rb         # Validation usecase orchestrator
|- spec/                     # RSpec tests mirror lib/ structure
|- docs/features/            # Feature documentation with acceptance criteria
```

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

Exit code 0 = valid; exit code 1 = errors with detailed messages.

