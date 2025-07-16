class LinkTarget
    attr_accessor :key, :target, :target_path, :files, :conflict, :ignore, :ignore_empty

    def initialize(key, data, abs_root)
        @key = key

        # Load all data
        @target = data["target"]
        @target_path = nil
        @conflict = data.key?("conflict") ? data["conflict"] : "skip"
        @ignore = data.key?("ignore") ? data["ignore"] : false
        @ignore_empty = data.key?("ignore-empty") ? data["ignore-empty"] : true

        # Apply default value to 'conflict'.
        unless ["skip", "force"].include? @conflict 
            @conflict = "skip"
        end

        # Create a absolute path for the target and expand with glob
        target_root = File.join(abs_root, @target)
        @files = Dir.glob(target_root, File::FNM_DOTMATCH).reject do |path| 
            File.basename(path) == '.' || File.basename(path) == '..'
        end

        # Look through the specified paths and find the first suitable one
        data["paths"].each do |path|
            expanded_path = path.gsub(/\$(\w+)/) do |match|
                env_var = match[1..] # Extract the variable name (e.g. HOME from $HOME)
                ENV[env_var] || ''
            end

            p = File.expand_path(expanded_path)
            if File.exist?(p)
                @target_path = p
                break
            end
        end
    end

    def check_status()
        @files.each do |file|
            link_target = File.join(@target_path, File.basename(file))
            backup_path = "#{link_target}.bak"
    
            # Check backup
            if File.file?(backup_path) || File.directory?(backup_path)
                puts "🔁     Existing backup: #{backup_path}"
                next
            end
    
            # Check if it's a symlink
            if File.symlink?(link_target)
                actual_link = File.readlink(link_target)
                if actual_link == file # Points here
                    puts "🔗     #{link_target} ~> #{actual_link}"
                else
                    puts "⚠️     #{link_target} ~> #{actual_link} (not a link to this repo)" 
                end
            else
                puts "⚪     #{file} (not linked)" 
            end
        end
    end

    def create_link(dry_run)
        @files.each do |file|
            link_target = File.join(@target_path, File.basename(file))
            backup_path = "#{link_target}.bak"

            # Check if empty and we ignore empty elements
            if @ignore_empty && (File.empty?(file) || Dir.empty?(file))
                puts "⚠️     Skipping: #{File.basename(file)} is empty"
                next
            end

            # Now check if symlink to this already exists or, if symlink to another file, we need to ignore
            if File.symlink?(link_target)
                actual_link = File.readlink(link_target)
                if actual_link == file
                    # Already linked to this
                    next
                elsif @conflict == "skip"
                    puts "⚠️     Skipping: Conflict detected and resolution is set to 'skip'"
                    next
                elsif dry_run
                    puts "📝     Would overwrite existing symlink: #{actual_link}"
                    next
                end

                # If here then it means that it's not a dry run and need to delete existing link
                File.delete(@link_target)
            end

            # Check if we need to make a backup
            unless File.exist?(backup_path) || !File.exist?(link_target)
                if dry_run
                    puts "🔁     Would make backup: #{link_target} ~> #{backup_path}"
                else
                    File.rename(link_target, backup_path)
                    puts "🔁     Moved existing file to: #{backup_path}"
                end
            end

            # Create the symbolic link
            if dry_run
                puts "📝     Would link: #{File.basename(file)} ~> #{link_target}"
            else
                File.symlink(file, link_target)
                puts "✅     Linked: #{file} ~> #{link_target}"
            end
        end
    end

    def remove_link(dry_run)
        @files.each do |file|
            link_target = File.join(@target_path, File.basename(file))
            backup_path = "#{link_target}.bak"

            # First check if the target is a symlink and points to the file
            if File.symlink?(link_target)
                actual_link = File.readlink(link_target)
                unless actual_link == file
                    puts "⚠️     Not unlinking: #{link_target} (not a link to this repo)"
                    next
                end
            elsif File.exists?(link_target)
                puts "❌     #{link_target} (not a symlink)"
                next 
            else 
                puts "⚪     #{file} (not linked)"
                next
            end

            # Remove symlink
            if dry_run
                puts "🗑️     Would unlink: #{link_target}"
            else
                File.delete(link_target)
                puts "🗑️     Unlinked: #{link_target}"
            end

            # Restore backup
            next unless File.exist?(backup_path)

            if dry_run
                puts "🔁     Would restore backup: #{backup_path} ~> #{link_target}"
            else
                File.rename(backup_path, @link_target)
                puts "🔁     Restored backup: #{File.basename(file)}.bak ~> #{link_target}"
            end
        end
    end

    # === HELPER FUNCTIONS === #
    
    def target_path?
        return !@target_path.nil?
    end
