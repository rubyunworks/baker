module Baker
  module Config

    on = true
    off = false

    MNTDIR = ENV['BAKER_MNTDIR'] || '/'  #'/mnt/lfs/'
    APPDIR = ENV['BAKER_APPDIR'] || File.join( MNTDIR, 'app' )
    SRVDIR = ENV['BAKER_SRVDIR'] || File.join( MNTDIR, 'srv/bakery' )

    RESDIR = File.join( SRVDIR, 'resources' )
    RECDIR = File.join( SRVDIR, 'recipes' )
    PKGDIR = File.join( SRVDIR, 'packages' )

    PRETEND = $BAKER_PRETEND.nil? ? ENV['BAKER_PRETEND'] : $BAKER_PRETEND

    DOWNLOAD = $BAKER_FETCH.nil?   ? true : $BAKER_FETCH
    UNPACK   = $BAKER_UNPACK.nil?  ? true : $BAKER_UNPACK
    COMPILE  = $BAKER_COMPILE.nil? ? true : $BAKER_COMPILE
    TEST     = $BAKER_TEST.nil?    ? true : $BAKER_TEST
    INSTALL  = $BAKER_INSTALL.nil? ? true : $BAKER_INSTALL
    LINK     = $BAKER_LINK.nil?    ? true : $BAKER_LINK

  end
end
