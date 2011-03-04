require 'baker/recipes/base'
require 'baker/shell'

module Baker
  
  # ShellRecipe
  #
  # all details of preparing, compiling and installing
  # are handled by yaml embedded shell scripts
  #
  # notes:
  #   - could used improved security so any "renegade" recipes can't hurt user's system
  #     is there a way to do some sort of sandboxing?
  #   - register a generic type with yaml rather then ---!ruby/object

  class ShellRecipe < BaseRecipe
    include Shell
    
    scripter :config_script, :setup_script, :test_script,
             :install_script, :clean_script, :uninstall_script

    #
    def to_yaml_properties
      [ :program, :version, :updated, :maintainer,
        :build_size, :noarch, :system_files, :notes,
        :config_script, :setup_script, :test_script,
        :install_script, :clean_script, :uninstall_script
      ].collect { |m| "@#{m}" }
    end
    def to_yaml_type; '!Baker::ShellRecipe'; end
    
    # which attributes are available to recipe shell scripts
    def methods_available_to_script
      [ 'program', 'version', 'updated, :maintainer',
        'build_size', 'noarch', 'system_files',
        'resource.categories', 'resource.dependencies', 'resource.conflicts',
        'resource.compliment', 'resource.supplement'  
      ].collect { |m| "#{m}" }
    end

    # these simply run shell scripts given in the yaml recipe
    # there are general substitutions for many of the receipe's instance variables
    # and all of the build variables (see shell)

    def sub_config
      puts config_script
      shell(config_script, source_dir(true))
    end

    def sub_setup
      #@already_installed = self.installed? if @already_installed == nil
      #if @already_installed and !Settings.opt_redo
      #  raise BakerError, "#{@program} is already installed (use -r to recompile)"
      #end
      shell(setup_script, source_dir)
    end

    # test is not in the execution chain by default (should it be?)
    # TODO: make shell option -t (?)
    def sub_test
      shell(test_script, source_dir)
    end

    # this needs to be fake rooted (TO DO!!!!!!!)
    def sub_install
      @already_installed = installed? if @already_installed == nil
      if @already_installed and !Settings.opt_redo
        raise BakerError, "#{@program} is already installed (use -r to reinstall)"
      end
      shell(install_script, source_dir)
    end

    def sub_clean
      shell(clean_script, source_dir)
    end
    
    # TODO!!!!
    def sub_uninstall
      shell(uninstall_script, source_dir)
    end

  end  # ShellRecipe

end 
