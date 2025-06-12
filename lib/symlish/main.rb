module Symlish
	class Main
		def self.run
			action, target_dir, options = parse_command_line
			if action == "help"
				print_usage
				exit 0
			end
			dispatch(action, target_dir, options)
			puts "🏁 Goodbye."
		end

		def print_usage
		    puts <<~USAGE
		        Usage: #{File.basename($0)} <directory> <command> [options]
				
		        Commands:
		            link      Create symlinks
		            unlink    Remove symlinks
		            status    Show symlink status
		            help      Print this guide
				
		        Options:
		            --dry-run           Simulate operation without making changes
		            --include x,y,z		List of items to include
		            --ignore  x,y,z		List of items to ignore
		            --only    x,y,z		Exclusive list (incompatible with include/ignore)
		    USAGE
		end
	end
end