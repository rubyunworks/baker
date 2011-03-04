
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
 
