# Validation

The validation feature is designed to verify the training data has valid values.

## Usage

The validation is a command accept a CSV file as input.

```bash
bundle exec ruby bin/validate path/to/your/file.csv
```

## Output

### Valid Data

The exit code will be `0` and no output will be produced.

### Invalid Data

The exit code will be `1` and the output will contain the row number and the error message.

```
Row 3: Invalid action 'trade'
Row 5: Price must be greater than 0 for action 'sell'
Row 8: Friendship value must be between -10 and 10
```

## Requirements

### JSON Validity

The `output` column must contain valid JSON.

### JSON Schema

The JSON in the `output` column always contains the following fields:

- `action` - enum: `sell`, `refuse`, `negotiate`, `talk`
- `message` - string
- `parameters` - object

#### Trade Parameters Object

When the `action` is `sell` or `negotiate`, the `parameters` object must contain:

- `price` - number, must be greater than 0

#### Talk/Refuse Parameters Object

When the `action` is `talk` or `refuse`, the `parameters` object can be empty or omitted.

#### Friendship Change

This value represents the change in friendship points based on the user's action. It should between -3 and +3.

> In training data, the actual friendship value is not provided, only the change in friendship points.

### Rarity

The `item_rarity` column must be one of the following values:

- `Common`
- `Rare`
- `Epic`

### Relationship Status

The `relationship_status` column must be one of the following values:

| Value    | Friendship Range |
|----------|------------------|
| Hostile  | -10 to -6        |
| Neutral  | -5 to -1         |
| Friendly | 0 to +5          |
| Allied   | +6 to +10        |

### Price Validity

The `item_expected_price` column must be a number greater than 0.

In the `output` JSON, if the `action` is `sell` or `negotiate`, the `price` in the `parameters` object must in a valid range based on the `item_rarity` and `relationship_status`:

| Rarity | Relationship Status | Minimum Price Condition       |
|--------|---------------------|-------------------------------|
| Common | Hostile             | price > expected_price * 1.2  |
| Common | Neutral             | price >= expected_price       |
| Common | Friendly            | price >= expected_price * 0.8 |
| Common | Allied              | price > 0                     |
| Rare   | Hostile             | price >= expected_price * 1.5  |
| Rare   | Neutral             | price >= expected_price       |
| Rare   | Friendly            | price >= expected_price       |
| Rare   | Allied              | price > 0                     |
| Epic   | Hostile             | price >= expected_price * 2.0  |
| Epic   | Neutral             | price >= expected_price * 1.2  |
| Epic   | Friendly            | price >= expected_price       |
| Epic   | Allied              | price > 0                     |

## Acceptance Criteria

- `bin/validate` command exists and is executable.
- `spec/` contains unit tests for the validation logic.
