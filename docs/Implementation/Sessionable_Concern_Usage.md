# Sessionable Concern Documentation

## Overview

The `Sessionable` concern provides a reusable way to add session functionality to ActiveRecord models that have a `session_data` field of type JSON/JSONB. This concern was created to extract session logic from the `TelegramUser` model and make it available for other models if needed.

## Features

- **JSON/JSONB Storage**: Stores session data in a `session_data` column
- **Type Safety**: Supports various data types (strings, numbers, booleans, arrays, hashes)
- **Key Normalization**: Automatically converts symbol keys to strings for consistency
- **Validation**: Validates session data structure and operations
- **Flexible API**: Provides comprehensive set of methods for session manipulation
- **Error Handling**: Graceful handling of errors and validation failures

## Requirements

- Model must have a `session_data` column of type JSON or JSONB
- Rails 8.0+ with PostgreSQL support recommended

## Installation

1. Add the concern to your model:

```ruby
class MyModel < ApplicationRecord
  include Sessionable
end
```

2. Ensure your model has a `session_data` column:

```ruby
# Migration
class AddSessionDataToMyModel < ActiveRecord::Migration[8.0]
  def change
    add_column :my_models, :session_data, :jsonb, default: {}
    add_index :my_models, :session_data, using: :gin
  end
end
```

## Usage Examples

### Basic Operations

```ruby
user = TelegramUser.create!(username: 'john_doe', timezone: 'UTC', language_code: 'en')

# Set a session value
user.set_session('name', 'John')
user.set_session('preferences', { theme: 'dark', language: 'en' })

# Get a session value
name = user.get_session('name')  # => "John"
preferences = user.get_session('preferences')  # => { "theme" => "dark", "language" => "en" }

# Check if key exists
user.session_has_key?('name')  # => true

# Get all keys
user.session_keys  # => ["name", "preferences"]

# Check session size
user.session_size  # => 2

# Check if session is empty
user.session_empty?  # => false
```

### Multiple Operations

```ruby
# Set multiple values at once
user.set_session_data({
  'first_name' => 'John',
  'last_name' => 'Doe',
  'age' => 30,
  'interests' => ['coding', 'reading']
})

# Delete multiple keys
user.delete_session_keys(['age', 'interests'])

# Clear entire session
user.clear_session!
```

### Advanced Usage

```ruby
# Work with a temporary copy
user.with_temp_session do
  user.set_session('temp_value', 'this_will_not_be_saved')
  # Do work with temporary data
end

# Get a safe copy of session data
session_copy = user.session_data_copy
session_copy['new_key'] = 'new_value'  # Won't affect original session

# Validate session data
user.valid_session_data?  # => true
```

### Error Handling

```ruby
# All operations return false on failure
result = user.set_session('key', 'value')
if result
  # Success
else
  # Handle failure
end

# Operations raise exceptions on validation errors
begin
  user.set_session('key', 'value')
rescue ActiveRecord::RecordInvalid => e
  # Handle validation error
end
```

## Available Methods

### Session Data Access
- `session_data` - Returns session data hash
- `session_data=` - Sets session data
- `session_data_copy` - Returns a copy of session data

### Key-Value Operations
- `get_session(key)` - Get value by key
- `set_session(key, value)` - Set value by key (saves to DB)
- `delete_session(key)` - Delete value by key (saves to DB)
- `session_has_key?(key)` - Check if key exists

### Bulk Operations
- `set_session_data(hash)` - Set multiple values at once
- `delete_session_keys(array)` - Delete multiple keys at once
- `clear_session!` - Clear all session data

### Utility Methods
- `session_keys` - Get all session keys
- `session_size` - Get number of keys in session
- `session_empty?` - Check if session is empty
- `valid_session_data?` - Validate session data structure

### Advanced Methods
- `with_temp_session` - Execute block with temporary session data
- `supports_sessions?` - Check if model supports sessions (class method)

## Model Integration

The concern automatically handles cases where models don't support sessions:

```ruby
class ModelWithoutSessionData < ApplicationRecord
  include Sessionable
end

ModelWithoutSessionData.supports_sessions?  # => false

model = ModelWithoutSessionData.new
model.set_session('key', 'value')  # => false
model.get_session('key')  # => nil
```

## Testing

The concern includes comprehensive tests that cover:

- Basic CRUD operations
- Different data types
- Error handling
- Edge cases
- Integration with real models

Run tests with:

```bash
rails test test/models/concerns/sessionable_test.rb
```

## Best Practices

1. **Keep session data small**: JSONB columns are efficient but large amounts of data can impact performance
2. **Use meaningful keys**: Use descriptive key names to avoid conflicts
3. **Validate data**: Ensure session data is valid before storing
4. **Handle errors**: Always check return values and handle potential exceptions
5. **Use appropriate data types**: JSONB supports various types, use them appropriately

## Performance Considerations

- **Indexing**: Consider adding GIN indexes for complex queries on session data
- **Data size**: Monitor session data size to avoid performance issues
- **Frequent updates**: Consider caching if sessions are updated frequently

## Security Notes

- Session data is stored in the database and should be treated as sensitive data
- Consider encrypting sensitive information before storing in session
- Validate all user input before storing in session
- Be aware of data persistence when storing sensitive information

## Migration from Direct Model Methods

If you have existing session methods in your model, you can easily migrate:

```ruby
# Before (in your model)
def get_session(key)
  session_data[key.to_s]
end

def set_session(key, value)
  self.session_data = session_data.merge(key.to_s => value)
  save!
end

# After (using Sessionable concern)
include Sessionable
# All methods are now available automatically
```