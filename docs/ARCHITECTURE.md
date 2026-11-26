# Architecture

The scripts validate the dataset and convert it into training samples for the two NPC calls. Each script in `bin/` is a thin command over a use case in `lib/`.

```
|- bin/
    |- validate # Check rows against the row rules
    |- convert  # Write extract and render samples as JSONL
    |- evaluate # Tool: score a served model
|- lib/
    |- dataset.rb      # CSV loader
    |- validation.rb   # Use case: validate a dataset
    |- validator.rb    # The validator set
    |- validator/      # Row validators
    |- conversion.rb   # Use case: convert a split
    |- npc_prompt.rb   # Messages of the extract and render calls
    |- npc_schema.rb   # Reply schemas of both calls
    |- currency.rb     # Train and test currencies
    |- rebalancing.rb  # Cell caps and copies for training
    |- evaluation/     # Tool: both calls per row, checks, summary
|- spec/               # RSpec tests mirroring lib/
|- docs/
    |- features/       # Dataset features with acceptance criteria
    |- tools/          # Tools for using the dataset
    |- rubrics/        # Code review criteria
```

## Validation

`Validation` runs every validator on every row and collects messages. A validator raises `ValidationError` with a descriptive message, or returns `true`.

| Validator         | Checks                                  |
|-------------------|-----------------------------------------|
| `ColumnValidator` | Required columns and positive integers  |
| `LabelValidator`  | Allowed values and agreeing labels      |

## Conversion

`Conversion` turns each row into an extract and a render sample. The split picks currencies and whether `Rebalancing` runs.

```
row ──▶ NpcPrompt.extract ──┐
    └─▶ NpcPrompt.render  ──┴──▶ JSONL line
```

Dependencies are injected: use cases take a dataset and an IO, so specs pass arrays and `StringIO`.

## Evaluation

`Evaluation` makes both calls for each row through injected clients, one per reply schema. `Judge` checks the replies and `Summary` adds rates with Wilson lower bounds.

```
row ──▶ extract client ──▶ Judge.extract ──┐
    └─▶ render client  ──▶ Judge.render  ──┴──▶ Summary
```
