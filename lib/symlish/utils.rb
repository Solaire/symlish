require_relative "config"

# <!--
#   - filter_directories(source, options) -> List
# -->
# Reject keys based on the options:
# * ONLY mode: reject keys not present in the source.
# * IGNORE mode: reject keys present in the source.
#
def filter_directories(source, options)
	# ONLY mode: reject keys NOT present in `options.only`
	unless options.only.empty?
		return source.reject { |t| !options.only.include?(t.key) }
	end

	# IGNORE mode: reject keys present in options.ignore
	unless options.ignore.empty?
		return source.reject { |t| options.ignore.include?(t.key) }
	end

	# Return everything
	return source
end

# <!--
#   - empty?(path) -> true or false
# -->
# Returns `true` if path points to an empty file or directory, `false` otherwise.
#
def empty?(path)
		return File.empty?(path) || (File.directory?(path) && Dir.empty?(path))
end

# <!--
#   - file_dir?(path) -> true or false
# -->
# Returns `true` path points to a valid non-symlink file or a directory, `false` otherwise
#
def file_dir?(path)
		return (File.file?(path) && !File.symlink?(path)) || File.directory?(path)
end