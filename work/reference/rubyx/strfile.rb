#!/bin/ruby -w

# LICENSE
#
# Go for it. Whatever.
# But NEVER FEED THE LAWYERS.
#
# Originally coded by Andrew Walrond
#

#-------------------------------------------------------------------------------
def path(*elements)   #Create a path from the elements
#-------------------------------------------------------------------------------
  path=elements.join('/').strip #Remove leading and trailing whitespace
  while path.gsub!('//','/'); end  #Remove duplicate slashes
  return path
end

#-------------------------------------------------------------------------------
def umask0()  #Run block with umask=0000
#-------------------------------------------------------------------------------
  cum=File.umask
  File.umask(0)
  begin; yield; ensure; File.umask(cum); end
end

#===============================================================================
class String
#===============================================================================

	DEREF=true; NODEFRE=false
  #-----------------------------------------------------------------------------
  def stat(deref=false); begin; deref ? File.stat(self) : File.lstat(self); rescue; nil; end; end
	def exists?(deref=false); return stat(deref); end
  def directory?(deref=false); s=stat(deref); return (s ? s.directory? : nil); end
  def file?(deref=false);      s=stat(deref); return (s ? s.file?      : nil); end
  def symlink?(deref=false);   s=stat(deref); return (s ? s.symlink?   : nil); end
  def chardev?(deref=false);   s=stat(deref); return (s ? s.chardev?   : nil); end
  #-----------------------------------------------------------------------------  

  #-----------------------------------------------------------------------------
  def ls(); fa=Dir.glob(self+"/{.,}?*"); fa.delete(self+"/.."); return fa; end
  #-----------------------------------------------------------------------------  

  #-----------------------------------------------------------------------------  
  def lsd(&action)  # Recursively list files, top down
	#-----------------------------------------------------------------------------
		action.call(self) if exists?
		ls.each { |fn| fn.lsd(&action) } if directory?
  end

  #-----------------------------------------------------------------------------
  def lsu(&action)  # Recursively list files, bottom up
	#-----------------------------------------------------------------------------
		ls.each { |fn| fn.lsu(&action) } if directory?
		action.call(self) if exists?
  end

  #-----------------------------------------------------------------------------  
	def mkdir(mode=0777); Dir.mkdir(self,mode) unless self.directory?(true); return self; end
	def mkdirs(); File.makedirs(self); return self; end
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
	def chmod(mode); File.chmod(mode,self); return self; end
	def chown(owner,group); File.chown(owner,group,self); return self; end
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------  
	def cd()
  #-----------------------------------------------------------------------------  
		cwd=Dir.getwd
		Dir.chdir(self)
		if block_given?
			yield
			Dir.chdir(cwd)
		end
	end

  #-----------------------------------------------------------------------------  
  def rm(); File.delete(self) if exists?; end
  def rmdir(); Dir.delete(self) if exists?; end
  #-----------------------------------------------------------------------------  

  #-----------------------------------------------------------------------------
  def rrm()  # Recursive file remove
	#-----------------------------------------------------------------------------
		lsu { |fn|
			Dir.delete(fn) if fn.directory?
			File.delete(fn) if fn.exists?
		}
  end

  #-----------------------------------------------------------------------------
  def cp(dest)
	#-----------------------------------------------------------------------------
		raise "cp failed" unless File.syscopy(self,dest)
  end

  #-----------------------------------------------------------------------------
  def mv(dest)
	#-----------------------------------------------------------------------------
		raise "mv failed" unless File.mv(self,dest)
  end

  #-----------------------------------------------------------------------------
  def rcp(dest)  # Recursive copy (no dereference and preserves mode)
	#-----------------------------------------------------------------------------
		lsd { |fn|
			dn = fn.gsub(Regexp.new('^'+Regexp.escape(self)),dest)
			if fn.directory?
				dn.mkdir
			else
				File.delete(dn) if dn.exists?
				raise "rcp failed" unless File.syscopy(fn,dn)
			end
		}
  end

  #-----------------------------------------------------------------------------
  def link(dest,hard=false)
	#-----------------------------------------------------------------------------
		File.delete(dest) if dest.exists?
		if hard
			File.link(self,dest)
		else
			File.symlink(self,dest)
		end
	end

  #-----------------------------------------------------------------------------
  def rlink(dest,hard=false)
	#-----------------------------------------------------------------------------
		lsd { |fn|
			dn = fn.gsub(Regexp.new('^'+Regexp.escape(self)),dest)
			if fn.directory?
				dn.mkdir
			else
				fn.link(dn,hard)
			end
		}
  end

  #-----------------------------------------------------------------------------
  def logfork(mode='w')  #Run block as sub-process and log to filename given by self
	#-----------------------------------------------------------------------------
		return Process.fork {
			begin
				User.asroot { 
					File.makedirs(File.dirname(self))
					$stdout.reopen(self,mode); $stdout.sync=true; $stderr.reopen($stdout)
				}
				yield
				exit 0
			rescue Interrupt
				puts "Caught Interrupt!"
				exit 20
			rescue
				exit 1
			ensure
				User.asroot { $stdout.close }
			end
		}
  end

  #-----------------------------------------------------------------------------
  def fread(*lines)
	#-----------------------------------------------------------------------------
		lines = IO.readlines(self) if exists?
		lines.delete_if { |l| l.strip!; l=='' or l[0,1] == '#' }
		return lines
  end

  #-----------------------------------------------------------------------------
  def fwrite(*lines)
	#-----------------------------------------------------------------------------
		File.makedirs(File.dirname(self))
		File.open(self,'w') { |f|
			lines.each { |l|
				if l.class == Array
					f << l.join("\n") << "\n"
				else
					f<<l<<"\n"
				end
			}
		}
		return self
  end

  #-----------------------------------------------------------------------------
  def fcat(*lines)
	#-----------------------------------------------------------------------------
		File.makedirs(File.dirname(self))
		File.open(self,File::CREAT|File::APPEND|File::WRONLY) {|f| lines.each { |l| f<<l<<"\n" } }
  end

  #-----------------------------------------------------------------------------
  def ftouch(*lines)
	#-----------------------------------------------------------------------------
		fwrite(*lines) unless exists?
		return fread()
  end

  #-----------------------------------------------------------------------------
  def fedit
	#-----------------------------------------------------------------------------
		lines = IO.readlines(self)
		File.open(self,"w") { |f| lines.each { |l| yield l; f<<l } }
  end

  #-----------------------------------------------------------------------------
  def freplace(pattern,replacement)
	#-----------------------------------------------------------------------------
		fedit { |l| puts "  Changed: "+l if l.gsub!(pattern,replacement) }
  end

end
