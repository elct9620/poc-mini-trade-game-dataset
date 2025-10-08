# Testing

This document outlines the criteria for evaluating the quality of tests. For each test file, we expect it to pass the following criteria.

## Criteria

Following are the criteria used to evaluate the quality of tests, review step by step with structural reasoning.

### Test Case Naming (1 points)

The RSpec is following the naming convention for test cases by `Module/Class#method` for instance methods and `Module/Class.method` for class methods.

```ruby
RSpec.describe MyClass do
  describe '#instance_method' do
    subject { parent.instance_method(args) }

    it { is_expected.to ... }
    it "is expected to ..." do
      ...
    end
  end

  describe '.class_method' do
    # tests for class_method
  end
end
```

- Use `describe` for grouping related tests.
- Use `it` for individual test cases.
- Use `is expected to ...` in `it` blocks for expectations.
- Use `subject` to define the object under test.

### Contextual Grouping (1 points)

If we need to set up different contexts for the same method, we should use `context` blocks to group related tests together.

```ruby
RSpec.describe MyClass do
  describe '#method' do
    context 'when condition A is met' do
      before do
        # setup for condition A
      end

      let(:variable) { ... }

      it 'does something' do
        ...
      end
    end

    context 'when condition B is met' do
      before do
          # setup for condition B
      end

      it 'does something else' do
        ...
      end
    end
  end
end
```

- Use `when ...` to describe the condition in `context` blocks.
- Use `let` to define variables specific to the context.
- Use `before` blocks to set up the context.

### Assertion Clarity (1 points)

For each test case, the assertions should be clear and focused on a single behavior or outcome.

```ruby
it { is_expected.to eq(expected_value) }
it { is_expected.to be_truthy }
```

- Each `it` block should contain only one expectation.
- Prefer using `is_expected.to ...` for clarity.

### Minimal Mocking/Stubbing (1 points)

Use real objects and data as much as possible. Only use mocking or stubbing when absolutely necessary to isolate the unit under test.

- Use spies or doubles only when the real object is impractical to use.
- Use real data for testing whenever possible.
- Do not mock or stub for private methods.

## Scoring

Each criterion only get the point when it is fully satisfied, otherwise get 0 point.
