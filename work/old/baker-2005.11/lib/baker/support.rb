require 'yaml'

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
