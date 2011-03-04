
module Baker

  # common eval_scripter for resource and recipes
  module EvalScripter

    #== scripter eval
    
    # module.rb includes  nice helper function that depends on this method for evaluation
    # eval_scripter substitution has three forms, all of which are enclosed by \=( ... ).
    # - the 1st is a simple variable name, eg. \=(program)
    # - the 2nd is for lookup of sub content eg. \=(maintainer.email)
    # - the 3rd using a ? asks if a list includes a value and returns text if so eg. \=(categories?qt yes)
    # - the 4th using a ! asks if a list does NOT include a value and returns text if so eg. \=(categories!qt yano)
    # this works in conjunction with scripter attributes (so is automatic)
    def eval_scripter(raw_script)
#       puts "#{raw_script}" if $DEBUG
      script = raw_script.dup
      script.gsub!( /\#\{(.+?)\}/ ) do
        match_eval, match_method = eval_token($&)
        if BuildConfig.instance.respond_to?(match_method)
          match_eval = "BuildConfig.instance.#{match_eval}"
        elsif self.methods_available_to_script.include?(match_method)
          match_eval = "self.#{match_eval}"
        else
          raise BakerError, "recipe script error on undefined subsitution: #{$&}"
        end
        # run the evalutation
        begin
          self.instance_eval(match_eval)
        rescue
          raise BakerError, "recipe script subsitution evaluation error: #{$&}"
        end
      end
      script
    end

    # support function for eval_scripter
    def eval_token(raw_marker_match)
      marker_match = raw_marker_match[3..-2].strip
      if marker_match.include?('?')
        # well i would have used regexp if it frig'n worked! :|
        match_rest = marker_match.dup
        mq = match_rest.index('?')
        match = match_rest[0..(mq-1)].downcase
        match_rest = marker_match[(mq+1)..-1].strip
        mq = match_rest.index(' ')
        match_include = match_rest[0..(mq-1)].downcase
        match_print = match_rest[mq..-1].strip.downcase
        match_on = true
      elsif marker_match.include?('!')
        match_rest = marker_match.dup
        mq = match_rest.index('!')
        match = match_rest[0..(mq-1)].downcase
        match_rest = marker_match[(mq+1)..-1].strip
        mq = match_rest.index(' ')
        match_include = match_rest[0..(mq-1)].downcase
        match_print = match_rest[mq..-1].strip.downcase
        match_on = false
      else
        match = marker_match.downcase
        match_on = nil
      end
      match_method, match_keys = match.split('.')  # split off hash lookups
      match_eval = match_method.dup                # build eval
      match_eval += match_keys.collect { |m| "['#{m}']" }.to_s if match_keys
      match_eval += ".include?('#{match_include}') ? '#{match_print}' : ''" if match_on == true
      match_eval += ".include?('#{match_include}') ? '' : '#{match_print}'" if match_on == false
      return match_eval, match_method
    end
 
  end  # EvalScripter
  
end