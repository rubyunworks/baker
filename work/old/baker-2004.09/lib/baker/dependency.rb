# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, GPL

# LICENSE HERE

require 'catalog'

class Tuple < Array
  include Enumerable
end

module Baker

  module Dependency

    attr_reader :resolved_dependencies, :unresolved_dependencies

    # function to resolve names of dependencies, applicable_compliment and applicable_supplement
    def resolve_dependencies
      puts "resolving dependency names for #{program} #{version}" if $DEBUG
      dep_names = dependencies | applicable_compliment | applicable_supplement
      @resolved_dependencies, @unresolved_dependencies = Catalog.instance.resolve_names(dep_names)
    end

    # collects the compliemts which are conditional dependencies
    # dependent on aviod in current build configuration
    def applicable_compliment
      compliment.find_all do |c|
        !BuildConfig.instance.avoid.collect{|a| a.downcase}.include?(c.split(/(\s+|--)/)[0].downcase)
      end
    end

    # collects the suppliments which are conditional dependencies
    # dependent on ensure in current build configuration
    def applicable_supplement
      supplement.find_all do |s|
        BuildConfig.instance.ensure.collect{|e| e.downcase}.include?(s.split(/(\s+|--)/)[0].downcase)
      end
    end

    #
    def unresolved_dependencies?
      (@unresolved_dependencies.length > 0)
    end

    
    #== Module Methods

    # produce a complete dependency tree
    def Dependency.dependency_tree(recipe, already=[])
      tree = {}
      recipe.resolved_dependencies.each do |rk|
        if already.include?(rk)
          tree[rk] = nil
        else
          already << rk
          r = Catalog.instance.get(rk)
          branch = Dependency.dependency_tree(r, already)
          tree[rk] = (branch == {} ? true : branch)
        end
      end
      recipe.unresolved_dependencies.each do |ur|
        tree[ur] = false
      end
      tree
    end

    # checks dependency tree for recursion
    # pass in a dependency tree
    def Dependency.recursion?(dep_branch)
      rec = nil
      case dep_branch
      when Hash
        dep_branch.each_value do |v|
          rec ||= Dependency.recursion?(v)
        end
      when nil
        rec = true
      else
        rec = false
      end
      rec
    end

    # returns a list of missing dependencies
    # pass in a dependency tree
    def Dependency.missing_dependencies(dep_branch, key=nil)
      miss = []
      case dep_branch
      when Hash
        dep_branch.each do |k,v|
          miss << Dependency.missing_dependencies(v,k)
        end
      when false
        miss << key if key
      end
      miss.flatten
    end

    # returns list of recipes in the order they are to be processed
    # pass in a dependency tree
    def Dependency.priorities(dep_branch, key=nil)
      priors = []
      case dep_branch
      when Hash
        dep_branch.each do |k,v|
          priors << Dependency.priorities(v,k)
        end
      when true
        priors << key if key
      end
      priors.flatten
    end

    # conflicts between recipes
    # pass in a dependency tree
    def Dependency.resource_conflicts(dep_tree)
      priors = Dependency.priorities(dep_tree)
      # build list of recipes as tuples
      priority_tuples = priors.collect{|rk| n,v = rk.split('--'); Tuple.new( [n, v.split('.')].flatten )}
      # build list of possible conflicts as tuples
      possible_conflicts = priors.collect{|rk| r = Catalog.instance.get(rk); r.conflicts}.flatten
      conflict_tuples = possible_conflicts.collect{|rk| n,v = rk.split('--'); Tuple.new( [n, v.split('.')].flatten )}
      # build list of conflicts
      conflicts = []
      conflict_tuples.each do |ct|
        priority_tuples do |pt|
          if ct.last[-1..-1] = '+' and pt > ct
            conflicts << "#{pt[0]}--#{pt[1..-1].join('.')}"
          elsif ct == pt
            conflicts << "#{pt[0]}--#{pt[1..-1].join('.')}"
          end
        end
      end
      conflicts
    end

    # existing install conflicts
    # returns a hash list of recipes with conflicts
    # TODO File.exists? needs FHS redirect
    def Dependency.install_conflicts(dep_tree)
      priors = Dependency.priorities(dep_tree)
      iconflicts = {}
      priors.each do |rk|
        r = Catalog.instance.get(rk)
        r.install_conflicts.each do |ic_key, ic_indicators|
          if File.exists?(ici)
            iconflicts[rk] ||= []
            iconflicts[rk] << ic_key
          end
        end
      end
      return iconflicts
    end

  end

end

