
module Baker

  module Shell
  
    # shell executes a shell command from a string
    # it dumps the string into a temporary file in
    # the given directory, then executes it and deletes it.
    # if no #! appears at the beginning it is assumed to be a bash script

    def shell(raw_script, working_directory='./')
      script = raw_script.to_s.strip
      #puts script  # debug
      if script != ''
        #script = build_sub(script)
        #check_sub(script)
        #current_dir = Dir.getwd
        Dir.chdir(working_directory)
        begin
          File.open('baker__tempscript.sh','w') do |x|
            x << "#!#{ENV['SHELL']}\n" if script[0..1] != '#!'
            x << script
          end
          File.chmod(0755,'baker__tempscript.sh')
          `./baker__tempscript.sh`
        rescue
          raise BakerError, "error occured while tryng to execute script"
        ensure
          #File.delete('baker__tempscript.sh')  # temporary remark
          #Dir.chdir(current_dir)
        end
      end
    end
    private :shell 

  end
  
end