end



=begin

    def create_link(dry_run)
        @files.each do |file|
            link_target = File.join(@target_path, File.basename(file))
            backup_path = "#{link_target}.bak"
            
            # Check if there is an existing symbolic link 
            if File.symlink?(link_target)
                actual_link = File.readlink(link_target)
                if actual_link == file || @conflict == "skip"
                    # Already symlinked to this, or it's a different one and we're skipping
                    next
                end
                # If here it means we overwrite. Need to delete the old one first
                File.delete(link_target)
            end

            if @ignore_empty && (File.empty?(file) || Dir.empty?(file))
                puts "⚠️     Skipping: #{File.basename(file)} is empty"
                next
            end

            # Create backup
            unless File.exist?(backup_path)
                if dry_run
                    puts "🔁     Would make backup: #{link_target} ~> #{backup_path}"
                else
                    File.rename(@link_target, backup_path)
                    puts "🔁     Moved existing file to: #{backup_path}"
                end
            end
        end
    end

class LinkEntry
    attr_reader :name, :paths, :ignore?, :ignore_empty?, :conflict, :create_path?

    def initialize(key, yaml_data)
        @name = key        
        @paths = yaml_data[:paths]
        @ignore? = yaml_data[:ignore]
        @ignore_empty? = yaml_data[:ignore_empty]
        @conflict = yaml_data[:conflict]
        @create_path?= yaml_data[:create_path]
    end

    
end
=end

=begin
class LinkTarget
    attr_reader :name, :rel_path, :abs_path, :link_target, :child

    def initialize(target_dir, child)
        @child = child 
        @name = File.join(File.basename(target_dir), child)
        @rel_path = File.join(target_dir, child)
        @abs_path = File.realpath(@rel_path)
        @link_target = File.join(Dir.home, child)
    end

    def directory?
        return File.directory?(@abs_path)
    end

    def zero?
        return File.zero?(@abs_path)
    end

    def starts_with_dot?
        return @child[0,1] == "."
    end

    def link_target_exists?
        File.file?(@link_target)
    end

    def backup_path
        return "#{@link_target}.bak"
    end

    def backup_exists?
        return File.file?(backup_path)
    end

    def symlink?
        File.symlink?(@link_target)
    end

    def points_here?
        return false unless symlink?
        File.readlink(@link_target) == @abs_path
    end

    def create_backup(dry_run = false)
        return unless link_target_exists?

        if dry_run
            puts "🔁     Would make backup: #{@link_target} ~> #{backup_path}"
        else
            File.rename(@link_target, backup_path)
            puts "🔁     Moved existing file to: #{backup_path}"
        end
    end

    def restore_backup(dry_run = false)
        return unless backup_exists?

        if dry_run
            puts "🔁     Would restore backup: #{backup_path} ~> #{@link_target}"
        else
            File.rename(backup_path, @link_target)
            puts "🔁     Restored backup: #{backup_path}.bak ~> #{@link_target}"
        end
    end

    def create_symlink(dry_run = false)
        if dry_run
            puts "📝     Would link: #{@name} ~> #{@link_target}"
        else
            File.symlink(@abs_path, @link_target)
            puts "✅     Linked: #{@abs_path} → #{@link_target}"
        end
    end

    def remove_symlink(dry_run = false)
        if dry_run
            puts "🗑️     Would unlink: #{@link_target}"
        else
            File.delete(@link_target)
            puts "🗑️     Unlinked: #{@link_target}"
        end
    end

    def readlink
        return File.readlink(@link_target) if symlink?
    end
end
=end