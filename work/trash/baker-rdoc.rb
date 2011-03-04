#!/usr/bin/ruby

DEBUG = false
OUTDIR = 'web/rdoc'
MAIN = 'README'
EXCLUDE = [ 'baker-cvs.rb', 'baker-rdoc.rb', 'TRASH', 'ext', 'web', 'var/cat' ]
UEXCLUDE = [ '.', '..', 'CVS' ]

def traversal(path)
  incl = []
  Dir.entries(path).each do |e|
    fpath = File.join(path,e)
    cpath = File.join(path,e)[2..-1]  # removes './'
    if File.file?(fpath)
      unless UEXCLUDE.include?(e) or EXCLUDE.include?(cpath)
        incl << cpath
      end
    elsif File.directory?(fpath)
      unless UEXCLUDE.include?(e) or EXCLUDE.include?(cpath)
        incl.concat(traversal(fpath))
      end
    end
  end
  return incl
end

rdoc_cmd = "rdoc --all --op #{OUTDIR} --main #{MAIN} --template kilmer "
rdoc_cmd += traversal('./').join(' ')

if DEBUG
  p rdoc_cmd
else
  `#{rdoc_cmd}`
end
