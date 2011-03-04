# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, LGPL

# LICENSE HERE

#
require 'fileutils'

#
require 'user'


module Baker

  module Fakeroot

    StandardLocations = %w{bin sbin etc lib usr tmp}
    SystemLocations = %w{dev proc}

    EnvPaths = {
      'PATH'            => ['bin','sbin','usr/bin','usr/sbin','usr/local/bin','usr/local/sbin'].collect{|d| Dir.map(d)},
      'LD_LIBRARY_PATH' => ['lib','usr/lib','usr/local/lib'].collect{|d| Dir.map(d)},
      'LIBRARY_PATH'    => ['lib','usr/lib','usr/local/lib'].collect{|d| Dir.map(d)},
      'C_INCLUDE_PATH'  => ['include','usr/include','usr/local/include'].collect{|d| Dir.map(d)},
      'MANPATH'         => ['man','usr/man','usr/local/man'].collect{|d| Dir.map(d)},
      'INFOPATH'        => ['info','usr/info','usr/local/info'].collect{|d| Dir.map(d)}
    }

    #
    def buildbase(basedir)
      make_standard_root_dirs(basedir, true)

    end

    #
    def make_standard_root_dirs(rdir, incSys=false)
      File.makedirs(rdir) if !File.directory?(rdir)
      stdl = StandardLocations.collect{|d| File.join(newroot,d)}
      sysl = SystemLocations.collect{|d| File.join(newroot,d)}
      stdl.each{|d| Dir.mkdir(d) if !File.directory?(d)}
      sysl.each{|d| Dir.mkdir(d) if !File.directory?(d)} if incSys
      File.chmod(0777,File.join(newroot,'tmp'))
    end

    #
    def mountroot(newroot)
      return if !block_given?
      begin
        File.makedirs(newroot) if !File.directory?(newroot)
        system("mount --bind -r -n / #{newroot}")
        yield
      ensure
        umountroot(newroot)
      end
    end

    def umountroot(newroot)
      system("umount -ln #{newroot}")
    end

    # takes block to ensure unchroot
    def chroot(newroot)
      return if !block_given?
      raise BakerError, "can't chroot into #{newroot}, directory dosen't exist" if !File.directory?(newroot)
      FileUtils.mkdir(File.join(newroot,'proc')) if !File.directory?(File.join(newroot,'proc'))
      raise BakerError, "mount proc failed" unless system("mount -n -t proc #{Dir.map('/proc')} #{File.join(newroot,'proc')}")
      begin
        trap('INT','IGNORE')
        pid = Process.fork do
          begin
            Dir.chdir(newroot)
            puts `ls ./root/bin`
            ENV['PATH'] = "/root/bin:#{ENV['PATH']}"
            ENV['SHELL'] = "/bin/bash"
            `chroot ./` #Dir.chroot('.')
            p "here"
            yield
          rescue Exception => e
            puts "Error in chroot: #{e}"
          end
        end
        Process.waitpid(pid)
      ensure
        system("umount -ln #{File.join(newroot,'proc')}")
        trap('INT','DEFAULT')
      end
    end

    def env_new(newroot, altenv=nil)
      env = altenv ? altenv : ENV
      newenv = {}
      env.each do |k,v|
        if v[0..0] == '/'
          newenv[k] = env[k].split(':').collect{|p| "#{newroot}#{p}"}.join(':')
        end
      end
      EnvPaths.each do |k, std|
        if !newenv.has_key?(k)
        #  newenv[v] = env[v].split(':').collect{|p| File.join(newroot, p)}.join(':')
        #else
          newenv[k] = std.collect{|s| File.join(newroot,s)}.join(':')
        end
      end
      #export PATH=/#{Settings.root_dirname}/bin:/#{Settings.root_dirname}/sbin`
      #export PATH="/opt/.bin:$PATH"
      #export LD_LIBRARY_PATH="/opt/.lib:$LD_LIBRARY_PATH"
      #export LIBRARY_PATH="/opt/.lib:$LIBRARY_PATH"
      #export C_INCLUDE_PATH="/opt/.include:$C_INCLUDE_PATH"
      #export MANPATH="/opt/.man:$MANPATH"
      newenv
    end

    def env_add(rdir, env)
      newenv = {}
      EnvPaths.each do |k, v|
        newenv[k] = EnvPaths[k].collect{|s| File.join(rdir,s)}.join(':') + ":#{env[v]}".chomp(':')
      end
      env.each do |k, v|
        if !EnvPaths.include?(k)
          newenv[k] = env[k]
        end
      end
      newenv
    end

    def env_set(env)
      oldenv = ENV
      env.each do |k, v|
        #ENV[k] = v
        `export #{k}=#{v}`
      end
      puts
      `env`
    end

    # takes block to ensure unmounting
    #def mountroot(newroot)
    #  raise(BakerError, "can't mount dirs in #{newroot}, directory dosen't exist") if !File.directory?(newroot)
    #  stdl = StandardLocations.collect{|d| [Dir.map("/#{d}"),File.join(newroot,d)]}
    #  sysl = SystemLocations.collect{|d| [Dir.map("/#{d}"),File.join(newroot,d)]}
    #  raise BakerError, "required mount dirs don't exist" if !(stdl+sysl).all?{|d| File.directory?(d[1])}
    #  begin
    #    stdl.each{|d| raise BakerError, "mount of #{d[0]} to #{d[1]} failed" unless system("mount --bind -r -n #{d[0]} #{d[1]}")}
    #    sysl.each{|d| raise BakerError, "mount of #{d[1]} to #{d[1]} failed" unless system("mount --bind -n #{d[0]} #{d[1]}")}
    #    yield if block_given?
    #  ensure
    #    (stdl+sysl).each{|d| system("umount #{d[1]}")}
    #  end
    #end

    # from RUBYX
    #def chroot(dir)
    #  User.asroot {
    #    raise BakerError, "mount proc failed" unless system("mount -n -t proc proc "+path(dir,'proc'))
    #    begin
    #      trap('INT','IGNORE')
    #      pid = Process.fork {
    #        begin
    #          dir.cd #MUST cd before chroot - see Dir.chroot docs
    #          Dir.chroot(dir)
    #          #Reset the rubyx UID/GID which may be different here
    #          User.set($users['rubyx'],$groups['users'])
    #          $root = '/'
    #          #ENV.delete_if { |key,val| key!='TERM' }
    #          '/etc/environment'.fread.each { |v| v =~ /export (.*)=(.*)/; ENV[$1]=$2 }
    #          ENV['HOME'] = '/home/root'
    #          yield
    #        rescue Exception
    #          puts $!
    #        end
    #      }
    #      Process.waitpid(pid)
    #    ensure
    #      system('umount -ln '+path(dir,'proc'))
    #      trap('INT','DEFAULT')
    #    end
    #  }
    #end

  end

