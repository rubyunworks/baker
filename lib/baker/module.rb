
require 'succ.new/tuple'


# adds some class evaluators that help in constructing recipes

class Module

  # shorthand for attr_reader but returns args
  def reader(*args)
    attr_reader(*args)
    args
  end

  # shorthand for attr_writer but returns args
  def writer(*args)
    attr_writer(*args)
    args
  end

  # shorthand for attr_accessor but returns args
  def accessor(*args)
    attr_accessor(*args)
    args
  end

  # this is some of the cool stuff ruby can do
  # it dynamically creates a reader method for the
  # attributes that routes the output through
  # a varaible substitution parser (see eval_scripter)
  # so be sure to use accessor methods rather then @
  def scripter(*args)
    args.each do |name|
      class_eval <<-EOS
        attr_accessor :#{name}
        alias_method :__#{name}, :#{name}
        def #{name}()
          if respond_to?(:eval_scripter)
            eval_scripter(self.__#{name})
          else
            self.__#{name}
          end
        end
      EOS
    end
    args
  end

end  # Module


#
class Class
  def yamlize(yaml_type, domain=nil)
    if domain
      YAML.add_domain_type( domain, yaml_type ) { |t,v| self.new_yaml(v,t) }
      define_method(:to_yaml_type) { "!#{domain}/#{yaml_type}" }
    else
      YAML.add_private_type( yaml_type ) { |t,v| self.new_yaml(v,t) }
      define_method(:to_yaml_type) { "!!#{yaml_type}" }
    end
    def self.new_yaml(v,t=nil)
      rc = self.allocate
      rc.initialize_yaml(v,t)
      rc
    end
  end
end

#
class Object
  def initialize_yaml(h={},t=nil)
    h.each{ |k,v| instance_variable_set("@#{k}",v) }
  end
end
