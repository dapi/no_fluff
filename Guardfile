guard :minitest do
  # Rails files
  watch(%r{^app/(.+)\.rb$})                               { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^app/controllers/(.+)_controller\.rb$})        { |m| "test/controllers/#{m[1]}_controller_test.rb" }
  watch(%r{^app/models/(.+)\.rb$})                        { |m| "test/models/#{m[1]}_test.rb" }
  watch(%r{^app/mailers/(.+)\.rb$})                       { |m| "test/mailers/#{m[1]}_test.rb" }
  watch(%r{^app/jobs/(.+)\.rb$})                          { |m| "test/jobs/#{m[1]}_test.rb" }
  watch(%r{^app/helpers/(.+)\.rb$})                       { |m| "test/helpers/#{m[1]}_test.rb" }

  # Library files
  watch(%r{^lib/(.+)\.rb$})                               { |m| "test/lib/#{m[1]}_test.rb" }

  # Test files themselves
  watch(%r{^test/.+_test\.rb$})
  watch('test/test_helper.rb')                            { 'test' }

  # Config changes
  watch(%r{^config/routes\.rb$})                          { 'test' }
  watch(%r{^config/database\.yml$})                       { 'test' }
end