end


=begin

    mkdir /tmp/fake_root
    cd /tmp/fake_root
    mkdir bin sbin usr lib tmp dev etc
    mkdir build
    #mount read only dirs
    mount --bind -r /bin bin
    mount --bind -r /sbin sbin
    mount --bind -r /usr usr
    mount --bind -r /lib lib
    mount --bind -r /etc etc
    #dev needs to be normal read-write mode
    mount --bind /dev dev
    chmod a=rwx tmp
    cp /tmp/bash-2.05b.tar.gz build/
    cd build
    tar xzvf bash-2.05b.tar.gz
    cd ..
    pwd
    /tmp/fake_root
    chroot .
    cd build
    cd bash-2.05b
    pwd
    /tmp/fake_root/build/bash-2.05b
    ./configure
    make
    cd /
    exit #chroot
    pwd
    /tmp/fake_root
    umount bin
    umount dev
    umount etc
    umount lib
    umount sbin
    umount usr
    cp /bin/bash bin/
    cp /bin/sh bin/
    cp /bin/ls bin/
    cp /bin/install bin/
    ldd bin/*
    cp /lib/libdl.so.2 /lib/libc.so.6 /lib/ld-linux.so.2 lib/
    cp /lib/libpthread.so.0 /lib/librt.so.1 lib/
    mount --bind -r / real_root
    chroot .
    export
    PATH=/bin/:/real_root/bin:/real_root/sbin:/real_root/usr/bin:/real_root/usr/sbin:/real_root/usr/i686-pc-linux-gnu/gcc-bin/3.2
    cd build
    cd bash
    make install
    exit   #chroot
    pwd
    /tmp/fake_root
    umount /tmp/fake_root/real_root

=end
