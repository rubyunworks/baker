# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

# external libs
require 'fileutils'
require 'yaml'

# internal libs
require 'baker/error'
require 'baker/settings'
require 'baker/catalog'
require 'baker/resource'
require 'baker/buildconfig'
require 'baker/dependency'
require 'baker/fakeroot'

module Baker

  # ResourceManager
  #
  # this is the primary interface class
  # it controls the over all functionality of baker

  class ResourceManager

    include Fakeroot

    # recipe_lookup::        hash of { 'recipe file name' => recipe_object } mashalled from the yaml file
    # selected_recipes::     list of the recipe file names passed in on the command line
    # prioritized_recipes::  is the above plus the dependent recipes in prioritized order

    attr_reader :priorities
    attr_reader :selected_recipes, :prioritized_recipes

    # 
    def initialize(selected_resources)
      @selected_recipes = selected_resources
      @session_collection = ResourceCollection.new('bake-session', Time.now.strftime("%Y.%m.%d.%I.%m"), selected_resources)
      @session_dependency = Dependency.dependency_tree(@session_collection)
    end

    def dependency_tree
      @session_dependency
    end

    # returns a two element array of resource conflicts and install conflicts
    def conflicts
      return Dependency.resource_conflicts(@session_dependency), Dependency.install_conflicts(@session_dependency)
    end

    #
    def priorities
      return Dependency.priorities(@session_dependency)
    end

    # checks for potential problems
    def check_list
      if Dependency.recursion?(@session_dependency)
        raise BakerError, "recipe recursion detected"
      end
      problem_list = Dependency.missing_dependencies(@session_dependency)
      if !problem_list.empty?
        raise DependencyError, "missing dependencies: #{problem_list.join(',')}"
      end
      problem_list = Dependency.resource_conflicts(@session_dependency)
      if !problem_list.empty?
        raise ConflictError, "recipe conflicts: #{problem_list.join(',')}"
      end
      problem_list = Dependency.install_conflicts(@session_dependency)
      if !problem_list.empty?
        raise ConflictError, "installed conflicts: #{problem_list.join(',')}"
      end
    end

    #== prebuild commands

    # download source package
    def fetch
      if Settings.opt_batch
        priorities.each {|rn| Catalog.instance.get(rn).fetch}
      else
        Catalog.instance.get(priorities.last).fetch
      end
    end

    # extract source
    def extract
      if Settings.opt_batch
        priorities.each {|rn| Catalog.instance.get(rn).extract}
      else
        r = Catalog.instance.get(priorities.last)
        raise(BakerError, "source package has not been downloaded") if !r.fetched?
        r.extract
      end
    end

    # patch source
    def patch
      if Settings.opt_batch
        priorities.each {|rn| Catalog.instance.get(rn).patch}
      else
        r = Catalog.instance.get(priorities.last)
        raise(BakerError, "source package has not been extracted") if !r.extracted?
        Catalog.instance.get(priorities.last).patch
      end
    end

  end
  
  
  # = RecipeManager
  #
  #
  class RecipeManager
    
    include Fakeroot
  
    def initialize
    
    end

    def build
      check_list if !Settings.opt_ignore
      self.patch if Settings.opt_batch
      
      priorities.each do |rn|
        r = Catalog.instance.get(rn)
        depnames = r.resolved_dependencies #.collect {|dn| Catalog.instance.get(dn)}
        pkgdir = Settings.pkg_dir
        bpkgdir = File.join(pkgdir,"#{r.program}--#{r.version}")
        fakedir = File.join(pkgdir,"#{r.program}--#{r.version}",Settings.root_dirname)
        depndir = File.join(pkgdir,"#{r.program}--#{r.version}",Settings.dep_dirname)
        #makeroot(bpkg_dir, false)        # setup the bpkg dir
        #makeroot(fake_dir, true)         # setup the fakeroot dir
        User.asroot do
          envvars = env_new("/#{Settings.root_dirname}", nil)
          depnames.each{|rd| envvars = add_env(File.join("/#{Settings.dep_dirname}",rd), envvars)}
          mountroot(fakedir) do              # mounts the fakeroot
            mountdep(depndir, depnames) do   # mounts the dependencies
              chroot(bpkgdir) do             # chroot to bpkg
                env_set envvars              # set the env vars to point to fakeroot and dependencies
                #p ENV
                r.prepare
                #r.compile
                #r.test if Settings.opt_test
                #r.install
    end end end end end end

    #
    def mountdep(depdir, depnames)
      return if !block_given?
      File.makedirs(depdir) if !File.directory?(depdir)
      depl = depnames.collect{|d| File.join(depdir,d)}
      depl.each{|d| Dir.mkdir(d) if !File.directory?(d)}
      begin
        depnames.each do |d|
          dpkg = File.join(Settings.pkg_dir,d)
          dmnt = File.join(depdir,d)
          raise BakerError, "mount of #{dmnt} failed" unless system("mount --bind -r -n #{dpkg} #{dmnt}")
        end
        yield
      ensure
        depnames.each do |d|
          dmnt = File.join(depdir,d)
          system("umount #{dmnt}")
        end
      end
    end

    # prepare source
    def prepare
      check_list if !Settings.opt_ignore
      if Settings.opt_batch
        priorities.each {|rn| Catalog.instance.get(rn).prepare}
      else
        Catalog.instance.get(priorities.last).prepare
      end
    end

    # compile source
    def compile
      check_list if !Settings.opt_ignore
      if Settings.opt_batch
        priorities.each {|rn| Catalog.instance.get(rn).compile}
      else
        Catalog.instance.get(priorities.last).compile
      end
    end

    # test
    def test
      check_list if !Settings.opt_ignore
      if Settings.opt_batch
        priorities.each {|rn| Catalog.instance.get(rn).test}
      else
        Catalog.instance.get(priorities.last).test
      end
    end

    # install program
    def install
      check_list if !Settings.opt_ignore
      if Settings.opt_batch
        priorities.each {|rn| Catalog.instance.get(rn).install}
      else
        Catalog.instance.get(priorities.last).install
      end
    end


    # do it all
    def cast
      exit 0
      old_batch = Settings.opt_batch    # since cast is auto batch
      begin                             # get the current batch option
        Settings.opt_batch = true       # set batch to true for cast
        self.install                    # now call install
      ensure
        Settings.opt_batch = old_batch  # reset batch option to what it was
      end
    end

    # adds recipe and recuses through dependencies
    #def recursive_add_recipes(recipe_object, matched=[])
    #  recipe_object.resolve_dependencies #(@catalog)
    #  recipe_object.resolved_dependencies.each do |dependency_name|
    #    if !matched.include?(dependency_name)  # no need to add if already there
    #      matched << dependency_name  # so we won't do it again
    #      dependency_recipe_object = YAML::load(File.new(File.join(Settings.catalog_dir,dependency_name)))
    #      recursive_add_recipes(dependency_recipe_object, matched)
    #      @recipe_lookup[dependency_name] = dependency_recipe_object
    #      @prioritized_recipes << dependency_name
    #    end
    #  end
    #end

    # build a dependency tree
    #def dependency_tree
    #  recurse_dependency_tree(@recipe_collection.program)
    #end
    #def recurse_dependency_tree(recipe_node, matched=[])
    #  tree = {}
    #  @recipe_lookup[recipe_node].resolved_dependencies.each do |dep_name|
    #    if !matched.include?(dep_name)
    #      matched << dep_name
    #      branch = self.recurse_dependency_tree(dep_name, matched)
    #      tree[dep_name] = (branch == {} ? true : branch)
    #    end
    #  end
    #  @recipe_lookup[recipe_node].unresolved_dependencies.each do |dep_name|
    #    tree[dep_name] = false
    #  end
    #  return tree
    #end

    # raise errors if missing?, install confliicts, or recipe conflicts?
    #def raise_on_missing_or_conflicts
    #  raise DependencyError if self.missing?  # dependencies
    #  ic = self.install_conflicts # install conflicts
    #  raise ConflictError if ic.length > 0
    #  raise ConflictError if self.conflicts? # receipe conflicts
    #end

  end  # Manager

end
