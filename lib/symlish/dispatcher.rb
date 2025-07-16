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
        elsif !target.target_path?
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
        # Check if we need to ignore
        # This could be due to: item being empty, conflict, or already being linked
        next if item.ignore?

        # Create backup
        if item.existing?
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
                puts "⚠️     Not unlinking: #{item.self} (not a link to this repo)"
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