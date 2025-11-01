# Development Commands for NoFluff Project

## Essential Commands

### Model & Database Operations
```bash
./bin/rails generate model ModelName field:type field2:type:index
./bin/rails db:migrate
./bin/rails db:rollback
./bin/rails db:seed
```

### Testing
```bash
./bin/rails test                    # Run all tests
./bin/rails test test/models/       # Run model tests
./bin/rails test test/integration/  # Run integration tests
rubocop -A                         # Lint and auto-fix
guard                              # Auto-run tests on file changes
```

### Server & Development
```bash
./bin/rails server                  # Start development server
./bin/rails console                  # Rails console
./bin/rails generate controller     # Generate controller
./bin/rails generate service        # Generate service
```

### Background Jobs
```bash
./bin/rails solid_queue:start       # Start Solid Queue workers
./bin/rails solid_queue:status      # Check queue status
```

### Quality Assurance
```bash
rubocop                            # Check code style
rubocop -A                         # Auto-fix style issues
brakeman                           # Security vulnerability scan
```

## Git Workflow Commands
```bash
git status                         # Check status before any work
git checkout -b feature/name       # Create feature branch
git add .                          # Stage changes
git commit -m "Message"            # Commit
git push                           # Push to remote
```

## Project-Specific Patterns

### Model Generation with Required Options
```bash
# Always use references for associations
./bin/rails generate model FollowerUser channel:references

# Use jsonb instead of json for JSON columns
./bin/rails generate model Model data:jsonb

# Add indexes in migration generator
./bin/rails generate model Model name:string:index:{unique:true}
```

### Testing Commands (Minitest)
```bash
# Run specific test file
./bin/rails test test/models/channel_test.rb

# Run specific test method
./bin/rails test test/models/channel_test.rb::test_method_name

# Run with verbose output
./bin/rails test -v
```

### Configuration Commands
```bash
# Check environment variables
./bin/rails runner "puts Rails.application.credentials.config"

# Check routes
./bin/rails routes

# Check Solid Queue configuration
./bin/rails runner "puts SolidQueue.config"
```

## Post-Development Checklist
1. Run `rubocop -A` for all changed files
2. Run relevant tests
3. Check `git status` before staging
4. Commit with descriptive message
5. Run full test suite if time permits