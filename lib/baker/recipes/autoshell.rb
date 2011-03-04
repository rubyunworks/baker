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

  class AutoShellRecipe < BaseRecipe
    include Shell
  
    scripter :test_script, :uninstall_script

    #
    def to_yaml_properties
      [ :program, :version, :updated, :maintainer,
        :build_size, :noarch, :system_files, :notes
        :config_params, :setup_params, :test_params,
        :install_params, :clean_params, :uninstall_params,
        :test_script, :uninstall_script
      ].collect { |m| "@#{m}" }
    end
    def to_yaml_type; '!Baker::AutoShellRecipe'; end

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
      config_script = <<-EOS
        make config #{config_params}
      EOS
      puts config_script if $VERBOSE
      shell(config_script, source_dir(true))
    end

    def sub_setup
      setup_script = <<-EOS
        make setup #{setup_params}
      EOS
      puts setup_script if $VERBOSE
      #@already_installed = self.installed? if @already_installed == nil
      #if @already_installed and !Settings.opt_redo
      #  raise BakerError, "#{@program} is already installed (use -r to recompile)"
      #end
      shell(setup_script, source_dir)
    end

    # test is not in the execution chain by default (should it be?)
    # TODO: make shell option -t (?)
    def sub_test
      test_script = @test_script || <<-EOS
        make test #{test_params}
      EOS
      puts test_script if $VERBOSE
      shell(test_script, source_dir)
    end

    # this needs to be fake rooted (TO DO!!!!!!!)
    def sub_install
      @already_installed = installed? if @already_installed == nil
      if @already_installed and !Settings.opt_redo
        raise BakerError, "#{@program} is already installed (use -r to reinstall)"
      end
      install_script = <<-EOS
        make install #{install_params}
      EOS
      puts install_script if $VERBOSE
      shell(install_script, source_dir)
    end

    def sub_clean
      clean_script = <<-EOS
        make clean #{clean_params}
      EOS
      puts clean_script if $VERBOSE
      shell(clean_script, source_dir)
    end
    
    # TODO!!!! ???
    def sub_uninstall
      uninstall_script = @uninstall_script || <<-EOS
        make uninstall #{uniinstall_params}
      EOS
      puts uninstall_script if $VERBOSE
      shell(uninstall_script, source_dir)
    end

  end  # ShellRecipe

end 
 
