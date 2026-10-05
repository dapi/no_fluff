# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'open3'
require 'tmpdir'

# Runs the real entrypoint against stub executables: no Rails or database needed.
class DockerEntrypointTest < Minitest::Test
  ENTRYPOINT = File.expand_path('../../bin/docker-entrypoint', __dir__)

  def run_entrypoint(env, *command)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'bin'))
      { 'rails' => 'rails', 'thrust' => 'thrust' }.each do |name, label|
        path = File.join(dir, 'bin', name)
        File.write(path, "#!/bin/bash\necho \"#{label} $* port=${NO_FLUFF_DATABASE_PORT-unset}\"\n")
        FileUtils.chmod('+x', path)
      end
      clean_env = { 'NO_FLUFF_DATABASE_PORT' => nil, 'NO_FLUFF_DATABASE_MIGRATION_PORT' => nil, 'LD_PRELOAD' => '' }
      output, status = Open3.capture2e(clean_env.merge(env), ENTRYPOINT, *command, chdir: dir)
      assert status.success?, output
      output.lines.map(&:strip)
    end
  end

  def test_web_server_prepares_database_over_the_migration_port
    lines = run_entrypoint(
      { 'NO_FLUFF_DATABASE_PORT' => '6432', 'NO_FLUFF_DATABASE_MIGRATION_PORT' => '5432' },
      './bin/thrust', './bin/rails', 'server'
    )

    assert_equal [ 'rails db:prepare port=5432', 'thrust ./bin/rails server port=6432' ], lines
  end

  def test_web_server_prepares_database_over_the_app_port_without_migration_port
    lines = run_entrypoint({ 'NO_FLUFF_DATABASE_PORT' => '5432' }, './bin/thrust', './bin/rails', 'server')

    assert_equal [ 'rails db:prepare port=5432', 'thrust ./bin/rails server port=5432' ], lines
  end

  def test_database_port_stays_unset_when_nothing_is_configured
    lines = run_entrypoint({}, './bin/thrust', './bin/rails', 'server')

    assert_equal [ 'rails db:prepare port=unset', 'thrust ./bin/rails server port=unset' ], lines
  end

  def test_other_commands_do_not_prepare_the_database
    lines = run_entrypoint(
      { 'NO_FLUFF_DATABASE_PORT' => '6432', 'NO_FLUFF_DATABASE_MIGRATION_PORT' => '5432' },
      './bin/rails', 'runner', 'puts 1'
    )

    assert_equal [ 'rails runner puts 1 port=6432' ], lines
  end
end
