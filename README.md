
*PAY ATTENTION THIS REPOSITORY AND THE ASSOCIATED GEM ARE ARCHIVED! NO LONGER WORK DONE.*  

# ImportPostman
## Description
Using import_postman method you will be able to import a postman collection and create a Ruby Requests Hash containing the path, headers, data...

You can also generate the Ruby tests from the tests you have declared on your collection by using the ImportPostman::Parsers module

Feel free to add more parsers or improve existing ones

## Input parameters

The import_postman method has these arguments: 

    postman_collection_file_path: (positional) (String)
        Specify just the name of the collection without the extension and in case we have on the same folder the environment and/or the global variable files they will be imported automatically also.
        It is necessary in that case to use the default extensions from Postman: .postman_collection, .postman_environment, .postman_globals.
        The postman collection need to be exported as v1
        
    env_file: (optional) (keyword) (String) 
        Path to the environment postman file

    global_file: (optional)  (keyword) (String)
        Path to the global postman file
        
    output_file: (optional)  (keyword) (String)
        Path to output file

    mock_vars: (optional)  (keyword) (Hash) 
        Hash including all postman variables we want to mock for example: {"requestId": "return_requestId_method"}


## Output
In case output_file is supplied the file will be exported to that location and name. In case not .rb extension it will be added.

In case a output_file is not supplied then automatically will create one with the same name as postman_collection_file_path and .rb extension on the same path

The postman environments variables will be added as global variables at the beginning of the resultant file

The postman global variables will be added as global variables at the beginning of the resultant file

All other postman variables will be added as parameters on the request methods created

The file when converted will be possible to be used in your code, for example:

```ruby
request=RESTRequests::Customer.addAlias()
```

The Postman Dynamic Variables will be converted into Ruby variables. Added $guid, $timestamp and $randomint

## Examples of Use

### Case #1

Only one parameter, the collection name with relative path and no extension supplied.

The file on the folder would be: MyCustomer.json.postman_collection

In case a MyCustomer.json.postman_environment and/or MyCustomer.json.postman_globals found on the same folder, they will be automatically imported also

```ruby
     import_postman "./interfaces/rest/postman/MyCustomer.json"
```

### Case #2
     
Relative paths, collection, environmental variables and global variables, with different extensions that the default ones

```ruby
     import_postman "./interfaces/rest/postman/collection.json.txt", 
       env_file: "./interfaces/rest/postman/env.json.txt", 
       global_file: "./interfaces/rest/postman/global.json.txt"
```

### Case #3

Full path for collection, environmental variables and global variables. relative path for resultant string. Different names and extensions

```ruby
     import_postman "c:/MyPostManFiles/MyCustomer_postman_collection.json", 
     env_file: "c:/MyPostManFiles/MyCustomer_env", 
     global_file: "c:/MyPostManFiles/MyCustomer_global", 
     output_file: "./interfaces/rest/customer_postman.rb"
```

### Case #4
Change the value of an environmental variable and create tests (mini-test) using the rest-client library

```ruby
  require 'string_pattern' #to generate the random value for requestId

  require 'import_postman/parsers/rest_client' #to generate the tests
  include ImportPostman::Parsers::RestClient
  
  require 'import_postman'
  import_postman "./my_collections/MyCustomer.json",
                  mock_vars: {"requestId": " '6:/Nx/'.gen"}
```

### Case #5
Change the value of an environmental variable and create tests (test-unit) using the rest-client library

```ruby
  require 'string_pattern' #to generate the random value for requestId

  IP_TEST_FRAMEWORK='test-unit'
  require 'import_postman/parsers/rest_client' #to generate the tests
  include ImportPostman::Parsers::RestClient
  
  require 'import_postman'
  import_postman "./my_collections/MyCustomer.json",
                  mock_vars: {"requestId": " '6:/Nx/'.gen"}
```

The tests file will be generated on the same folder than the output_file with the same name but finish by _tests

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marioruiz/import_postman.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

