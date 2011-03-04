# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, LGPL

# Baker is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Baker is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Baker; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

#external libs
require 'yaml'

#internal libs
require 'error'
require 'settings'

module Baker

  #
  class BuildConfig

    attr_accessor :concurrent_threads,
                  :kernel_config,
                  :host, :target,
                  :cflags, :cppflags, :distcc,
                  :check, :strip, :thread_library,
                  :man_dirpath, :info_dirpath,
                  :prefix, :avoid, :ensure,
                  :cc, :cpp, :ldflags

    def initialize
      @concurrent_threads = 1                          # set maximum parallel jobs
      @host = nil                                      # host architecture (cpu)
      @target = nil                                    # target architecture (cpu)
      @kernel_config = ""                              # kernel .config file
      @cflags = []                                     # specify default c flags
      @cppflags = []                                   # specify default c++ flags
      @distcc = true                                   # use distcc to speed things up
      @check = false                                   # do 'make check' or equivalents
      @strip = false                                   # strip binaries
      @thread_library = "nptl"                         # linuxthreads or nptl
      @man_dir = ""                            # need?
      @info_dir = ""                           # need?
      @prefix = '/usr/local'                           # prefix for install location
      @avoid = []                                      # compliment programs to avoid
      @ensure = []                                     # supplement programs to ensure
      @cc = 'gcc'
      @cpp = ''
      @ldflags = ''
    end

    def to_yaml_properties
      [ '@concurrent_threads', '@host', '@target', '@cc', '@cpp', '@cflags', '@cppflags', '@ldflags',
        '@distcc', '@check', '@strip', '@thread_library', '@kernel_config', '@man_dir', '@info_dir',
        '@prefix', '@avoid', '@ensure' ]
    end

    # -- Class Methods ------------------------------------

    # homebrew singleton pattern (but retain new abilities)

    # load configuration file
    def BuildConfig.instance(reload=false)
      if !defined?(@@instance) or reload
        config_file = Settings.opt_use
        if !config_file
          if FileTest::exists?(Settings.current_config_file)
            @@instance = YAML::load(File.new(Settings.current_config_file))
          else
            raise BakerError, "could not find current build configuration:\n#{Settings.current_config_file}"
          end
        else
          if FileTest::exists?(Settings.opt_use_filepath)
            @@instance = YAML::load(File.new(Settings.opt_use_filepath))
          else
            raise BakerError, "could not find specified build configuration"
          end
        end
      end
      @@instance
    end

  end  # BuildConfig

  #
  class BuildConfigManager

    attr_accessor :buildconfig

    ##
    # configuration commands
    #
    # these allow you to manipulate some master build settings.
    # sets of these are stored in build configuration files.
    ##

    # current configuration help
    def arch
      arch_msg = "Supported Architectures:\n"
      ARCHITECTURES.each do |arch, desc|
        pad = ' ' * (15 - arch.length)
        arch_msg += "\t#{arch}#{pad}\t(#{desc[0]}, #{desc[1]}, #{desc[2]})\n"
      end
      return arch_msg
    end

    # show current configuration
    def show
      fstr = ''
      File.open(Settings.current_config_file) do |f|
        fstr = f.read
      end
      fstr
    end

    # configuration reset
    def reset_configuration
      File.syscopy(Settings.current_config_file, Settings.undo_config_file)
      File.syscopy(Settings.default_config_file, Settings.current_config_file)
      @buildconfig = BuildConfig.instance(true)
    end

    # configuration undo
    def undo_configuration
      File.syscopy(Settings.current_config_file, Settings.temp_config_file)
      File.syscopy(Settings.undo_config_file, Settings.current_config_file)
      File.syscopy(Settings.temp_config_file, Settings.undo_config_file)
      File.delete(Settings.temp_config_file)
      @buildconfig = BuildConfig.instance(true)
    end

    # use configuration
    def use_configuration(use_file)
      if !FileTest::exists?(File.join(Settings.build_config_dir,use_file))
        raise BakerError, "could not find specified configuration"
      end
      File.syscopy(Settings.current_config_file, Settings.undo_config_file)
      File.syscopy(File.join(Settings.build_config_dir,use_file), Settings.current_config_file)
      @buildconfig = BuildConfig.instance(true)
    end

    # save configuration
    def save_configuration(use_file)
      if use_file !~ /\w+/
        raise BakerError, "configuration name has invalid syntax or was not given"
      elsif [CURRENT_CONFIG_FILENAME, UNDO_CONFIG_FILENAME].include?(use_file)
        raise BakerError, "cannot use #{CURRENT_CONFIG_FILENAME} or #{UNDO_CONFIG_FILENAME} for configuration name"
      end
      File.syscopy(Settings.current_config_file, File.join(Settings.build_config_dir,use_file))
    end

    # remove configuration
    def remove_configuration(use_file)
      if use_file !~ /\w+/
        raise BakerError, "configuration name has invalid syntax or was not given"
      elsif [CURRENT_CONFIG_FILENAME, UNDO_CONFIG_FILENAME].include?(use_file)
        raise BakerError, "cannot use #{CURRENT_CONFIG_FILENAME}, #{DEFAULT_CONFIG_FILENAME} or #{UNDO_CONFIG_FILENAME} for configuration name"
      elsif !FileTest::exists?(File.join(Settings.build_config_dir,use_file))
        raise BakerError, "configuration '#{use_file}' does not exist"
      end
      File.delete(File.join(Settings.build_config_dir,use_file))
    end

    # edit configuration
    def edit_configuration
      if ENV['EDITOR']
        system "#{ENV['EDITOR']} #{Settings.current_config_file}"
      else
        raise BakerError, "EDITOR enviornment variable is not set"
      end
    end

  end  # BuildConfigManager

end
