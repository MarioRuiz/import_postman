
module ImportPostman
  module Parsers
    module RestClient
	  #can be test-unit or minitest
	  IP_TEST_FRAMEWORK='minitest' unless defined?(IP_TEST_FRAMEWORK)
	  
      def parse_postman_test_headers(module_main_name)
        headers="require 'test-unit'\n" if IP_TEST_FRAMEWORK=='test-unit'
        headers="require 'minitest/autorun'\n" if IP_TEST_FRAMEWORK=='minitest'
        headers+="require 'json'\n"
        headers+="require 'nice_hash'\n"
        headers+="require 'rest-client'\n\n"

        headers+="
        class String
          def json(*keys)
            require 'json'
            return JSON.parse(self, {symbolize_names: true})
          end
          def ==(par)
            if par.kind_of?(Integer) or par.nil? or par.kind_of?(Float) then
              super(par.to_s())
            else
              super(par)
            end
          end
        end\n\n"
        headers+="class Test#{module_main_name} < Test::Unit::TestCase\n\n" if IP_TEST_FRAMEWORK=='test-unit'
        headers+="class Test#{module_main_name} < Minitest::Test\n\n" if IP_TEST_FRAMEWORK=='minitest'
		headers+="i_suck_and_my_tests_are_order_dependent!\n\n" if IP_TEST_FRAMEWORK=='minitest'
		headers+="\tdef setup\n\t\t"
        headers+='@http=RestClient::Resource.new("http://#{$host}")'
        headers+="\n\tend\n"
        return headers
      end

      def parse_postman_test(js, num_test, test_name, method_to_call)
        rcode_lines=Array.new
        rcode_txt="\tdef test_#{num_test.to_s.rjust(3, "0")}_#{test_name}\n"
        res=method_to_call.scan(/(\w+)\((.+)\)/)
        met=res[0][0]
        req=res[0][1]
        if met=='post' or met=='put'
          method_to_call="#{met} req[:data].to_json, req.headers"
        else
          method_to_call="#{met} req.headers"
        end

        rcode_txt+="\t\treq=#{req}\n"
        rcode_txt+="\t\tbegin\n"
        rcode_txt+="\t\t\tresponse=@http[req.path].#{method_to_call}\n"
        rcode_txt+="\t\trescue RestClient::ExceptionWithResponse => res\n"
        rcode_txt+="\t\t\tresponse=res.response\n"
        rcode_txt+="\t\tend\n"

        var_data=""
        blocks=Array.new
        blocks_add=Array.new
        js.split(/$/).each {|line|

          line_orig=line.dup
          rcode=""
          line.gsub!("===", "==")
          line.gsub!(/;$/, "")
          line.gsub!('\"','"')
          line.gsub!("responseCode.code", "response.code")
          line.gsub!(" : ", ": ")
          #pm.environment.set("coupon_id_dgrd", jsonData.coupons[0].primaryCouponId)
          if line.scan(/pm\.environment\.set\(\"(\w+)\",\s*(.+)\)/).size>0
            rcode=line.gsub!(/pm\.environment\.set\(\"(\w+)\",\s*(.+)\)/, '$\1 = \2')
          end
          line.gsub!(/environment\["(\w+)"\]/, '$\1')
          line.gsub!(/environment\./, '$')
          line.gsub!(/postman.getEnvironmentVariable\(['"](\w+)['"]\)/, '$\1')
          #postman.getResponseHeader('WWW-Authenticate')
          line.gsub!(/postman\.getResponseHeader\(['"]([\w-]+)['"]\)/, 'response.headers["\1"]')
          line.gsub!(/parseInt\(([\w\$\-]+)\)/, '\1.to_i')
          line.gsub!(".indexOf", ".include?")
          line.gsub!(/\.include\?\((\w+)\)==\s*-1\s*/, '.include?(\1)==false')
          line.gsub!(/\.include\?\((\w+)\)\s*==\s*0/, '.include?(\1)==true')
          line.gsub!("responseBody", "response.body")
          line.gsub!(".has(", ".include?(")
          line.gsub!(/(['"\w\s]+) in (\w+)/, '\1.include?(\2)') if line.scan(/for\s*\(/).size==0

          #typeof jsonData.guaranteedPrizeData[0].gpData== "string"
          if line.scan(/typeof (.+)\s*==\s*"(\w+)"/).size>0
            res=line.scan(/typeof (.+)\s*==\s*"(\w+)"/)
            var=res[0][0]
            type=res[0][1].capitalize
            line.gsub!(/typeof (.+)\s*==\s*"(\w+)"/, "#{var}.kind_of?(#{type})")
          end

          if blocks[-1]==:if_one_line and line.strip.scan(/\s*{/).size>0 #'if' is a block not a line
            blocks[-1]=:if_block
          end

          if line.strip=="" or
              (line.strip=="{" and (blocks[-1]==:if_one_line or blocks[-1]==:if_block or blocks[-1]==:for))
            next
          elsif blocks[-1]==:if_one_line and line.scan(/^\s*if\s+/).size==0 #we are in the next line after if
            rcode="#{line.strip}\n\t\tend"
            blocks.pop
          elsif line.scan(/\s*\/\//).size>0
            rcode="# #{line.scan(/\s*\/\/(.+)/).join}"
          elsif blocks[-1]==:comment
            rcode="# #{line.lstrip}"
            if line.scan(/\s*\*\//).size>0
              blocks.pop
            end
          elsif line.scan(/\s*\/\*/).size>0
            rcode="# #{line.scan(/\s*\/\*(.+)/).join}"
            unless line.scan(/\s*\*\//).size>0
              blocks<<:comment
            end
          elsif line.scan(/^\s*try\s*{/).size>0
            blocks<<:try
            rcode="begin"
          elsif line.strip.scan("}").size>0 and blocks[-1]==:try
            blocks.pop
            rcode=""
          elsif line.scan(/^\s*catch\s*\((\w+)\)\s*{/).size>0
            rcode="rescue Exception =>#{line.scan(/^\s*catch\s*\((\w+)\)\s*{/).join}"
            if line.scan(/}\s*$/).size>0 #ends in one line
              rcode+="\n\t\tend\n"
            end
            blocks<<:catch
          elsif line.strip.scan("}").size>0 and blocks[-1]==:try
            blocks.pop
            rcode=""
          elsif line.strip.scan(/else if\s*/).size>0 and rcode_lines.size>0 and rcode_lines[-1].strip=="end"
            rcode_lines.pop
            rcode=line.gsub("else if","elsif").strip.gsub(/\s*\{$/, '')
            blocks<<:if_block
          elsif line.strip.scan(/else\s*\{/).size>0 and rcode_lines.size>0 and rcode_lines[-1].strip=="end"
            rcode_lines.pop
            rcode="else"
            blocks<<:if_block
          elsif line.scan(/^\s*\w+\.push/).size>0
            #arrayOfValuesFromhighestNumber4Comparing.push(highestNumber4Comparing[j][key])
            rcode=line.strip.gsub(/;\s*$/, "")
          elsif line.scan(/^\s*if\s*/).size>0
            #if ( key === numberCount && numberCount4Comparing[k][key] != jsonData.games[i].properties.numberCount)\n"
            if line.scan(/{\s*$/).size==0 #only one like for the if on next line, not a block
              blocks<<:if_one_line
            else
              blocks<<:if_block
            end
            rcode=line.strip.gsub(/\s*\{$/, '')
          elsif line.strip=="}"
            if blocks[-1]==:for
              rcode="#{blocks_add[blocks.size-1]}\t\tend"
              blocks_add[blocks.size-1]=""
              blocks.pop
            else
              rcode="end"
              blocks_add[blocks.size-1]=""
              blocks.pop
            end
          elsif line.scan(/for\s*\(var (\w+)\s+in/).size>0
            #for(var key in highestNumber4Comparing[j])
            var=line.scan(/for\s*\(var (\w+)\s+in\s+([^\)]+)\)/)
            variab=var[0][0]
            compar=var[0][1]
            #for i in 0..jsonData.games.length-1
            rcode="for #{variab} in #{compar}"
            blocks<<:for
          elsif line.scan(/for\s*\(var (\w+\s*=\s*\d+);([^;]+)/).size>0
            #for(var i=0;i<jsonData.games.length;i++){
            var=line.scan(/for\s*\(var (\w+\s*=\s*\d+);([^;]+)/)
            variab=var[0][0]
            compar=var[0][1]
            rcode="#{variab}\n\t\twhile #{compar}\n"
            blocks<<:for
            blocks_add[blocks.size-1]="\t\t#{variab.scan(/(\w+)\s*=/).join}+=1\n"
          elsif line.scan(/\w\s*;\s*\w/).size>0
            #any line with more than one instruction
            rcode="#Line not added: #{line.lstrip}"
          elsif var_data=="" and line.scan(/var\s(\w+)\s*=\s*JSON\.parse\(response.body\)/).size>0
            var_data = line.scan(/var\s(\w+)\s*=\s*JSON\.parse\(response.body\)/).join
            rcode="#{var_data} = response.body.json"
          elsif line.scan(/postman\.setEnvironmentVariable\(/).size>0
            vart=line.scan(/postman\.setEnvironmentVariable\("(\w+)"/).join
            valt=line.scan(/postman\.setEnvironmentVariable\("\w+",\s*(.+)\)$/).join
            rcode="$#{vart} = #{valt}"
          elsif line.scan(/var \w+\s*=/).size>0
            vart=line.scan(/var\s+(\w+)\s*/).join
            valt=line.scan(/var\s+\w+\s*=\s*(.+)$/).join
            valt[-1]="" if valt[-1]=="," #multiple assigment
            rcode="#{vart} = #{valt}"
          elsif line.scan(/^\s*\w+\s*=\s*/).size>0
            vart=line.scan(/^\s*(\w+)\s*/).join
            valt=line.scan(/^\s*\w+\s*=\s*(.+)$/).join
            valt[-1]="" if valt[-1]=="," #multiple assigment
            rcode="#{vart} = #{valt}"
          elsif line.scan(/tests\[/).size>0
            msg=line.scan(/tests\["([^=]*)"\]/).join
            val=line.scan(/tests\["[^=]*"\]\s*=\s*(.+)/).join
            if msg==""
              msg=line.scan(/tests\[(.*)\]\s=\s/).join
              val=line.scan(/tests\[.*\]\s=\s(.+)/).join
            else
              msg="\"#{msg}\""
            end
            rcode="assert(#{val}, #{msg})"
          elsif rcode==""
            rcode="#Line not added: #{line_orig.lstrip}"
          end
          rcode_lines.push("\t\t#{rcode.to_s.lstrip}\n") unless rcode==""
        }
        rcode_txt+=rcode_lines.join
        rcode_txt+="\tend\n\n"
        return rcode_txt
      end

    end

  end
end
