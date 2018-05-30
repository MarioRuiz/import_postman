Gem::Specification.new do |s|
  s.name        = 'import_postman'
  s.version     = '1.5.0'
  s.summary     = "This gem imports a postman collection to be used as RequestHash object"
  s.description = "This gem imports a postman collection to be used as RequestHash object"
  s.authors     = ["Mario Ruiz"]
  s.email       = 'marioruizs@gmail.com'
  s.files       = ["LICENSE","README.md","lib/import_postman.rb","lib/import_postman/parsers/rest_client.rb"]
  s.extra_rdoc_files = ["LICENSE","README.md"]
  s.homepage    = 'https://github.com/MarioRuiz/import_postman'
  s.license       = 'MIT'
  s.add_runtime_dependency 'nice_hash', '~> 1.0', '>= 1.0.0'
end

