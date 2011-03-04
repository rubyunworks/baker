# Baker - The Delicious Program Maker
# Copruight (c) 2004 PsiT Corporation

# LICENSE HERE

require 'yaml'
require 'ftools'
#require 'find'  # don't think needed anymore
#require 'digest/md5'
#require 'open-uri'

require 'succ/object'

require 'baker/module'
require 'baker/settings'
#require 'baker/filetools'
require 'baker/download'
require 'baker/catalog'
require 'baker/eval_scripter'

module Baker

  # = ResourceManager
  #
  class ResourceManager

    # recipe_lookup::        hash of { 'recipe file name' => recipe_object } mashalled from the yaml file
    # selected_recipes::     list of the recipe file names passed in on the command line
    # prioritized_recipes::  is the above plus the dependent recipes in prioritized order

    attr_reader :selected_resources, :priorities  #:prioritized_resources
    
    # 
    def initialize(selected_resources)
      temp_program = 'bake-session'
      temp_version = Time.now.strftime("%Y.%m.%d.%I.%m")
      @selected_resources = selected_resources
      @session_collection = ResourceCollection.new( temp_program, temp_version, selected_resources )
    end

    def dependency_tree(recalc=false)
      @dependency_tree = nil if recalc
      @dependency_tree ||= calc_dependency_tree(@session_collection)
    end

    def dependency_recursion(recalc=false)
      @dependency_recursion = nil if recalc
      @dependency_recursion ||= calc_dependency_recursion(dependency_tree)
    end

    # returns a two element array of resource conflicts and install conflicts
    def resource_conflicts(recalc=false)
      @resource_conflicts = nil if recalc
      @resource_conflicts ||= calc_resource_conflicts(dependency_tree)
    end

    def install_conflicts(recalc=false)
      @install_conflicts = nil if recalc
      @install_conflicts ||= calc_install_conflicts(dependency_tree)
    end
    
    def priorities(recalc=false)
      @priorities = nil if recalc
      @priorities ||= calc_priorities(dependency_tree)
    end

    
    ### check for potential problems
    
    def check_list
      if dependency_recursion
        raise BakerError, "resource recursion detected"
      end
      problem_list = missing_dependencies
      if !problem_list.empty?
        raise DependencyError, "missing dependencies: #{problem_list.join(',')}"
      end
      problem_list = resource_conflicts
      if !problem_list.empty?
        raise ConflictError, "resource conflicts: #{problem_list.join(',')}"
      end
      problem_list = install_conflicts
      if !problem_list.empty?
        raise ConflictError, "installed conflicts: #{problem_list.join(',')}"
      end
    end

    
    ### dependency calculation methods
    
    # produces a complete dependency tree
    def calc_dependency_tree(resrc, already=[])
      tree = {}
      resrc.resolved_dependencies.each do |rk|
        if already.include?(rk)
          tree[rk] = nil
        else
          already << rk
          r = Catalog.get(rk)
          branch = calc_dependency_tree(r, already)
          tree[rk] = (branch == {} ? true : branch)
        end
      end
      resrc.unresolved_dependencies.each do |ur|
        tree[ur] = false
      end
      tree
    end

    # checks dependency tree for recursion (pass in dependency tree)
    def calc_dependency_recursion(dep_branch)
      rec = nil
      case dep_branch
      when Hash
        dep_branch.each_value do |v|
          rec ||= calc_dependency_recursion?(v)
        end
      when nil
        rec = true
      else
        rec = false
      end
      rec
    end

    # returns a list of missing dependencies (pass in dependency tree)
    def calc_missing_dependencies(dep_branch, key=nil)
      miss = []
      case dep_branch
      when Hash
        dep_branch.each do |k,v|
          miss << calc_missing_dependencies(v,k)
        end
      when false
        miss << key if key
      end
      miss.flatten
    end

    # returns list of recipes in the order they are to be processed (pass in dependency tree)
    def calc_priorities(dep_branch, key=nil)
      priors = []
      case dep_branch
      when Hash
        dep_branch.each do |k,v|
          priors << calc_priorities(v,k)
        end
      when true
        priors << key if key
      end
      priors.flatten
    end

    # conflicts between recipes (pass in dependency tree)
    def calc_resource_conflicts(dep_tree)
      priors = calc_priorities(dep_tree)
      # build list of recipes as tuples
      priority_tuples = priors.collect{|rk| n,v = rk.split('--'); Tuple.new( [n, v.split('.')].flatten )}
      # build list of possible conflicts as tuples
      possible_conflicts = priors.collect{|rk| r = Catalog.get(rk); r.conflicts}.flatten
      conflict_tuples = possible_conflicts.collect{|rk| n,v = rk.split('--'); Tuple.new( [n, v.split('.')].flatten )}
      # build list of conflicts
      conflicts = []
      conflict_tuples.each do |ct|
        priority_tuples do |pt|
          if ct.last[-1..-1] = '+' and pt > ct
            conflicts << "#{pt[0]}--#{pt[1..-1].join('.')}"
          elsif ct == pt
            conflicts << "#{pt[0]}--#{pt[1..-1].join('.')}"
          end
        end
      end
      conflicts
    end

    # existing install conflicts
    # returns a hash list of recipes with conflicts
    def calc_install_conflicts(dep_tree)
      priors = calc_priorities(dep_tree)
      iconflicts = {}
      priors.each do |rk|
        r = Catalog.get(rk)
        r.install_conflicts.each do |ic_key, ic_indicators|
          if File.exists?(ici)
            iconflicts[rk] ||= []
            iconflicts[rk] << ic_key
          end
        end
      end
      return iconflicts
    end

    
    #== action commands

    # download source package
    def fetch
      if Settings.opt_batch
        priorities.each {|rn| Catalog.get(rn).fetch}
      else
        Catalog.get(priorities.last).fetch
      end
    end

    # extract source
    def extract
      if Settings.opt_batch
        priorities.each {|rn| Catalog.get(rn).extract}
      else
        r = Catalog.get(priorities.last)
        raise(BakerError, "source package has not been downloaded") if !r.fetched?
        r.extract
      end
    end

    # patch source
    def patch
      if Settings.opt_batch
        priorities.each {|rn| Catalog.get(rn).patch}
      else
        r = Catalog.get(priorities.last)
        raise(BakerError, "source package has not been extracted") if !r.extracted?
        Catalog.get(priorities.last).patch
      end
    end

  end

  
  # = ResourceCommon
  #
  module ResourceCommon
    include EvalScripter
  
    def initialize_yaml(v,t=nil)
      super
      resolve_dependencies
    end

    attr_reader :resolved_dependencies, :unresolved_dependencies

    # function to resolve names of dependencies, applicable_compliment and applicable_supplement
    def resolve_dependencies
      puts "resolving dependency names for #{program} #{version}" if $DEBUG
      dep_names = dependencies | applicable_compliment | applicable_supplement
      @resolved_dependencies, @unresolved_dependencies = *Catalog.resolve_names(dep_names)
    end

    # collects the compliemts which are conditional dependencies
    # dependent on aviod in current build configuration
    def applicable_compliment
      compliment.find_all do |c|
        !BuildConfig.instance.avoid.collect{|a| a.downcase}.include?(c.split(/(\s+|--)/)[0].downcase)
      end
    end

    # collects the suppliments which are conditional dependencies
    # dependent on ensure in current build configuration
    def applicable_supplement
      supplement.find_all do |s|
        BuildConfig.instance.ensure.collect{|e| e.downcase}.include?(s.split(/(\s+|--)/)[0].downcase)
      end
    end

    #
    def unresolved_dependencies?
      (@unresolved_dependencies.length > 0)
    end
    
  end
  
  
  # = Resource
  # This is a class to access baker resource files and
  # run checks on the system using that information
  # plus download, unpack, and patch sources
  class Resource
    include ResourceCommon
    #include Filetools
    
    yamlize('resource', 'baker.rubyforge.org,2004')
    
    reader   :name, :parent
    accessor :program, :version, :updated, :maintainer,
             :dependencies, :conflicts, :compliment, :supplement,
             :install_indicators, :install_conflicts, :install_size,
             :source_urls, :patch_urls, :bittorrents,
             :distributions, :categories, :notes
    scripter :brief, :description, :website
    
        
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
                                                   Catalog.local_region,
                                                   spkg_dir,
                                                   Settings.opt_force )
      raise(BakerError, "source package fetch failed") if !success
      #if Settings.opt_batch  # fetch dependencies if in batch mode
      #  already << @key
      #  @resolved_dependencies.each do |rd|
      #    Catalog.get(rd).fetch(already) if !already.include?(rd)
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
      #    Catalog.get(rd).extract(already) if !already.include?(rd)
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
          Catalog.get(rd).patch(already) if !already.include?(rd)
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
  
  
  # = ResourceCollection
  # This is a psudeo resource. It does not represent a single
  # program on its own but rather only serves as means to
  # collect other recipes together
  # a recipe collection just pretends to do something,
  # but really only its dependencies actually do.
  class ResourceCollection
    include ResourceCommon

    reader :collection, :version, :resources
    writer :updated, :maintainer, :categories, :notes
    scripter :brief, :description, :website
  
    yamlize('resource_collection', 'baker.rubyforge.org,2004')
    #yamlize('Baker::ResourceCollection')
    
    def initialize(collection, version, resources=[])
      @collection = collection
      @version = version
      @resources = resources
      @updated = ""
      @maintainer = ""
      @brief = ""
      @description = ""
      @website = ""
      @categories = []
      @notes = ""
      resolve_dependencies
    end
    
    # these allow Resource and RecsourceCollection to share some methods
    def program; @collection ; end
    def dependencies; @resources; end
    def compliment; []; end
    def supplement; []; end
    def install_size; "n/a" ; end
    def installed?; nil ; end
    
  end  # ResourceCollection

end  # Baker
