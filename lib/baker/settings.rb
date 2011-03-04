# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

#require 'fhsmap'
class Dir
  def self.map(d); d; end
end

require 'ftools'
require 'yaml'
require 'singleton'

require 'succ/object/setters'
require 'succ.new/attributes'


module Baker

  # Constants
  
  # use fhs configuration to map directories to other locations,
  # and thus conform the system to your distribution.

  #USE_FHS = true

  NAMESPACE = 'baker.rubyforge.org'
  
  FILE_TEMPLATE = "%s--%s"
  
  SYS_DIRS = {
    :tmp_dir       => '/tmp/baker',
    :etc_dir       => '/etc/baker',
    :templates_dir => '/etc/baker/templates'
  }
  
  BASE = '/bld/'
  
  BASE_DIRS = {
    :config_dir    => BASE + 'config',
    :tools_dir     => BASE + 'tools',
    :build_dir     => BASE + 'build',
    :source_dir    => BASE + 'sources',
    :catalog_dir   => BASE + 'catalog',
    :resource_dir  => BASE + 'catalog/resources',
    :recipe_dir    => BASE + 'catalog/recipes'
  }

  DEFAULT_CONFIG_FILES = {
    :catalog_config => 'catalog-configuration',
    :build_config   => 'build-configuration'
  }

  # To help in the use of local mirrors
  REGIONS = [
    'Unspecified',
    'North America',
    'South America',
    'Europe',
    'Australia',
    'Asia'
  ]

  # ARCHITECTURES::
  # currently supported architectures are in the form of a hash:
  # { cpu => [generic, full, march], ...}
  ARCHITECTURES = {
    'i386' =>         [ 'i386', 'i386-pc-linux-gnu', 'i386' ],
    'i486' =>         [ 'i386', 'i486-pc-linux-gnu', 'i486' ],
    'i586' =>         [ 'i386', 'i586-pc-linux-gnu', 'i586' ],
    'i686' =>         [ 'i386', 'i686-pc-linux-gnu', 'i686' ],
    'pentium' =>      [ 'i386', 'i586-pc-linux-gnu', 'pentium' ],
    'pentium-mmx' =>  [ 'i386', 'i586-pc-linux-gnu', 'pentium-mmx' ],
    'pentiumpro' =>   [ 'i386', 'i586-pc-linux-gnu', 'pentiumpro' ],
    'pentium2' =>     [ 'i386', 'i586-pc-linux-gnu', 'pentium2' ],
    'pentium3' =>     [ 'i386', 'i686-pc-linux-gnu', 'pentium3' ],
    'pentium4' =>     [ 'i386', 'i686-pc-linux-gnu', 'pentium4' ],
    'k6' =>           [ 'i386', 'i586-pc-linux-gnu', 'k6' ],
    'k6-2' =>         [ 'i386', 'i586-pc-linux-gnu', 'k6-2' ],
    'k6-3' =>         [ 'i386', 'i586-pc-linux-gnu', 'k6-3' ],
    'athlon' =>       [ 'i386', 'i686-pc-linux-gnu', 'athlon' ],
    'athlon-tbird' => [ 'i386', 'i686-pc-linux-gnu', 'athlon-tbird' ],
    'athlon4' =>      [ 'i386', 'i686-pc-linux-gnu', 'athlon4' ],
    'opteron' =>      [ 'x86_64', 'x86_64-pc-linux-gnu', nil ],
    'athlon64' =>     [ 'x86_64', 'x86_64-pc-linux-gnu', nil ]
  }

    
  # = SettingsClass
  #  
  # Baker's main configuration settings class
  #
  class SettingsClass
    include Singleton
    
    # options    
    def_attr :opt_root=, :opt_root => :to_s
    def_attr :opt_verbose,  :opt_batch,  :opt_force,  :opt_ignore,  :opt_pretend,  :opt_redo,  :opt_use
    def_attr :opt_verbose=, :opt_batch=, :opt_force=, :opt_ignore=, :opt_pretend=, :opt_redo=, :opt_use=

    # locations
    def_attr :tmp_dir, :etc_dir, :templates_dir
    def_attr :config_dir, :tools_dir, :build_dir, :source_dir, :catalog_dir, :resource_dir, :recipe_dir
    
    # default config files
    def_attr :catalog_config, :build_config
    
    def initialize
      SYS_DIRS.each_pair{ |k,d| instance_variable_set( "@#{k}", Dir.map( d ) ) }
      BASE_DIRS.each_pair{ |k,d| instance_variable_set( "@#{k}", opt_root + d ) }
      DEFAULT_CONFIG_FILES.each_pair { |k,d| instance_variable_set( "@#{k}", d ) }
    end
    
    def file_template; FILE_TEMPLATE; end
    def build_template; "#{build_dir}/#{FILE_TEMPLATE}"; end
    
  end  # SettingsClass
  

  
  # = BuildConfigClass
  #
  class BuildConfigClass
    include Singleton
    
    def_attr :cc
    
    def initialize
      build_config_path = File.join(Settings.config_dir, Settings.build_config)
      if ! FileTest.exists?( build_config_path )
        raise IOError, "Could not find build configuration file at: #{build_config_path}"
      end
      set_instances( YAML::load( File.new(build_config_path) ) )
    end
    
  end  # BuildConfigClass
  
  
  
  
  module FileTools
  
    # search for a file, works like a simple find shell command
    def findfile(root_dir, filepath_pattern, exclude_paths=[])
      path_match = nil
      re = Regexp.new(filepath_pattern)
      Find.find(root_dir) do |path|
        exclude_paths.each { |x| Find.prune if path =~ /^#{root_dir}\/#{x}/ }
        if re.match(path.sub(root_dir,''))
          path_match = path
          break
        end
      end
      path_match
    end
  
    #== methods for package and source paths

    # returns the dir location of source package file
    def source_package_dir
      Settings.source_dir #% [@program, @version]
    end

    # returns the full path to the source package file
    def source_package_file
      pkg_file = nil
      pkg_dir = self.source_package_dir
      @source_urls.each do |url|
        poss_pkg_file = File.join(pkg_dir, File.basename(url[0]))
        if File::exists?(poss_pkg_file)
          pkg_file = poss_pkg_file
          break
        end
      end
      pkg_file
    end

    def build_dir
      Settings.build_dir % [@program, @version]
      #File.join(Settings.pkg_dir,"#{@program}--#{@version}", Settings.build_dirname)
    end

    #
    def source_dir(chrootenv=false)
      src_dir = nil
      if chrootenv
        bld_dir = "/#{Settings.build_dirname}"
      else
        bld_dir = self.build_dir
      end
      if File.directory?(bld_dir)
        poss_src_dir = Dir.entries(bld_dir).select do
          |e| e != '.' and e != '..' and File.directory?(File.join(bld_dir,e))
        end
        if poss_src_dir.length > 1
          raise BakerError, "more than one source directory exists for #{@program}--#{@version}"
        end
        src_fn = poss_src_dir[0]
        src_dir = File.join(bld_dir,src_fn) if src_fn
      end
      return src_dir  # will return nil if dir not found
    end

  end  # FileTools
  

  # These are what's used to access the above singleton classes
  
  Settings = SettingsClass.instance
  BuildConfig = BuildConfigClass.instance
    
  
end  # Baker
