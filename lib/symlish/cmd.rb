require 'optparse'
require 'ostruct'

COMMANDS = %w[link unlink status help]

def parse_command_line
	options = OpenStruct.new(
    	dry_run: false,
    	include: [],
    	ignore: [],
    	only: []
  	)

	args = ARGV.dup
	target_dir = args.shift

	action = args.shift
	action = "help" unless COMMANDS.include?(action)

	unless target_dir && File.directory?(target_dir)
		warn "Error: First argument must be a valid directory path"
    exit 1
	end
	
	# Parse options
	OptionParser.new do |opts|
		opts.on("--dry-run", 				"Enable dry run mode") 							{ options.dry_run = true }
		opts.on("--include x,y,z", 	Array, 	"Items to include (comma separated)") 			{ |list| options.include = list }
		opts.on("--ignore x,y,z", 	Array, 	"Items to ignore (comma separated)") 			{ |list| options.ignore = list }
		opts.on("--only x,y,z",  	Array,	"Exclusive items (not with include/ignore)") 	{ |list| options.only = list }
	end.parse!(args)

	# Validate option combinations.
	if !options.only.empty? && (!options.include.empty? || !options.ignore.empty?)
	    warn "Error: --only cannot be used alongside --include or --ignore"
	    exit 1
	end

	return action, target_dir, options
end