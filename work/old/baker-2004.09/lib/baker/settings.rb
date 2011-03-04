# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

require 'fhsmap'

module Kernel
  def with(obj, &blk)
    obj.instance_eval(&blk)
  end
  alias _p p
  def p(*args)
    _p(*args)
    return *args
  end
end

module Baker

  # use fhs configuration to map directories to other locations,
  # and thus conform the system to your distribution.

  # ARCHITECTURES::
  # currently supported architectures are in the form of a hash:
  # { cpu => [generic, full, march], ...}

  #USE_FHS = true

  DIRECTORIES = {
    :etc    => '/etc/baker',
    :tmp    => '/tmp/baker',
    :src    => '/var/lib/baker/src',
    :cat    => '/var/lib/baker/cat',
    :pkg    => '/pkg',
    :bcfg   => '/var/lib/baker/builds'
  }

  FILENAMES = {
    :cat_config      => 'cat-config',
    :current_config  => 'current',
    :default_config  => 'default',
    :undo_config     => 'undo',
    :temp_config     => 'temporary'
  }

  DIRNAMES = {
    :templates       => 'templates',
    :build           => 'build',
    :root            => 'root',
    :dep             => 'require'
  }

  REGIONS = [
    'Unspecified',
    'North America',
    'South America',
    'Europe',
    'Australia',
    'Asia'
  ]

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


  # baker's main configuration settings class
  class Settings
    class << self

      attr_accessor :opt_verbose, :opt_batch, :opt_force, :opt_ignore,
                    :opt_pretend, :opt_redo, :opt_use

      def cat_config_file
        Dir.map( File.join(DIRECTORIES[:etc], FILENAMES[:cat_config]) )
      end

      def templates_dir
        Dir.map( File.join(DIRECTORIES[:etc], DIRNAMES[:templates]) )
      end

      def build_config_dir
        Dir.map( File.join(DIRECTORIES[:etc], BUILD_CONFIG_DIRNAME) )
      end

      def current_config_file
        Dir.map( File.join(DIRECTORIES[:bcfg], FILENAMES[:current_config]) )
      end

      def default_config_file
        Dir.map( File.join(DIRECTORIES[:bcfg], FILENAMES[:default_config]) )
      end

      def undo_config_file
        Dir.map( File.join(DIRECTORIES[:bcfg], FILENAMES[:undo_config]) )
      end

      def temp_config_file
        Dir.map( File.join(DIRECTORIES[:bcfg], FILENAMES[:temp_config]) )
      end

      def source_dir
        Dir.map( DIRECTORIES[:src] )
      end

      def catalog_dir
        Dir.map( DIRECTORIES[:cat] )
      end

      def pkg_dir
        Dir.map( DIRECTORIES[:pkg] )
      end

      def tmp_dir
        Dir.map( DIRECTORIES[:tmp] )
      end

      def build_dir
        # %s--%s are for program name and version
        Dir.map( File.join(DIRECTORIES[:pkg],"%s--%s",DIRNAMES[:build]) )
      end

      def build_dirname
        DIRNAMES[:build]
      end

      def root_dirname
        DIRNAMES[:root]
      end

      def dep_dirname
        DIRNAMES[:dep]
      end

      def opt_use_filepath
        File.join( Dir.map( DIRECTORIES[:bcfg] ), opt_use )
      end

    end
  end

end
