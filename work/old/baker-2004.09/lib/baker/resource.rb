# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

require 'yaml'
require 'succ/object'
require 'ftools'
#require 'find'  # don't think needed anymore
#require 'digest/md5'
#require 'open-uri'

require 'baker/module'
require 'baker/settings'
require 'baker/dependency'
require 'baker/filetools'
require 'baler/download'
require 'baker/catalog'

module Baker

  # Resource
  #
  # this is a class to access baker resource files and
  # run checks on the system using that information
  # plus download, unpack, and patch sources
  class Resource
    include Filetools
    include Dependency
    include EvalScripter
    
    YAML.add_private_type( 'Baker::Resource' ) { |t, v| Baker::Resource.new(v) }

    reader :name, :parent

    accessor :program, :version, :updated, :maintainer,
             :dependencies, :conflicts, :compliment, :supplement,
             :install_indicators, :install_conflicts, :install_size,
             :source_urls, :patch_urls, :bittorrents,
             :distributions, :categories, :notes

    scripter :brief, :description, :website
    
    def to_yaml_type; '!Baker::Resource'; end
    
    def initialize(h={})   
      with_instances(h)
    end

    
    #== methods

    # if only one word is given it is assumed a definte filepath
    # if two or more words then it uses findfile (see below)
    # (actually i think the find feature should probably be removed)
    def installed?
      success = false
      @install_indicators.each do |ii|
        if ii.include?(' ')
          root, pattern, exclusions = ii.split(' ')
          success = findfile(root, pattern, exclusions) ? true : false
        else
          success = FileTest::exists?(ii)
        end
        break if success
      end
      success
    end

    # download the source package
    def fetch(already=[])
      spkg_dir = self.source_package_dir  # create source pkg dir if it does not exist
      File.makedirs(spkg_dir) if !File.directory?(spkg_dir)
      success = DownloadManager.regional_download( self.source_urls,
                                                   Catalog.instance.local_region,
                                                   spkg_dir,
                                                   Settings.opt_force )
      raise(BakerError, "source package fetch failed") if !success
      #if Settings.opt_batch  # fetch dependencies if in batch mode
      #  already << @key
      #  @resolved_dependencies.each do |rd|
      #    Catalog.instance.get(rd).fetch(already) if !already.include?(rd)
      #  end
      #end
      return success
    end

    def fetched?
      self.source_package_file ? true : false
    end

    # extract source package
    def extract(already=[])
      success = false # assume the worst
      pkg_file = self.source_package_file  # do we have the source package?
      raise(BakerError, "source package not found for #{@program}--#{version} (has it been downloaded?)") if !pkg_file
      pkg_fn = File.basename(pkg_file)
      bld_dir = self.build_dir  # if build dir does not exist then create it
      File.makedirs(bld_dir) if !FileTest::exists?(bld_dir)
      # if no unpacked source dir exists or if the force option is set copy package to build dir and extract
      src_dir = self.source_dir
      if !src_dir or Settings.opt_force
        bld_pkg = File.join(bld_dir,pkg_fn)
        File.install(pkg_file,bld_dir)  # copies package file to build dir
        success = DownloadManager.extract(bld_pkg)  # extract
        raise(BakerError, "extraction of source package failed for #{@program}--#{@version}") if !success
        File.delete(bld_pkg)  # remove source package file from build dir
      end
      #if Settings.opt_batch  # extract dependencies if batch mode
      #  already << @key
      #  @resolved_dependencies.each do |rd|
      #    Catalog.instance.get(rd).extract(already) if !already.include?(rd)
      #  end
      #end
      return success
    end

    def extracted?
      self.source_dir ? true : false
    end

    # TO DO!!!!!!!!!
    def patch(already=[])
      #raise BakerError, "patching has not yet implemented"
      # patch dependencies if batch mode
      if Settings.opt_batch
        already << @key
        @resolved_dependencies.each do |rd|
          Catalog.instance.get(rd).patch(already) if !already.include?(rd)
        end
      end
    end

    # purge the upacked source directory and source file
    # this is a little on the unsafe side a the moment,
    # so it is left out for now
    def purge
      raise BakerError, "purging source has been disabled for the time being."
      #File.delete(self.source_package_file)
      #File.delete(build_dir)
      #system('rm -rf #{build_dir}')
    end

  end 
  
  
  # ResourceCollection
  #
  # this is a psudeo resource. it does not represent a single
  # program on its own but rather only serves as means to
  # collect other recipes together (under dependencies)
  # a recipe collection just pretends to do something.
  # but really only its dependencies actually do.
  # (this may change in the future to allow post
  # install proceessing at a collection level.)
  class ResourceCollection < Resource

    def to_yaml_type; '!Baker::ResourceCollection'; end
  
    def initialize(program, version, dependencies=[])
      self.program = program
      self.version = version
      self.dependencies = dependencies
      self.updated = ""
      self.maintainer = ""
      self.brief = ""
      self.description = ""
      self.website = ""
      self.categories = []
      self.install_size = 0
      self.install_indicators = []
      self.install_conflicts = {}
      self.conflicts = []
      self.compliment = []
      self.supplement = []
      self.no_architecture = []
      self.notes = ""
      super( :program => program, :version => version )
      resolve_dependencies if !dependencies.empty?
    end
    
  end  # ResourceCollection

end
