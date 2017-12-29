
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "trueskill/version"

Gem::Specification.new do |spec|
  spec.name          = "trueskill"
  spec.version       = TrueSkill::VERSION
  spec.authors       = ["Ryan Foster"]
  spec.email         = ["theorygeek@gmail.com"]

  spec.summary       = %q{Port of Jeff Moser's TrueSkill implementation from C# to Ruby}
  spec.homepage      = "https://github.com/theorygeek/trueskill"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
