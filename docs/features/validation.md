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

## Acceptance Criteria

- `bin/validate` command exists and is executable.
- `spec/` contains unit tests for the validation logic.
