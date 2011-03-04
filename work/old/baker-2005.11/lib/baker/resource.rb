require 'baker/support'
require 'baker/config'

module Baker
  # Resource encapsulates infomation about an application
  # such as where to get it and what dependencies it has.
  class Resource
    include Config
    yamlize('resource', 'baker.rubyforge.org,2004')
    # Attributes loaded from file
    attr_accessor :program,
                  :version,
                  :updated,
                  :maintainer,
                  :dependencies,
                  :conflicts,
                  :compliment,
                  :supplement,
                  :install_indicators,
                  :install_conflicts,
                  :install_size,
                  :source_urls,
                  :patch_urls,
                  :package_dir,  # if differs from source url basename
                  :bittorrents,
                  :distributions,
                  :categories,
                  :notes,
                  :brief,
                  :description,
                  :website
    # Calculated on load attribute
    attr_reader :recipe_path
    # Return the list of package file names
    def packages(recalc=false)
      @packages ||= nil
      if !@packages or recalc
        pkgs = []
        source_urls.each { |file, location, checksum, size|
          pkgs |= [ File.basename( file ) ]
        }
        @packages = pkgs
      end
      @packages
    end
    # Return a hash of download urls
    def package_urls(recalc=false)
      @package_urls ||= nil
      if !@package_urls or recalc
        keyd = Hash.new{ |h,k| h[k] = [] }
        source_urls.collect { |file, location, checksum, size|
          keyd[File.basename(file)] << [file, location, checksum, size]
        }
        @package_urls = keyd
      end
      @package_urls
    end
  end # Resource
  # Resource class-module methods.
  class << Resource
    def load( name, version=nil )
      matches = nil
      Dir.chdir( File.join( RESDIR ) ) do
        matches = Dir.glob("#{name}*")
      end
      return nil if matches.empty?
      file = select_version( name, version, matches )
      path = File.join( RESDIR, file )
      res = YAML::load( File.open( path ) )
      res.instance_eval { @recipe_path = path }
      res
    end
    # TODO improve!
    def select_version( name, version, list )
      ver = {}
      list.each do |m|
        if md = %r{^#{name}--(.*)}.match( m )
          ver[ md[1].split(/[-._]/) ] = m
        end
      end
      ver[ver.keys.sort.last]
    end
  end # class << Resource
end
