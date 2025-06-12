Gem::Specification.new do |spec|
	spec.name          = "symlish"
	spec.version       = "0.0.1"
	spec.authors       = ["Solaire"]
	spec.email         = ["22472584+Solaire@users.noreply.github.com"]
	
	spec.summary       = "Symlink manager for dotfiles with backups and configuration"
	spec.description   = "Symlish is a simple command-line tool to manage symbolic links for dotfiles."
	spec.homepage      = "https://github.com/solaire/symlish"
	spec.license       = "GPL-3.0"
	
	spec.required_ruby_version = ">= 3.2.8"
	
	spec.files = Dir["lib/**/*.rb"] + ["bin/symlish", "README.md", "LICENSE"]
	spec.bindir        = "bin"
	spec.executables   = ["symlish"]
	spec.require_paths = ["lib"]
end
