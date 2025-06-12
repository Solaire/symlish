require_relative 'utils'
require_relative 'link_target'

def dispatch(action, target_dir, options)
	filter_directories(target_dir, options).each do |target|
		puts "📁   Processing: #{File.basename(target)}/"
		skipped = []

		Dir.children(target).each do |child|
			link_target = LinkTarget.new(target, child)

			# Validate
        	if link_target.directory? && !link_target.starts_with_dot?
        	    skipped << "⚠️     Ignoring non-dot directory: #{link_target.rel_path}"
        	    next
        	elsif link_target.zero?
        	    skipped << "⚠️     Skipping empty file: #{link_target.name}"
        	    next
        	end

			# Dispatch the action
			case action
				when "link"		then do_link(link_target, options.dry_run)
				when "unlink"	then do_unlink(link_target, options.dry_run)
				when "status"	then do_status(link_target)
				else print_usage
			end
		end

		skipped.each { |skip| puts skip }
	end
end

def do_link(link_target, dry_run)
    link_target.create_backup(dry_run)
    link_target.create_symlink(dry_run)
end

def do_unlink(link_target, dry_run)
    if link_target.symlink?
        unless link_target.points_here?
            puts "⚠️     Not unlinking: #{link_target.link_target} (not a link to this repo)"
            return
        end
    elsif link_target.link_target_exists?
        puts "❌     #{link_target.link_target} (not a symlink)"
        return 
    else
        puts "⚪     #{link_target.abs_path} (not linked)"
        return 
    end

    link_target.remove_symlink(dry_run)
    link_target.restore_backup(dry_run)
end

def do_status(link_target)
    if link_target.backup_exists?
        puts "🔁     Existing backup: #{link_target.backup_path}"
    end

    if link_target.symlink?
        if link_target.points_here?
            puts "🔗     #{link_target.link_target} ~> #{link_target.readlink}"
        else            
            puts "⚠️     #{link_target.link_target} ~> #{link_target.readlink} (not a link to this repo)" 
        end
    elsif link_target.link_target_exists?
        puts "❌     #{link_target.link_target} exists (not a symlink)"
    else
        puts "⚪     #{link_target.name} (not linked)"
    end
end