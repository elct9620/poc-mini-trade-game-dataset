# Executable

This document outlines the criteria for evaluating the quality of executable script. For each executable script, we expect it to pass the following criteria.

## Criteria

Following are the criteria used to evaluate the quality of scripts, review step by step with structural reasoning.

### Modular Design (1 points)

The script should be modular that testable and maintainable. The logic should be encapsulated in classes or modules, and put in `lib/` directory.

```ruby
# lib/my_module.rb
module MyModule
  def self.my_method(args)
    # implementation
  end
end
```

```ruby
# bin/my_script

require_relative '../lib/my_module'

MyModule.my_method(args)
```

- Keep script simple and focused on command line interface.
- Manage logic in separate files under `lib/` directory.

### Executable Command (1 points)

The script should be executable from the command line. Use stdlib `OptionParser` to parse command line arguments.

```ruby
#!/usr/bin/env ruby

# Your script logic here
```

- Use simple and clear command line interface.
- Provide helpful error messages for invalid inputs.

## Scoring

Each criterion only get the point when it is fully satisfied, otherwise get 0 point.

