# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

require 'ftools'
#require 'digest/md5'
#require 'open-uri'
require 'yaml'
require 'singleton'
require 'error'

module Baker

  class Catalog

    include Singleton

    attr_accessor :local_region, :catalog_urls

    def initialize
      @@cache = {}
      load_config
    end

    def load_config
      cat_conf_file = Settings.cat_config_file
      if FileTest::exists?(cat_conf_file)
        settings = YAML::load(File.new(cat_conf_file))
      else
        raise BakerError, "could not find catalog settings file at:\n#{cat_conf_file}"
      end
      @source_dir = settings['source_dir']
      @catalog_dir = settings['catalog_dir']
      @personal_dir = settings['personal_dir']
      @local_region = settings['local_region']
      @catalog_urls = settings['catalog_urls']
    end

    # synchronizies catalog with master catalog
    def sync
      # source directory already exists? if not then create
      cat_dir = Settings.catalog_dir
      if !File.directory?(cat_dir)
        raise BakerError, "error in catalog.rb"
        # File.makedirs(cat_dir)
      end
      local_path = DownloadManager.regional_download(self.catalog_urls, self.local_region, cat_dir, true)
      if !local_path
        raise BakerError, "Catalog synchronization failed when downloading."
      end
      success = DownloadManager.extract(local_path)
      if !success
        puts BakerError, "Catalog synchronization failed when extracting."
      end
    end

    # returns a list of all recipe files in the catalog
    def entries
      cat_dir = Settings.catalog_dir
      #
      #personal_entries = []
      #Dir.entries(@personal_dir).each do |r|
      #  personal_entries << r if FileTest::file?(File.join(@catalog_dir,r))
      #end
      # this probably needs enhancement
      #reposits = @catalog_urls.collect { |r|
      #  ['.gz','.bz2','.zip','.tgz','.tar'].inject(File.basename(r)) { |bn, ch| bn.chomp(ch) }
      #}.reverse
      public_entries = []
      Dir.entries(cat_dir).each do |r|
        reposit = File.join(cat_dir,r)
        if File.directory?(reposit) and r != '.' and r != '..' and r != 'CVS'
          Dir.entries(reposit).each do |d|
            public_entries << "#{File.basename(reposit)}/#{d}" if File.file?(File.join(reposit,d))
          end
        elsif File.file?(reposit)
          public_entries << "#{File.basename(reposit)}" if r !~ /(\.gz|\.bz2|\.zip|\.tgz|\.tar)$/
        end
      end
      #personal_entries + public_entries
      public_entries
    end

    # search catalog entries - find matching recipe names
    def search(pattern)
      entries.grep(Regexp.new(pattern))
    end

    #
    def find(recipe_reference, parent=nil)
      recipe_name = resolve_name(recipe_reference)
      return nil if !recipe_name
      unless @@cache[recipe_name]
        @@cache[recipe_name] = YAML::load(File.open(File.join(Settings.catalog_dir, recipe_name)))
        @@cache[recipe_name].initialize_post(recipe_name)
      end
      return @@cache[recipe_name]
    end

    #
    def get(recipe_name, parent=nil)
      return nil if !File.exists?(File.join(Settings.catalog_dir, recipe_name))
      unless @@cache[recipe_name]
        @@cache[recipe_name] = YAML::load(File.open(File.join(Settings.catalog_dir, recipe_name)))
        @@cache[recipe_name].initialize_post(recipe_name)
      end
      return @@cache[recipe_name]
    end

    # resolves a program name making sure it exists and getting latest + version.
    def resolve_name(recipe_reference)
      resolved_name = nil  # will return nil if can't resolve
      possible_name = recipe_reference.strip
      if possible_name[-1..-1] == '+'
        # okay lets see what recipes fit the bill
        recipe_pattern = "^#{possible_name[0..-2]}"
        possible_recipes = search(recipe_pattern)
        if possible_recipes.length > 0
          # get the latest version
          latest_name = possible_recipes.sort.reverse[0]
          # is it later then whats wanted?
          if latest_name > possible_name
            resolved_name = latest_name
          end
        end
      else  # okay the name is good but does it exist?
        resolved_name = possible_name if File.exists?(File.join(Settings.catalog_dir, possible_name))
      end
      return resolved_name
    end

    #
    def resolve_names(recipe_references)
      resolved = []
      unresolved = []
      recipe_references.each do |unresolved_name|
        recipe_name = resolve_name(unresolved_name)
        if recipe_name
          resolved << recipe_name  # :)
        else
          unresolved << unresolved_name  # :(
        end
      end
      return resolved, unresolved
    end

    # build a dependency tree
    #def dependency_tree(recipes_name)
    #  recurse_dependency_tree(@recipe_collection.program)
    #end

    #def dependency_tree(recipe_name, already=[])
    #  tree = {}
    #  recipe = get(recipe_name)
    #  recipe.resolved_dependencies.each do |rd|
    #    if !matched.include?(rd)
    #      already << rd
    #      branch = dependency_tree(rd, already)
    #      tree[rd] = (branch == {} ? true : branch)
    #    end
    #  end
    #  recipe.unresolved_dependencies.each do |ud|
    #    tree[ud] = false
    #  end
    #  return tree
    #end

    # new recipe from template file
    # currently only 'simple' recipe type (the name of file in templates dir)
    def template(recipe_type, recipe_name, recipe_version)
      recipe_version = '1.0.0' if recipe_version.strip == ''
      from_file = File.join(Settings.templates_dir,"#{recipe_type}")
      to_file = File.join(Settings.catalog_dir,"#{recipe_name}--#{recipe_version}")
      if FileTest::exists?(to_file)
        raise BakerError, "source recipe already exists"
      elsif !FileTest::exists?(from_file)
        raise BakerError, "template recipe does not exist"
      end
      File.syscopy(from_file, to_file)
      if FileTest::exists?(to_file)
        return "#{recipe_name}--#{recipe_version}"
      else
        raise "could not write for #{to_path}, permissions correct?"
      end
    end

  end  # End Catalog

end
