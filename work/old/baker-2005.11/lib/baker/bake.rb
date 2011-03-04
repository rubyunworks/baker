
def all_off
  $BAKER_DOWNLOAD = false
  $BAKER_UNPACK   = false
  $BAKER_COMPILE  = false
  $BAKER_TEST     = false
  $BAKER_INSTALL  = false
  $BAKER_LINK     = false
end

# Prepare parameters
params = []
ARGV.each{ |parm|
  case parm
  when '--help, -h'
    puts "No help yet."
    exit 0
  when '--verbose', '-v'
    $VERBOSE = true
  when '--pretend', '-p'
    $BAKER_PRETEND = true
  when '--download'
    all_off
    $BAKER_DOWNLOAD = true
  when '--unpack'
    all_off
    $BAKER_UNPACK = true
  when '--compile'
    all_off
    $BAKER_COMPILE = true
  when '--test'
    $BAKER_TEST = true
  when '--install'
    all_off
    $BAKER_INSTALL = true
  when '--link'
    all_off
    $BAKER_LINKAGE = true
  when '--no-download'
    $BAKER_DOWNLOAD= false
  when '--no-unpack'
    $BAKER_UNPACK = false
  when '--no-compile'
    $BAKER_COMPILE = false
  when '--no-test'
    $BAKER_TEST = true
  when '--no-install', '-n'
    $BAKER_INSTALL = false
    $BAKER_LINK = false
  when '--no-link'
    $BAKER_LINK = false
  else
    if parm =~ /^-/
      puts "Unknown option: #{parm}"
      exit 0
    end
    params << parm
  end
}

# Load configuration
require 'baker/config'
include Baker::Config

# Which recipe
name = params[0]
unless name
  puts "What? You are no a Chef, ey?"
  exit 0
end

# if name == '--cool'
#   dirs = { 'bin'=>nil, 'lib'=>nil, 'man'=>nil, 'include'=>nil }
#   dirs.keys.each { |dir|
#     dirs[dir] = Dir.glob( File.join( APPDIR, '**', 'root', dir, '*' ) )
#   }
#   # do symlinks here
#   dirs.each { |dir, files|
#     files.each { |f|
#       target = f[f.index("\#{dir}")..-1]
#       puts "ln -fs #{f} #{target}"
#     }
#   }
#   exit 0
# end

pattern = File.join( RECDIR, "#{name}--*" )
recs = Dir.glob( pattern )
if recs.size == 0
  puts "Error: No recipe found for #{name}."
  puts recs
  exit 0
end
if recs.size > 1
  puts "Error: Found more than one match:"
  puts recs.join("\n")
  exit 0
end
puts "Cooking up a delicious treat #{recs[0]}"
# run the receipe
require 'baker/dsl'
load recs[0]
