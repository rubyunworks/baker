# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

require 'ftools'
require 'yaml'
require 'singleton'

require 'baker/settings'
require 'baker/download'


module Baker
  
  # = Catalog
  #
  class CatalogClass
    include Singleton
    
    def_attr :local_region, :catalog_urls
    
    def initialize
      catalog_config_path = File.join(Settings.config_dir,Settings.catalog_config)
      if ! FileTest.exists?( catalog_config_path )
        raise IOError, "Could not find catalog configuration file at:\n#{catalog_config_path}"
      end
      set_instances( YAML::load( File.new(catalog_config_path) ) )
      @cache = {}
    end
    
    # synchronizies catalog with master catalog
    def sync
      # catalog directory already exists?
      cat_dir = Settings.catalog_dir
      if !File.directory?(cat_dir)
        raise IOError, "Catalog directory does not exist: #{cat_dir}"
        # File.makedirs(cat_dir)
      end
      local_path = DownloadManager.regional_download(catalog_urls, local_region, cat_dir, Settings.opt_force)
      if ! local_path
        raise IOError, "Catalog synchronization failed when downloading."
      end
      success = DownloadManager.extract(local_path)
      if !success
        puts IOError, "Catalog synchronization failed when extracting '#{local_path}'."
      end
    end

    def resource_entries
      Dir.chdir(Settings.resource_dir)
      Dir["[^.]*"]
    end
    
    def recipe_entries
      Dir.chdir(Settings.recipe_dir)
      Dir["[^.]*"]
    end
    
    # returns a list of all recipe files in the catalog
    def entries(reload=false)
      @entries = nil if reload
      @entries ||= resource_entries #& recipe_entries
    end
#       
#       cat_dir = Settings.catalog_dir
#       #
#       #personal_entries = []
#       #Dir.entries(@personal_dir).each do |r|
#       #  personal_entries << r if FileTest::file?(File.join(@catalog_dir,r))
#       #end
#       # this probably needs enhancement
#       #reposits = @catalog_urls.collect { |r|
#       #  ['.gz','.bz2','.zip','.tgz','.tar'].inject(File.basename(r)) { |bn, ch| bn.chomp(ch) }
#       #}.reverse
#       public_entries = []
#       Dir.entries(cat_dir).each do |r|
#         reposit = File.join(cat_dir,r)
#         if File.directory?(reposit) and r != '.' and r != '..' and r != 'CVS'
#           Dir.entries(reposit).each do |d|
#             public_entries << "#{File.basename(reposit)}/#{d}" if File.file?(File.join(reposit,d))
#           end
#         elsif File.file?(reposit)
#           public_entries << "#{File.basename(reposit)}" if r !~ /(\.gz|\.bz2|\.zip|\.tgz|\.tar)$/
#         end
#       end
#       #personal_entries + public_entries
#       public_entries
#    end

    # search catalog entries - find matching recipe names
    def search(pattern)
      pat = "^#{pattern}".gsub('*','.*')
      entries.grep(Regexp.new(pat,Regexp::IGNORECASE))
    end

    #
    def find(reference, parent=nil)
      rname = resolve_name(reference)
      return nil if ! rname
      unless @cache[rname]
        @cache[rname] = YAML::load(File.open(File.join(Settings.resource_dir, rname)))
        #@@cache[rname].initialize_post(rname)
      end
      return @cache[rname]
    end

    #
    def get(rname, parent=nil)
      return nil if ! File.exists?(File.join(Settings.resource_dir, rname))
      unless @cache[rname]
        @cache[rname] = YAML::load(File.open(File.join(Settings.resource_dir, rname)))
        #@cache[rname].initialize_post(rname)
      end
      return @cache[rname]
    end

    # resolves a program name making sure it exists and getting latest + version.
    def resolve_name(reference)
      resolved_name = nil  # will return nil if can't resolve
      possible_name = reference.strip
      if File.exists?(File.join(Settings.resource_dir, possible_name))
        resolved_name = possible_name
      else      
        #if possible_name[-1..-1] == '+'
        # okay lets see what recipes fit the bill
        pattern = "#{possible_name}*"
        possiblities = search(pattern)
        if possiblities.length > 0
          # get the latest version
          latest_name = possiblities.sort.reverse[0]
          # is it later then whats wanted?
          if latest_name > possible_name
            resolved_name = latest_name
            #puts "Using best match...#{resolved_name}" if Settings.opt_verbose
          end
        end
        #else  # okay the name is good but does it exist?
        #  resolved_name = possible_name if File.exists?(File.join(Settings.catalog_dir, possible_name))
        #end
      end
      return resolved_name
    end

    #
    def resolve_names(references)
      resolved = []; unresolved = []
      references.each do |unresolved_name|
        resolved_name = resolve_name(unresolved_name)
        if resolved_name
          resolved << resolved_name  # :)
        else
          unresolved << unresolved_name  # :(
        end
      end
      return resolved, unresolved
    end
    
#     # new recipe from template file
#     # currently only 'simple' recipe type (the name of file in templates dir)
#     def template(recipe_type, recipe_name, recipe_version)
#       recipe_version = '1.0.0' if recipe_version.strip == ''
#       from_file = File.join(Settings.templates_dir,"#{recipe_type}")
#       to_file = File.join(Settings.catalog_dir,"#{recipe_name}--#{recipe_version}")
#       if FileTest::exists?(to_file)
#         raise BakerError, "source recipe already exists"
#       elsif !FileTest::exists?(from_file)
#         raise BakerError, "template recipe does not exist"
#       end
#       File.syscopy(from_file, to_file)
#       if FileTest::exists?(to_file)
#         return "#{recipe_name}--#{recipe_version}"
#       else
#         raise "could not write for #{to_path}, permissions correct?"
#       end
#     end

  end  # End Catalog

  
  #
  Catalog = CatalogClass.instance
  
  
end  # Baker
