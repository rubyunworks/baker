require 'progressbar'

total = 100
pbar = ProgressBar.new("test(inc)", total)
total.times {
  sleep(0.02)
  pbar.inc
}
pbar.finish

total = 1000
pbar = ProgressBar.new("test(set)", total)
(1..total).find_all {|x| x % 10 == 0}.each {|x|
  sleep(0.02)
  pbar.set(x)
}
pbar.finish

total = File.size("progressbar.rb")
pbar = ProgressBar.new("test(inc(x))", total)
File.new("progressbar.rb").each {|line|
  sleep(0.02)
  pbar.inc(line.length)
}
pbar.finish

total = 0
pbar = ProgressBar.new("test(total=0)", total)
pbar.finish

total = 100
pbar = ProgressBar.new("test(halt)", total)
(total / 2).times {
  sleep(0.02)
  pbar.inc
}
pbar.halt

total = 1024 * 1024
pbar = ProgressBar.new("test(bytes)", total)
pbar.file_transfer_mode
0.step(total, 2048) {|x|
  pbar.set(x)
  sleep(0.01)
}
pbar.finish
