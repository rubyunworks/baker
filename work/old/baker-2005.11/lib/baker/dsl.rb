require 'fileutils'
require 'digest/md5'

require 'baker/resource'
require 'baker/shell'

module Baker
  module RecipeDsl
    include Config
    include Shell
    ##
    # Setup up commands.
    def recipe( name, version=nil )
      @resource = Baker::Resource.load( name, version )
      puts "  ### Pretend Mode ###" if PRETEND
      prepare_package
    end
    def maintainer( name, email=nil )
      @maintainer = name
      @email = email
    end
    def date( date )
      @date = date
    end
    ##
    # These are the primary build commands.
    def configure( *params )
      return unless COMPILE
      params = check_parameters( *params )
      parameters = (master_parameters | params).join(' ')
      shell "./configure #{parameters}"
    end
    def make
      return unless COMPILE
      shell "make"
    end
    def make_test
      return unless TEST #and COMPILE
      shell "make test"
    end
    def make_install
      return unless INSTALL
      shell "make DESTDIR=#{install_directory} install"
    end
    def make_link
      return unless LINK
      link_current
      link_all
    end
    def make_clean
      return unless COMPILE
      shell "make clean"
    end
    ##
    # Directory methods
    def application_directory
      File.join( APPDIR, @resource.program )
    end
    def version_directory
      File.join( APPDIR, @resource.program, @resource.version )
    end
    alias_method :install_directory, :version_directory
    # Current version link
    def current_directory
      File.join( application_directory, 'current' )
    end
    # Resources
    def resource_directory
      File.join( APPDIR, @resource.program, 'rsc', @resource.version )
    end
    def source_directory
      File.join( resource_directory, 'src' )
    end
    def patch_directory
      File.join( resource_directory, 'patch' )
    end
    # Install directory
    #def install_directory
    #  File.join( APPDIR, @resource.program, @resource.version )
    #end
    #
    def package_directory
      unless src = @resource.package_dir
        tar = File.basename(@resource.source_urls[0][0])
        tar = tar.gsub(/\.(gz|tar|tbz|tgz|bz|bz2|bzip2|zip)$/, '')
        src = tar.gsub(/\.(gz|tar|tbz|tgz|bz|bz2|bzip2|zip)$/, '')
      end
      File.join( source_directory, src )
    end
    ##
    #
    def check_parameters( *params )
      return params
    end
    def master_parameters
      []
    end
    ##
    #
    def chdir( dir, &blk )
      puts "  cd #{dir}"
      unless PRETEND
        blk ? Dir.chdir( dir, &blk ) : Dir.chdir( dir )
      end
    end
    ##
    # The shell command
    def shell( cmdtext, force=false )
      puts "  #{cmdtext}"
      if PRETEND
        true
      else
        result = system cmdtext
        unless result or force
          puts "Command failed."
          exit 1
        end
        result
      end
    end
    ##
    # Prepare source for compile.
    def prepare_package
      unless File.directory?( source_directory )
        shell "mkdir -p #{source_directory}"
      end
      chdir PKGDIR
      download_source
      chdir source_directory
      unpack_source
      chdir package_directory
    end
    def download_source
      return unless DOWNLOAD
      # This needs to be improved to use the closest/fastest mirror.
      # Right now it just relies on the first mirror given.
      @resource.package_urls.each { |key, res|
        mirror = res[0]
        file, location, checksum, size = mirror[0],mirror[1],mirror[2],mirror[3]
        download( file, checksum, size )
      }
    end
    def unpack_source
      return unless UNPACK
      raise "No packages" if @resource.packages.empty?
      @resource.packages.each do |pkg|
        packagefile = File.join( PKGDIR, pkg )
        unpack( packagefile )
      end
    end

    def patch_source( which=nil )
      which ||= '*'
      patches = Dir.glob( File.join( PATCHDIR, which ) )
      patches.each { |p|
        patch( p )
      }
    end
    # The download method assumes it is in the directory
    # to which the give url is to be stored.
    def download( url, checksum=nil, size=nil )
      checksum = nil if checksum == ''
      #pkg = File.basename( url )
      #File.open( pkg, "w+" ) do |f|
      #  f << open( url ).read
      #end
      path = File.join( PKGDIR, File.basename(url) )
      unless checksum?( path, checksum )
        shell "wget #{url}"
      else
        puts "  # package found"
      end
    end
    # checksum
    def checksum?( path, match )
      md5 = nil
      if File.exists?( path )
        md5 = Digest::MD5.new( File.open( path ).read ).hexdigest
        puts "  # Warning: md5 checksum is not given in resource file" unless match
        puts "  # md5 checksum is #{md5}" if $VERBOSE
      end
      md5 == match
    end
    # unpack using system tools
    def unpack( path )
      #success = false
      #begin
        case path
        when /.*gz$/
          shell "tar -xzf #{path}"
        when /.*(bz|bz2)$/
          shell "tar -xjf #{path}"
        when /.zip$/
          shell "unzip #{path}"
        else
          success = false
        end
      #rescue
      #  success = false
      #else
      #  success = true
      #end
      #return success
    end
    # patch source
    def patch( patchfile )
      shell "patch -Np1 -i #{patchfile}"
    end
    # symbolic link (relative to current if not absolute)
    def link( target, lnk )
      if /^\// !~ target
        target = File.join( install_directory, target )
      end
      shell "ln -sfv #{target} #{lnk}"
    end
    # For installs that are simply a matter of copying over the source
    def copy_install
      shell "mkdir -p #{version_directory}"
      shell "cp -dR #{File.join(package_directory,'*')} #{install_directory}"
      link_current
    end
    # link_current
    def link_current
      link( version_directory, current_directory  )
    end
    # link installed package into system
    def link_all
      alldirs = Dir.glob( File.join( install_directory, "*/" ) )
      alldirs -= [ File.join( install_directory, 'var/' ) ]
      alldirs.each { |d|
        puts "cp -dRsf #{d} /#{File.basename(d)}"
      }
      #link( File.join(install_directory,'bin','*'), '/usr/bin/' )
      #link( File.join(install_directory,'lib','*'), '/usr/lib/' )
      ## man
      #9.times{ |i|
      #  link( File.join(install_directory,'man',"man#{i}",'*'), '/usr/man/man#{i}/' )
      #}
    end
  end
end
include Baker::RecipeDsl
