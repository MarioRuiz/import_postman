
require 'nice_hash'

##################################################################################
# This method import a postman collection to be used as RequestHash object
# Input:
#   postman_collection_file_path: specify just the name of the collection without the extension and in case we have on the same folder the environment and/or the global variable files they will be imported automatically also.
#     It is necessary in that case to use the default extensions from Postman: .postman_collection, .postman_environment, .postman_globals.
#   env_file: (optional) path to the environment postman file
#   global_file: (optional) path to the global postman file
#   output_file: (optional) path to output file
#   mock_vars: (optional) Hash including all postman variables we want to mock for example: {"requestId": "return_requestId_method"}
# Output:
#   In case output_file is supplied the file will be exported to that location and name. In case not .rb extension it will be added.
#   In case a output_file is not supplied then automatically will create one with the same name as postman_collection_file_path and .rb extension on the same path
#   The postman environments variables will be added as global variables at the beginning of the resultant file
#   The postman global variables will be added as global variables at the beginning of the resultant file
#   All other postman variables will be added as parameters for the request
#   The file when converted will be possible to be used in your code, for example:
#     request=RESTRequests::Customer.addAlias()
#   The Postman Dynamic Variables will be converted into Ruby variables. Added $guid, $timestamp and $randomint
# examples:
#   only one parameter, the collection name with relative path and no extension supplied.
#   The file on the folder would be: MyCustomer.json.postman_collection
#   In case a MyCustomer.json.postman_environment and/or MyCustomer.json.postman_globals found on the same folder, they will be automatically imported also
#     import_postman "./interfaces/rest/postman/MyCustomer.json"
#   relative paths, collection, environmental variables and global variables, with different extensions that the default ones
#     import_postman "./interfaces/rest/postman/collection.json.txt", env_file: "./interfaces/rest/postman/env.json.txt", global_file: "./interfaces/rest/postman/global.json.txt"
#   full path for collection, environmental variables and global variables. relative path for resultant string. Different names and extensions
#     import_postman "c:/MyPostManFiles/MyCustomer_postman_collection.json", env_file: "c:/MyPostManFiles/MyCustomer_env", global_file: "c:/MyPostManFiles/MyCustomer_global", output_file: "./interfaces/rest/customer_postman.rb"
##################################################################################
def import_postman(postman_collection_file_path, env_file: postman_collection_file_path+".postman_environment", global_file: postman_collection_file_path+".postman_globals", output_file: postman_collection_file_path+".rb", mock_vars: Hash.new())
  #.postman_collection, .postman_environment, .postman_globals
  require 'json'
  postman_env_file_path = env_file
  postman_global_file_path = global_file
  output_file_path = output_file

  if postman_collection_file_path["./"].nil? then
    file_to_convert=postman_collection_file_path
  else
    file_to_convert=Dir.pwd.to_s() + "/" + postman_collection_file_path.gsub("./", "")
  end

  unless File.exist?(file_to_convert)
    file_to_convert+=".postman_collection"
  end

  if output_file_path['.rb'].nil? then
    output_file_path+=".rb"
  end

  unless output_file_path["./"].nil? then
    output_file_path=Dir.pwd.to_s() + "/" + output_file_path.gsub("./", "")
  end
  env_vars = {}

  if defined?(parse_postman_test)
    test_output_file_path = output_file_path.gsub(/\.rb$/, "_tests.rb")
    tests = ""
    num_test = 0
  end


  unless postman_global_file_path==""
    unless postman_global_file_path["./"].nil? then
      postman_global_file_path=Dir.pwd.to_s() + "/" + postman_global_file_path.gsub("./", "")
    end
    if File.exist?(postman_global_file_path) then
      begin
        file=File.read(postman_global_file_path)
        puts "** Postman Global file imported: #{postman_global_file_path}"
      rescue Exception => stack
        warn "* It seems there was a problem reading the Global file #{postman_global_file_path}"
        warn stack.to_s()
        return false
      end

      val=JSON.parse(file, {symbolize_names: true})
      if val.keys.include?(:values) then
        val=val[:values]
      end
      val.each {|v|
        env_vars[v[:key]]=v[:value] if v[:key]!="url" and v[:key]!=:url and v[:key]!="host" and v[:key]!=:host
      }
    end
  end

  unless postman_env_file_path==""
    unless postman_env_file_path["./"].nil? then
      postman_env_file_path=Dir.pwd.to_s() + "/" + postman_env_file_path.gsub("./", "")
    end
    if File.exist?(postman_env_file_path) then
      begin
        file=File.read(postman_env_file_path)
        puts "** Postman Env file imported: #{postman_env_file_path}"
      rescue Exception => stack
        warn "* It seems there was a problem reading the Env file #{postman_env_file_path}"
        warn stack.to_s()
        return false
      end

      val=JSON.parse(file, {symbolize_names: true})
      val[:values].each {|v|
        env_vars[v[:key]]=v[:value] if v[:key]!="url" and v[:key]!=:url and v[:key]!="host" and v[:key]!=:host
      }
    end
  end

  begin
    if File.exist?(file_to_convert) then
      file=File.read(file_to_convert)
      puts "** Postman Collection file imported: #{file_to_convert}"
    else
      warn "* It seems the collection file #{file_to_convert} doesn't exist"
      return false
    end
  rescue Exception => stack
    warn "* It seems there was a problem reading the collection file #{file_to_convert}"
    warn stack.to_s()
    return false
  end

  val=JSON.parse(file, {symbolize_names: true})

  module_main_name=val[:name].gsub(/^[\d\s\W]+/, "")
  module_main_name=module_main_name.gsub(/\W+/, "_")
  module_main_name=module_main_name[0, 1].upcase + module_main_name[1..-1] #to be sure first character is in capitalize
  if defined?(parse_postman_test_headers)
    tests="require './#{File.basename output_file_path}'\n"
    tests+=parse_postman_test_headers(module_main_name)
  end

  requests={}
  if val.keys.include?(:folders) and val.keys.include?(:requests) then
    requests_added=[]
    val[:folders].each {|folder|
      folder[:order].each {|reqnum|
        request=val[:requests].select {|f| f[:id]==reqnum}
        if request.size==1 #found one
          module_name=folder[:name].gsub(/^[\d\s\W]+/, "")
          module_name=module_name.gsub(/\W+/, "_")
          module_name=module_name[0, 1].upcase + module_name[1..-1] #to be sure first character is in capitalize
          requests[module_name]=Array.new() unless requests.keys.include?(module_name)
          requests[module_name].push(request[0])
          requests_added.push(reqnum)
        end
      }
    }
    module_main_name="" if requests.keys.size>0 #there are folders
    if val[:requests].size>requests_added.size then #if there are some requests that are not in folders
      requests[""]=Array.new()
      val[:requests].each {|req|
        if !requests_added.include?(req[:id]) then
          requests[""].push(req)
        end
      }
    end
  elsif val.keys.include?(:requests) then
    requests[""]=Array.new()
    val[:requests].each {|req|
      requests[""].push(req)
    }
  end


  rest_methods=""
  all_variables_on_path=[]
  all_variables_on_headers=[]
  requests.each {|folder, requests_folder|
    rest_methods+="\n   \tmodule #{folder}\n\n" unless folder==""

    requests_folder.each {|request|
      #url, host or server are the postman variables for the testserver
      path=request[:url].gsub(/\{\{url\}\}/, "").gsub(/\{\{server\}\}/, "").gsub(/\{\{host\}\}/, "").gsub(/https?:\/\//, "").gsub("{{", "\#{").gsub("}}", "}")
      variables_on_path=path.scan(/{(\w+)}/)
      variables_on_path.uniq!
      if request[:rawModeData].to_s()!="" then
        data=request[:rawModeData].gsub("\r", "")
        variables_on_data=Array.new
        begin
          JSON.parse(data.gsub("{{",'"').gsub("}}",'"'))
          data.gsub!(/"([^"]+)"\s*:/, '\1:')
          variables_on_data=data.scan(/{([\w\-]+)}/)
          variables_on_data.uniq!
          if variables_on_data.size>0 and variables_on_data[0].size>0
            variables_on_data[0].each {|v|
              #for the case it is not a string
              data.gsub!(": {{#{v}}}", ": #{v.gsub("-", "_").downcase}")
              #for the case it is a string
              data.gsub!("{{#{v}}}", "{{#{v.gsub("-", "_").downcase}}}")
              v.gsub!("-", "_")
            }
          end
          data.gsub!("{{", "\#{")
          data.gsub!("}}", "}")
          data.gsub!(/:\s*null/, ": nil")
        rescue
          data='"'+request[:rawModeData].gsub("\r", "") + '"'
        end
      else
        data=""
        variables_on_data=[]
      end
      all_variables_on_path+=variables_on_path
      all_variables_on_path.uniq!
      header=request[:headers].gsub(/\{\{url\}\}/, "").gsub(/\{\{server\}\}/, "").gsub(/\{\{host\}\}/, "").gsub(/https?:\/\//, "").gsub('"','\"')
      #remove headers starting by //
      header.gsub!(/^\/\/.+$/,'')
      #remove empty lines
      header.gsub!(/^\s*$\n/,'')
      variables_on_header=header.scan(/{([\w\-]+)}/)
      variables_on_header.uniq!
      if variables_on_header.size>0 and variables_on_header[0].size>0
        variables_on_header[0].each {|v|
          header.gsub!("{{#{v}}}", "{{#{v.gsub("-", "_")}}}")
          v.gsub!("-", "_")
        }
      end
      header.gsub!("{{", '#{$')
      header.gsub!('}}', '}')
      header.gsub!("\n", '", ')
      header.gsub!(/([^:,\s]+):\s+/, '"\1"=>"')
      header.gsub!(/=>([^,"]+)/, '=>"\1"')
      header.gsub!(/,\s*$/, '')
      header+='"' if header.length>0 and header[-1]!='"'
      all_variables_on_headers+=variables_on_header
      all_variables_on_headers.uniq!
      variables_txt=""
      variables_on_path.each {|var|
        variables_txt+="#{var.join}:$#{var.join}, "
      }
      if variables_on_data.size>0 then
        variables_on_data.each {|var|
          if !variables_on_path.include?(var) then
            if env_vars.keys.include?(var.join) then
              variables_txt+="#{var.join.downcase}:$#{var.join.downcase}, "
            else
              variables_txt+="#{var.join.downcase}:'', "
            end
          end
        }
      end
      variables_txt.chop!
      variables_txt.chop!
      method_name=request[:name].gsub(/\W+/, "_")
      method_name.chop! if method_name[-1]=="_"
      method_name=method_name[0, 1].downcase + method_name[1..-1] #to be sure first character is in downcase
      unless request[:description].to_s==""
        request[:description].to_s.lines.each{|desc|
          rest_methods+="\t\t# #{desc}"
        }
        rest_methods+="\n"
      end
      rest_methods+="\t\tdef self.#{method_name}(#{variables_txt})\n\t\t\treturn {\n"
      rest_methods+="\t\t\t\tpath: \"#{path}\",\n"
      rest_methods+="\t\t\t\theaders: {#{header}},\n"
      if data!="" then
        rest_methods+="\t\t\t\tdata: #{data.split("\n").join("\n\t\t\t\t")}"
      end
      rest_methods+="\n\t\t\t}\n\t\tend\n\n"
      if request[:tests]!="" and defined?(parse_postman_test)
        num_test+=1
        #todo: add here preRequestScript or in the parse_postman_test method, decide
        method_to_call= "RESTRequests"
        method_to_call+="::#{module_main_name}" unless module_main_name.to_s()==""
        method_to_call+="::#{folder}" unless folder.to_s()==""
        method_to_call+=".#{method_name}"
        method_to_call="#{request[:method].downcase}(#{method_to_call})"
        rcode = parse_postman_test(request[:tests].to_s, num_test, method_name, method_to_call)
        tests+=rcode
      end
    }
    rest_methods+="\n   \tend\n\n" unless folder==''
  }
  rest_methods+="   end" unless module_main_name.to_s()==""
  rest_methods+="\nend"
  header_vars="# Postman variables\n"
  env_vars.each {|key, value|
    header_vars+="   $#{key.gsub("-", "_").downcase}='#{value}'\n"
  }
  header_vars+="\n\nmodule RESTRequests\n"
  header_vars+="\n   module #{module_main_name}\n\n" if module_main_name.to_s()!=""

  rest_methods= header_vars + rest_methods

  #Postman dynamic variables
  rest_methods.gsub!(/\$randomInt([^a-zA-Z=])/i, 'rand(1001)\1')
  rest_methods.gsub!(/\$timestamp([^a-zA-Z=])/i, 'Time.now.strftime(\'%Y-%m-%dT%H:%M:%S.000Z\')\1')
  rest_methods.gsub!(/\$guid([^a-zA-Z=])/i, 'SecureRandom.uuid\1')
  mock_vars.each {|mvar, mvalue|
    rest_methods.gsub!(/\$#{mvar}([^a-zA-Z=])/i, mvalue+'\1')
  }
  rest_methods.gsub!(/\s+,$/, ",") #to avoid orphan lines with only one comma
  tests+="end" if defined?(parse_postman_test)
  if output_file_path!=""
    File.open(output_file_path, 'w').write(rest_methods)
    puts "** Requests file: #{output_file_path} that contains the code of the requests and the environment variables after importing the Postman file"
    if defined?(parse_postman_test)
      File.open(test_output_file_path, 'w').write(tests)
      puts "** Tests file: #{test_output_file_path} that contains the code of the tests after importing the Postman file"
    end
  end

  begin
    eval(rest_methods)
  rescue Exception => stack
    warn "* It seems there was a problem importing the postman file #{postman_collection_file_path}"
    warn stack.to_s()
  end

end
