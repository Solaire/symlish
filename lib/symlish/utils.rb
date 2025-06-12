require_relative "config"

# Return list of all children directories of [root].
def list_directories(root)
	puts "🔍 Scanning dotfiles in: #{File.realdirpath(root)}/"

    entries = Dir.children(root)
    entries.map! { |entry| File.join(root, entry) }
    return entries.select { |path| File.directory?(path) }
end

# Find required directories in [root] and filter them out according to [options].
def filter_directories(root, options)
	dirs = []

	config = load_config(root)
	ignored_paths = config[:ignore]

	# ONLY mode
	unless options.only.empty?
		options.only.each do |name|
			path = File.join(root, name)
			unless File.directory?(path)
				warn "Error: --only item '#{path}' does not exist in '#{root}'"
				exit 1
			end

			dirs << path
		end

		return dirs
	end

	# Get actual directories and filter out.
	dirs = list_directories(root)
 
	# IGNORE from config file.
	dirs.reject! { |path| ignored_paths.include?(path) }

	# IGNORE from flags.
	unless options.ignore.empty?
		ignore_paths = options.ignore.map { |name| File.join(root, name) }
		dirs.reject! { |path| ignore_paths.include?(path) }
	end

	# INCLUDE
	unless options.include.empty?
		options.include.each do |name|
			path = File.join(root, name)
			unless File.directory?(path)
				warn "Error: --include item '#{path}' does not exist in '#{root}'"
				exit 1
			end

			dirs << path unless dirs.include?(path)
		end
	end

	return dirs
end