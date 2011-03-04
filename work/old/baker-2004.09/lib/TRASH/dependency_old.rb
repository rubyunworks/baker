# Baker - The Delicious Program Maker
# (c)2003 PsiT Corporation, LGPL

# Baker is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Baker is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Baker; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

class Tuple < Array
  include Enumerable
end

module Baker

  module Dependency

    attr_reader :resolved_dependencies, :unresolved_dependencies, :priorities
    attr_accessor :recursion_marker

    # function to resolve names of dependencies, applicable_compliment and applicable_supplement
    def resolve_dependencies
      if parent.check_dependecies(self)
        raise BakerError, "dependency recursion"
      end
      puts "resolving dependencies for #{self.name}" if $DEBUG
      dep_names = dependencies | applicable_compliment | applicable_supplement
      resolved, @unresolved_dependencies = Catalog.instance.resolve_names(dep_names)
      @resolved_dependencies = resolved.collect{|rn| Catalog.instance.get(rn, self)}
    end

    def check_dependencies(recipe)
      return true if @resolved_dependencies.include?(recipe)
      if parent
        return parent.check_dependencies(recipe)
      end
    end

    # collects the compliemts and suppliments which are conditional dependencies
    # dependent on ensure and aviod in current build config
    def applicable_compliment
      compliment.find_all do |c|
        !BuildConfig.instance.avoid.collect{|a| a.downcase}.include?(c.split(/(\s+|--)/)[0].downcase)
      end
    end

    def applicable_supplement
      supplement.find_all do |s|
        BuildConfig.instance.ensure.collect{|e| e.downcase}.include?(s.split(/(\s+|--)/)[0].downcase)
      end
    end

    def prioritize
      if resolved_dependencies.length == 0
        @priorities = [self]
      else
        @priorities = resolved_dependencies.collect{|r| r.priorities}.flatten.uniq + [self]
      end
      return @priorities
    end

    # produce a complete dependency tree
    def dependency_tree(recipe_key, already=[])
      tree = {}
      recipe = Catalog.instance.get(recipe_key)
      recipe.resolved_dependencies.each do |rk|
        if !already.include?(rk)
          already << rk
          branch = dependency_tree(rk, already)
          tree[rk] = (branch == {} ? true : branch)
        end
      end
      recipe.unresolved_dependencies.each do |ur|
        tree[ur] = false
      end
      tree
    end

    #
    def missing_dependencies
      miss = []
      #recipe = Catalog.instance.get(recipe_key)
      @priorities.each do |recipe|
        miss = miss | recipe.unresolved_dependencies
      end
      miss
    end

    #
    def missing_dependencies?
      (missing_dependencies.length > 0)
    end

    # collect recipe conflicts
    # these are the conflicts between recipe programs
    def recipe_conflicts
      priority_tuples = @priorities.collect{|recipe| n,v = recipe.name.split(/--/); Tuple.new([n, v.split('.')].flatten)}
      possible_conflicts = @priorities.collect{|recipe| recipe.conflicts}.flatten
      conflict_tuples = possible_conflicts.collect{|c| n,v = c.split(/--/); Tuple.new([n, v.split('.')].flatten)}
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

    # are there any recipe conflicts?
    def recipe_conflicts?
      (recipe_conflicts.length > 0)
    end

    # what are the existing install conflicts
    # returns a hash of conflicts in the form of { 'recipe_name' => [ 'path/to/conflicting/file' ], ... }
    def install_conflicts
      conflicts_hash = {}
      @priorities.each do |recipe|
        ic = Dependency.check_install_conflicts(recipe)
        if ic.length > 0
          conflicts_hash[recipe.key] = ic
        end
      end
      return conflicts_hash
    end

    def install_conflicts?
      (install_conflicts.length > 0)
    end

    #
    def Dependency.check_install_conflicts(recipe)
      conflicts_found = []
      recipe.install_conflicts.each do |ic_key, ic_indicators|
        ic_indicators.each do |ici|
          if ici.include?(' ')
            root, pattern, exclusions = ici.split(' ')
            success = findfile(root, pattern, exclusions) ? true : false
          else
            success = File.exists?(ici)
          end
          if success
            conflicts_found << ic_key
            break
          end
        end
      end
      conflicts_found
    end

  end

end
