# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

require 'yaml'

class Dir

  #
  class FHSMap < Hash

    FHS_VAR = "FHS_CONFIG"

    #
    def initialize
      load
    end

    #
    def load
      if FileTest::exists?(ENV[FHS_VAR])
        self.replace YAML::load(File.new(ENV[FHS_VAR]))
      else
        warn "FHS map configuration file not found. Assuming system is FHS compliant."
      end
      self
    end

    #
    def [](x)
      if !self.has_key?(x)
        return x
      end
      super
    end

    #
    def map(std_path)
      prefix = ''
      if std_path[0..0] == '/'
        check_path = std_path[1..-1]
        prefix = '/'
      end
      # spot check file to make sure it hasn't changed?
      matches = self.keys.select{|fm| check_path =~ /^#{fm}/}
      if matches and !matches.empty?
        bestmatch = matches.sort_by{|m| m.length}.last
        return prefix + check_path.gsub(/^#{bestmatch}/, self[bestmatch])
      else
        return std_path #raise "no fhs match #{std_path}"  # temporary
      end
      #p standard_path
      #prefix+std_path
    end

  end

  # no way to get the path of self?
  #def map
  #  Dir.map(self)
  #end

  def Dir.fhs_map
    @@fhs_map
  end

  def Dir.map(std_dir)
    @@fhs_map ||= FHSMap.new
    @@fhs_map.map(std_dir)
  end

end
