# This class should be a subclass of StagingPlugin (so it has access
# to all the correct environment etc).  Instead, we violate demeter
# and abuse the framework_plugin instance.
class RuntimeStaging

  # We should really have a separate file for each runtime, and
  # dynamically load them, but I haven't done that yet.
  class MaglevStaging < RuntimeStaging

    # Make sure we are configured correctly for staging.  Maglev will
    # check that there is a bound maglev stone service and that the
    # stone is running.
    def check_staging_prerequisites
      ensure_bound_stone

      Dir.chdir(maglev_home) do
        ml_prog = File.join(maglev_home, 'bin', 'maglev')
        cmd = "MAGLEV_HOME=#{maglev_home} rake #{stone_name}:start"
        system cmd
      end

      true
    end

    # Workaround Trac 899 bug.
    #
    # The staging creates a private rubygems directory for the app.
    # GEM_HOME and GEM_PATH do not completely specify the proper
    # RubyGem environment, so we hack it by doing:
    #   $ cd app/rubygems
    #   $ rm -rf maglev
    #   $ ln -s ruby maglev
    #
    def last_chance
      app_dir = File.join(@plugin.destination_directory, 'app')  # TODO: This should be an accessor defined in common.rb
      rubygems_dir = File.join(app_dir, 'rubygems')

      Dir.chdir(rubygems_dir) do
        FileUtils.rm_rf('maglev')
        FileUtils.ln_s('ruby', 'maglev')
      end
      true
    end

    # Extract the name of the provisioned stone from the bound service
    # info in @plugin.  It will be something like:
    #   "maglev-af6f8aac-3ac2-4fe9-be7c-85e5bc054edf"
    def stone_name
      @stone_name ||= stone_binding[:credentials][:stonename]
    end

    # Extracts the MAGLEV_HOME variable out of the environment given
    # to @plugin.  This utlimately comes from one of the .yml files
    def maglev_home
      @maglev_home ||= @plugin.environment_hash["MAGLEV_HOME"]
    end

    # If we go the route of specifying stone via $STONENAME, then we
    # must also set $GEMSTONE_GLOBAL_DIR and $GEMSTONE_SYS_CONF.
    def runtime_env_vars
      #host       = stone_binding[:credentials][:hostname]

      # TODO: Should we add $MAGLEV_HOME/bin to PATH?  Is so, this may
      # not be the place to do it, since we need to append to PATH,
      # not replace it.
      {
        "STONENAME" => stone_name,
        "GEMSTONE_GLOBAL_DIR" => maglev_home,
        "GEMSTONE_SYS_CONF" => File.join(maglev_home, "etc", "conf.d", stone_name + ".conf"),
      }
    end

    # Ensure that there is a MagLev stone bound to this app and return
    # the information about the bound stone.
    def ensure_bound_stone
      # bound_services is an array of service hashes that looks
      # something like:
      #
      #   [
      #     {
      #       :label       => "maglev-0.8",
      #       :tags        => ["maglev", "maglev-0.8", "stone"],
      #       :name        => "maglev-f3736",
      #       :credentials => {:hostname=>"192.168.109.132",
      #                        :stonename=>""maglev-af6f8aac-3ac2-4fe9-be7c-85e5bc054edf"},
      #       :options     => {},
      #       :plan        => "free",
      #       :plan_option => nil
      #     }
      #   ]

      # TODO: The upper level call should catch exceptions and do the
      # exit, but I don't want to mess with that right now.
      unless stone_binding
        # raise "No stone service found" unless stone_binding
        puts("No stone service found: exiting staging from ensure_bound_stone")
        exit 1
      end
      stone_binding
    end

    # stone_binding will look like:
    #   {
    #     :label       => "maglev-0.8",
    #     :tags        => ["maglev", "maglev-0.8", "stone"],
    #     :name        => "maglev-f3736",
    #     :credentials => {:hostname=>"192.168.109.132"},
    #     :options     => {},
    #     :plan        => "free",
    #     :plan_option => nil
    #   }
    def stone_binding
      @stone_binding ||= @plugin.bound_services.detect {|s| s[:label] =~ /maglev/}
    end
  end

  def self.plugin_for(framework_plugin)
    case framework_plugin.environment[:runtime]
    when /maglev/
      MaglevStaging.new(framework_plugin)
    else
      new(framework_plugin)
    end
  end

  def initialize(framework_plugin)
    raise "Framework plugin nil" unless framework_plugin
    @plugin = framework_plugin
  end

  # Return environment variables specific to the runtime.  We now have
  # available service bindings, so we can use those if needed to
  # customize for this particular instance.
  def runtime_env_vars
    {}
  end

  # Does any checks needed before we start creating the app
  # directoreis, copying source, etc.
  def check_staging_prerequisites
    true
  end

  # This hook method is called as the last step in
  # stage_application().
  def last_chance
    true
  end
end
