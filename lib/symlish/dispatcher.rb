require_relative 'utils'
require_relative 'link_target'
require_relative 'config'

def dispatch(action, config, options)
    filter_directories(config[:link], options).each do |target|
        puts "💎   Processing #{target.key}"

        # Config targets might have their own ignore flag
        if target.ignore
            puts "⚠️     Skipping: ignore flag is true"
        	next
        elsif !target.valid?
            puts "⚠️     Skipping: no valid target path specified"
        	next
        end

        # Dispatch the action
        case action
            when "link" then do_link(target, options)
            when "unlink" then do_unlink(target, options)
            when "status" then do_status(target)
        end
    end
end

def do_link(link_target, options)
    link_target.items.each do |item|
        # Ignore if:
        # * Source is empty and we ignore empty files/directories
        # * Symlink and points here (no message)
        # * Symlink from somewhere else
        if link_target.ignore_empty && empty?(item.source)
            puts "⚠️     Skipping #{item.source}: Source file/dir is empty"
            next
        elsif item.here?
            next
        elsif link_target.conflict == "skip" && item.symlink?
            puts "⚠️     Skipping #{item.source}: Conflict with another symbolic link"
            next
        end

        # Create the backup if required
        if item.exists? && !item.backup?
            if options.dry_run
                puts "🔁     Would make backup: #{item.backup}"
            else
                item.create_backup
                puts "🔁     Moved existing file to: #{item.backup}"
            end
        end

        # Create the symlink
        if options.dry_run
            puts "📝     Would link: #{item.source} ~> #{item.target}"
        else
            item.create_symlink
            puts "🔗     Linked: #{item.source} ~> #{item.target}"
        end
    end
end

def do_unlink(link_target, options)
    link_target.items.each do |item|
        next unless item.here?

        # Remove the symlink
        if options.dry_run
            puts "🗑️     Would unlink: #{item.target}"
        else
            item.remove_symlink
            puts "🗑️     Unlinked: #{item.source}"
        end

        # Restore the backup
        next unless item.backup?
        if options.dry_run
            puts "🔁     Would restore backup: #{item.backup} ~> #{item.target}"
        else
            item.restore_backup
            puts "🔁     Restored backup: #{item.backup} ~> #{item.target}"
        end
    end
end

def do_status(link_target, options)
    link_target.items.each do |item|
        # Check backup status
        if item.backup?
            puts "🔁     Existing backup: #{item.backup}"
        end

        # Check symlink
        if !item.symlink?
            puts "⚪     #{item.source} (not linked)" 
        elsif item.here?
            puts "🔗     #{item.target} ~> #{item.symlink}"
        else
            puts "⚠️     #{item.target} ~> #{item.symlink} (not a link to this repo)" 
        end
    end
end

=begin
def do_link(link_target, options)
    link_target.items.each do |item|
        # Check if we need to ignore
        # This could be due to: item being empty, conflict, or already being linked
        if empty?(item.source) && link_target.ignore_empty
            puts "⚠️     Skipping #{item.self}: Source file/dir is empty"
            next
        elsif item.symlink?
            if item.here?
                puts "⚠️     Skipping #{item.self}: Conflict with another symbolic link"
                next
            elsif link_target.conflict == "skip"
                # puts "⚠️     Skipping #{item.self}: Conflict with another symbolic link"
                next
            end
        end

        # Create backup
        if item.exists? && !item.backup?
            if options.dry_run
                puts "🔁     Would make backup: #{item.backup}"
            else 
                item.backup
                puts "🔁     Moved existing file to: #{item.backup}"
            end
        end

        # Create symlink
        if options.dry_run
            puts "📝     Would link: #{item.self} ~> #{item.target}"
        else
            item.link
            puts "🔗     Linked: #{item.self} ~> #{item.target}"
        end
    end
end

def do_unlink(link_target, options)
    link_target.items.each do |item|
        # Validate that it's a valid symlink
        if item.symlink?
            unless item.here?
                puts "⚠️     Skipping #{item.self}: Not a link to this repo"
                next 
            end
        else 
            puts "⚪     #{item.self} (not linked)"
            next
        end

        # Remove symlink
        if options.dry_run
            puts "🗑️     Would unlink: #{item.self}"
        else
            item.unlink
            puts "🗑️     Unlinked: #{item.self}"
        end

        next unless item.backup?
        
        # Restore backup
        if options.dry_run
            puts "🔁     Would restore backup: #{item.backup} ~> #{item.target}"
        else
            item.restore
            puts "🔁     Restored backup: #{item.backup} ~> #{item.target}"
        end
    end
end

def do_status(link_target)
    link_target.items.each do |item|
        # Check backup
        unless item.backup?
            puts "🔁     Existing backup: #{item.backup}"
        end
         
        # Check symlink
        unless item.symlink?
            puts "⚪     #{item.self} (not linked)" 
        end

        if item.here?
            puts "🔗     #{item.self} ~> #{item.symlink}"
        else
            puts "⚠️     #{item.self} ~> #{item.symlink} (not a link to this repo)" 
        end
    end
end
=end

=begin
skipped = []
files.each do |f| 
    if target.ignore_empty && (File.empty?(f) || Dir.empty?(f))
        skipped << "⚠️     Skipping #{File.basename(f)}: target is empty"
        next
    end


end

skipped.each { |skip| puts skip }
=end


=begin
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
=end