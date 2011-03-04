# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

require 'yaml'

require 'baker/module'
require 'baker/settings'
require 'baker/buildconfig'
require 'baker/catalog'
require 'baker/filetools'

module Baker

  # BaseRecipe
  #
  # this is the base class for all recipe subclasses, in itself rather useless.
  # create new recipes types by subclassing and def sub stage methods.
  class BaseRecipe
    include Filetools
    
    reader :name, :parent, :resource

    accessor :program, :version, :updated, :maintainer,
             :noarch, :build_size, :system_files, :notes

    #
    def initialize(program, version)
      @program = program
      @version = version
      #if @repositry
      #  @key = "#{repositry}/#{program.downcase}--#{version.to_s.downcase}"
      #else
      #  @key = "#{program.downcase}--#{version.to_s.downcase}"
      #end
    end

    #
    def initialize_post(name)
      @name = name
      resolve_dependencies
    end

    #== stage methods

    def prepare
      #raise BakerError, "unsafe to prepare in non-chroot evironment" if !Fakeroot.chroot?
      sub_prepare
    end

    def compile
      raise BakerError, "unsafe to compile in non-chroot evironment" if !Fakeroot.chroot?
      sub_compile
    end

    def test
      raise BakerError, "unsafe to test in non-chroot evironment" if !Fakeroot.chroot?
      sub_test
    end

    def install
      raise BakerError, "unsafe to install in non-chroot evironment" if !Fakeroot.chroot?
      sub_install
    end

    def clean
      #
      sub_clean
    end
    
    def uninstall
       #
       sub_uninstall
    end
    
    #== bug tracking

    # email a bug report to the package maintainer (TO DO)
    def bug_report
      raise BakerError, <<-EOS
        Bug reporting has not yet been implimented.
        Manually send a bug report to #{@maintainer}.
      EOS
    end

    #== CLASS METHODS

    #def Recipe.set_configuration
    #  @@buildconfig = BuildConfig.instance
    #  @@catalog = Catalog.instance
    #  @@fhs = FHSMap.instance
    #end

  end  # Recipe

end
