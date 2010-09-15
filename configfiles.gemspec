# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift File.join File.dirname(__FILE__), 'lib'

require 'configfiles'

Gem::Specification.new do |s|
  s.name = %q{configfiles}
  s.version = ConfigFiles::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Guido De Rosa"]
  s.date = Date.today.to_s
  s.description = %q{A simple library to specify the format of configuration files and the way to turn them into Ruby objects. Ruby1.9 centric. Uses some lazy evaluation. No write support: it's strongly sugested to use ERB or other templating systems for that.}
  s.email = %q{guido.derosa@vemarsas.it}
  s.files = [
    "README.rdoc",
    "Changelog",
    "lib/configfiles.rb",
    "lib/configfiles/extensions/enumerable.rb"
  ]
  s.homepage = %q{http://github.com/gderosa/configfiles}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.extra_rdoc_files = ["README.rdoc"]
  s.require_paths = ["lib"]
  s.summary = %q{A simple library to specify the format of configuration files and the way to turn their data into Ruby objects.}
  s.add_dependency 'facets'
end
