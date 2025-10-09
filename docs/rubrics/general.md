# General

This document outlines the criteria for evaluating the quality of Ruby files. For each Ruby file, we expect it to pass the following criteria.

## Criteria

Following are the criteria used to evaluate the quality of Ruby file, review step by step with structural reasoning.

### Documentation (1 points)

The implementation should include clear and concise documentation comments in RDoc style.

```ruby
##
# = Validator
# A class responsible for validating data inputs.
##
class Validator
  ...
end
```

- Use RDoc style comments for class/module/method documentation, the `@tag` style is not allowed.
- Keep comments concise and relevant.
- Only `lib/` is required to have documentation comments.

## Reference (1 points)

Each implementation is related to a specific specification document or issue, that should be referenced in the comments.

```ruby
##
# = Validator
# A class responsible for validating data inputs.
#
# == Reference
# - {docs/features/validation.md}(docs/features/validation.md)
##
class Validator
  ...
end
```

- Reference relevant specification documents or issue links in the "Reference" section of the comments.
- Remove any references to non-existent documents or issues.
- The document's requirements is prior to the code implementation.

## Testing Coverage (1 points)

The implementation should include comprehensive tests to ensure code quality and reliability.

- Each class/module should have corresponding test files in the `spec/` directory.
- Testing based on requirements, not implementation details.
- Describe behavior with `describe` and `context` blocks in RSpec.

## Scoring

Each criterion only get the point when it is fully satisfied, otherwise get 0 point.
