module VCAP
  module Runtime
    module Maglev
      class NilLogger
        def warn(msg)
        end

        def debug(msg)
        end
      end

      class Stone

        attr_reader :maglev_home, :name

        # Initialize a new instance given $MAGLEV_HOME and the name of
        # the stone.
        def initialize(maglev_home, name="maglev", logger=nil)
          @maglev_home = maglev_home
          @name = name
          @logger = logger || NilLogger.new
          raise "Invalid maglev_home #{@maglev_home.inspect}" unless File.directory? @maglev_home
        end

        # def running?
        #   VCAP.process_running? pid
        # end

        # def kill(sig=9)
        #   raise "Not Implemented"
        #   Process.kill(sig, pid) if running?
        # end

        # # Call exec to start the stone. (does not return).
        # # We are in the child, so we can muck with ENV freely.
        # def exec_start_stone
        #   setup_maglev_env
        #   cmd = "#{File.join(maglev_home, 'gemstone', 'bin', 'startstone')} #{name}"
        #   exec(cmd)
        # rescue => e
        #   @logger.warn("exec of startstone failed: #{e.inspect}")
        #   raise e
        # end

        # Create the files necessary to run this stone.
        # These files include:
        #    $MAGLEV_HOME/etc/conf.d/#{self.name}.conf
        #    $MAGLEV_HOME/data/#{self.name}/*
        def create_stone_files
          raise "Config file #{config_file()} already exists" if File.exist?(config_file())
          raise "Extent #{data_dir} already exists" if dbf_exists?

          cmd = "rake stone:create[#{name}]"
          Dir.chdir(maglev_home) { maglev_system(cmd) }
          raise "Failed to create stone dbf for #{name}" unless dbf_exists?

        rescue => e
          @logger.warn("create_stone_files(): ERROR #{e.inspect}")
          raise e
        end

        def dbf_exists?
          File.exist?(File.join(data_dir, 'extent', 'extent0.ruby.dbf'))
        end

        # Remove the files for this stone (i.e., blow away the repository).
        # Removes all files created in create_stone_files().  The stone process
        # should already be stopped.
        def remove_stone_files
          @logger.debug("remove_stone_files(): #{name}")
          cmd = "rake stone:destroy[#{name}]"
          Dir.chdir(maglev_home) { maglev_system(cmd) }
        end

        # $MAGLEV_HOME/etc/conf/#{name}.conf
        def config_file
          @config_file ||= File.join(maglev_home, "etc", "conf.d", name + ".conf")
        end

        # $MAGLEV_HOME/data/#{name}/
        def data_dir
          @data_dir ||= File.join(maglev_home, "data", name)
        end

        # Run a command and ensure $MAGLEV_HOME is set
        def maglev_system(string)
          system("MAGLEV_HOME=#{maglev_home} #{string}")
        end

        # Run a command and ensure $GEMSTONE is set
        def gemstone_system(string)
          setup_minimal_gemstone_env
          system("#{string}")
        end

        def get_pid_from_gslist
          # Avoid using setup_maglev_env, as this is a long-lived process and
          # we may be managing many stones.  $GEMSTONE, $GEMSTONE_GLOBAL_DIR
          # should be safe, since they are per node, not per stone.
          setup_minimal_gemstone_env

          cmd = "#{File.join(maglev_home, 'gemstone', 'bin', 'gslist')} -p #{name}"
          `#{cmd}`.chomp.to_i
        end

        # Wait for the stone to start, and return the PID of stoned
        def waitstone
          cmd = "#{File.join(maglev_home, 'gemstone', 'bin', 'waitstone')} #{name}"
          gemstone_system(cmd)
          pid = get_pid_from_gslist
          raise "gslist returned bad pid #{pid}" unless VCAP.process_running? pid
          pid
        end

        # MagLev needs both GEMSTONE and GEMSTONE_GLOBAL_DIR to run items in
        # $GEMSTONE/bin
        def setup_minimal_gemstone_env
          ENV['GEMSTONE']            ||= File.join(maglev_home, 'gemstone')
          ENV['GEMSTONE_GLOBAL_DIR'] ||= maglev_home

          ['GEMSTONE_GLOBAL_DIR', 'GEMSTONE'].each do |key|
            raise "$#{key} does not exist: #{ENV[key].inspect}" unless File.exist? ENV[key]
          end
        end

        def setup_maglev_env
          # Since this process is long lived, do NOT use ||= for the ENV
          # assignments.  Do we need to be thread safe too?
          ENV['MAGLEV_HOME']         = maglev_home
          ENV['GEMSTONE']            = File.join(maglev_home, 'gemstone')
          ENV['GEMSTONE_GLOBAL_DIR'] = maglev_home
          ENV['GEMSTONE_LOGDIR']     = File.join(maglev_home, 'log', name)
          ENV['GEMSTONE_LOG']        = File.join(ENV['GEMSTONE_LOGDIR'], name + '.log')
          ENV['GEMSTONE_DATADIR']    = File.join(maglev_home, 'data', name)
          ENV['GEMSTONE_SYS_CONF']   = File.join(maglev_home, 'etc', 'system.conf')
        end
      end
    end
  end
end
