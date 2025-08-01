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
            puts "⚠️     Skipping #{item.source}: Source #{item.type} is empty"
            next
        elsif item.here?
            next
        elsif item.symlink? # && link_target.conflict == "skip" (FIXME: Add support for conflict resolution)
            puts "⚠️     Skipping #{item.source}: Conflict with another symbolic link"
            next
        end

        # Create the backup if required
        if item.can_backup? && !item.backup?
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

def do_status(link_target)
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