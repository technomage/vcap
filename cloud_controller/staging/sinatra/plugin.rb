require File.expand_path(File.join(File.dirname(__FILE__), '..', 'runtime', 'runtime.rb'))

class SinatraPlugin < StagingPlugin
  include GemfileSupport
  def framework
    'sinatra'
  end

  def stage_application
    begin
      @runtime = RuntimeStaging.plugin_for(self)
      Dir.chdir(destination_directory) do
        # This is obviously the wrong place for this.  Some generic
        # stage_application() should be calling:
        #
        #   @runtime.create_app_directories()
        #   @framework.create_app_directories()
        #   @app_server.create_app_directories()
        #
        #   @runtime.copy_source_files()
        #   @framework.copy_source_files()
        #   @app_server.copy_source_files()
        #
        #   ...
        #
        @runtime.check_staging_prerequisites

        create_app_directories
        copy_source_files
        compile_gems
        create_startup_script
        @runtime.last_chance
      end
    ensure
      @runtime = nil
    end
  end

  # Sinatra has a non-standard startup process.
  # TODO - Synthesize a 'config.ru' file for each app to avoid this.
  def start_command
    sinatra_main = detect_main_file

    # The runtime: looks like:
    #  {"version"=>"0.8", "description"=>"MagLev",
    #   "executable"=>"/home/maglev/Maglev/maglev/bin/maglev-ruby",
    #   "environment"=>{"rails_env"=>"production", "bundle_gemfile"=>nil,
    #                   "rack_env"=>"production",
    #                   "maglev_home"=>"/home/maglev/Maglev/maglev"}}

    if uses_bundler?
      "#{local_runtime} ./rubygems/ruby/#{library_version}/bin/bundle exec #{local_runtime} ./#{sinatra_main} $@"
    else
      "#{local_runtime} #{sinatra_main} $@"
    end
  end

  private
  def startup_script
    vars = environment_hash
    if uses_bundler?
      vars['PATH'] = "$PWD/app/rubygems/ruby/#{library_version}/bin:$PATH"
      vars['GEM_PATH'] = vars['GEM_HOME'] = "$PWD/app/rubygems/ruby/#{library_version}"
      vars['RUBYOPT'] = '-I$PWD/ruby -rstdsync'
    else
      vars['RUBYOPT'] = "-rubygems -I$PWD/ruby -rstdsync"
    end

    vars = vars.merge(@runtime.runtime_env_vars)

    # PWD here is after we change to the 'app' directory.
    generate_startup_script(vars) do
      plugin_specific_startup
    end
  end

  def plugin_specific_startup
    cmds = []
    cmds << "mkdir ruby"
    cmds << 'echo "\$stdout.sync = true" >> ./ruby/stdsync.rb'
    cmds.join("\n")
  end

  # TODO - I'm fairly sure this problem of 'no standard startup command' is
  # going to be limited to Sinatra and Node.js. If not, it probably deserves
  # a place in the sinatra.yml manifest.
  def detect_main_file
    file = app_files_matching_patterns.first
    # TODO - Currently staging exceptions are not handled well.
    # Convert to using exit status and return value on a case-by-case basis.
    raise "Unable to determine Sinatra startup command" unless file
    file
  end
end

