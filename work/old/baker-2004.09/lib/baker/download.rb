# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, LGPL

# LICENSE HERE

# external libs
require 'digest/md5'
require 'open-uri'
require 'progressbar/progressbar'  # this is not part of standard ruby install (see raa)
                                   # actually I made a small modifcation to it so i
                                   # will include it with baker until the change effects raa
module Baker

  # DownloadManger
  #
  # this is module of tools for downloading and extracting archived files

  module DownloadManager

    # regional_urls - array of arrays of [ url, region, md5, expected_size ]
    # local_region - region of the user's system
    # source_dir - where to store downloaded file (full path)
    # force - redownload even if it already exists
    def DownloadManager.regional_download(regional_urls, local_region, source_dir, force=false)
      # source file exists and passes checksum then we need not fetch
      regional_urls.each do |url|
        file_path = File.join(source_dir,File.basename(url[0]))
        file_location = url[1]
        file_checksum = url[2]
        file_size= url[3]
        if File.exists?(file_path)
          if force or DownloadManager.checksum(file_path) != file_checksum
            File.delete(file_path)
            break
          else
            # prefer this puts not be here as it is interface code
            # but i haven't found a good way to seperate concersn yet
            puts "File has already been fetched and passes checksum." if Settings.opt_verbose
            return true
          end
        end
      end
      # prioritize urls
      prioritized_urls = DownloadManager.prioritize_regional_urls(regional_urls, local_region)
      # download
      success = nil
      prioritized_urls.each do |url|
        file_path = File.join(source_dir,File.basename(url[0]))
        file_checksum = url[2]
        file_size = url[3]
        success = DownloadManager.download(url[0], file_path, file_checksum, file_size)
        break if success  # we got it
      end
      return success
    end

    # prioritize regional urls putting local geographical region first
    # regional_urls - array of arrays of [ url, region, md5, expected_size ]
    # in the future we may test each connection for fastest download
    def DownloadManager.prioritize_regional_urls(regional_urls, local_region)
      # put local region first
      prioritized_urls = regional_urls.find_all { |a| a[1] == local_region }
      prioritized_urls.concat regional_urls.find_all { |a| a[1] != local_region }
      return prioritized_urls
    end

    # currently can only download a single compressed file
    # does not handle downloading an uncompressed directory tree (should it? doubt it)
    #
    # currently this displays progress to STDOUT; either their should
    # be a way to activate/deactivate or preferably use all new ducktype singletons
    # (more on that later, see google://_whytheluckystiff if interested)
    # of course I prefer chain messaging but matz said no :( we'll see :)
    def DownloadManager.download(url, file_path, file_checksum, file_size=nil)
    #p file_path
    #exit 0
      download_complete = nil
      STDOUT.sync = true
      print "Fetching #{File.basename(file_path)} " if !Settings.opt_verbose
      print "Fetching #{url} " if Settings.opt_verbose
      print "(#{(file_size.to_f/1024).to_i} KBytes)" if file_size
      puts
      progress_total = file_size ? file_size : 100000000  # pretend 100MB if no size
      pbar = ProgressBar.new(" ", progress_total, STDOUT)
      pbar.bar_mark=">"
      pbar.format="%-1s %3d%% %s %s"
      pbar.file_transfer_mode if file_size
      progress_proc = proc {|posit| pbar.set(posit)}
      #
      begin
        local_file = File.open(file_path,'w')
        remote_file = open(url,progress_proc)
        local_file << remote_file.read
      rescue
        pbar.halt
        download_complete = nil
        #remote_file.close unless remote_file.nil?
        raise
      else
        pbar.finish
        download_complete = file_path
      ensure
        remote_file.close unless remote_file.nil?
        local_file.close unless local_file.nil?
        STDOUT.sync = false
      end
      download_complete = nil if checksum(file_path) != file_checksum and file_checksum != nil
      return download_complete
    end

    # checksum
    def DownloadManager.checksum(local_path)
      if File.exists?(local_path)
        File.open(local_path) do |local_file|
          return Digest::MD5.new(local_file.read).hexdigest
        end
      end
    end

    # extract
    def DownloadManager.extract(local_path)
      success = false
      local_dir = File.dirname(local_path)
      local_file = File.basename(local_path)
      current_dir = Dir.getwd
      begin
        Dir.chdir(local_dir)
        case local_file
          when /.*gz$/
            system "tar -xzf #{local_file}"
          when /.*bz2$/
            system "tar -xjf #{local_file}"
          when /.zip$/
            system "unzip #{local_file}"
          else
            success = false
        end
      rescue
        success = false
      else
        success = true
      ensure
        Dir.chdir(current_dir)
      end
      return success
    end

  end  # DownloadManager

end

