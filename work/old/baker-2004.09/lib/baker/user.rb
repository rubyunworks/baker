# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

# Note: this was taken from Andrew Walrond's rubyx and is temporary
# until we can depend on UUID.

module User

  private

  @@unprivilegedUID=nil
  @@unprivilegedGID=nil

  public

  def set(user,group); @@unprivilegedUID,@@unprivilegedGID = user,group; end

  def uid(); return @@unprivilegedUID; end

  def User.create(user)  # user - String
    unless system('id -u rubyx > /dev/null 2>&1')
      puts "Creating an unprivileged 'rubyx' user..."
      raise "Unable to create user '#{user}'" unless system('useradd','-s/bin/false',user)
    end
    @@unprivilegedUID = `id -u #{user}`.chomp.to_i
    @@unprivilegedGID = `id -g #{user}`.chomp.to_i
  end

  def User.asroot()
    egid, euid = Process.egid, Process.euid
    Process.egid, Process.euid = 0,0
    home,ENV['HOME'] = ENV['HOME'],'/home/root'
    begin
      return yield
    ensure
      Process.egid,Process.euid=egid,euid
      ENV['HOME'] = home
    end if block_given?
  end

  def User.aseuid(u=nil,g=nil) #Pretend to be a user, but can become root again
    egid,euid = Process.egid,Process.euid
    Process.egid,Process.euid = 0,0
    Process.egid = (g ? g.to_i : @@unprivilegedGID)
    Process.euid = (u ? u.to_i : @@unprivilegedUID)
    home,ENV['HOME'] = ENV['HOME'],'/home/rubyx'
    begin
      return yield
    ensure
      Process.egid,Process.euid = 0,0
      Process.egid,Process.euid = egid,euid
      ENV['HOME'] = home
    end if block_given?
  end

  def User.asuid(u=nil,g=nil) #Become user. Cannot become root again
    Process.gid = (g ? g : @@unprivilegedGID)
    Process.uid = (u ? u : @@unprivilegedUID)
  end

end
