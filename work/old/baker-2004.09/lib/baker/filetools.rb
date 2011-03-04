

module Baker

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
   
end 
