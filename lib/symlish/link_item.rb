require_relative "utils"

class LinkItem
    attr_accessor :source, :target, :backup

    def initialize(source_path, target_path)
        @source = source_path
        @target = target_path
        @backup = "#{@target}.bak"
    end

    # <!--
    #   - LinkItem.here? -> true or false
    # -->
    # Returns `true` if @target is a symbolic link that points to @source, `false` otherwise.
    #
    def here?
        return File.symlink?(@target) && File.readlink(@target) == @source
    end

    # <!--
    #   - LinkItem.backup? -> true or false
    # -->
    # Returns `true` if file named `"#{@target}.bak"` exists in the target directory, `false` otherwise.
    #
    def backup?
        return File.file?(@backup)
    end

    # <!--
    #   - LinkItem.create_backup -> 0
    # -->
    # Create a backup by renaming `@target` to `"#{@target}.bak"`.
    # Early exit if either target does not exist _or_ the backup exists.
    #
    def create_backup
        return unless existing?(@target) && !backup?

        File.rename(@target, @backup)
    end

    # <!--
    #   - LinkItem.restore_backup -> 0
    # -->
    # Restore the backup by renaming `"#{@target}.bak"` to `@target`.
    # Early exit if either target exists _or_ the backup does not exist.
    # 
    def restore_backup
        return if existing?(@target) || !backup?
    end

    # <!--
    #   - LinkItem.symlink? -> true or false
    # -->
    # Returns `true` if `@target` points to a symbolic link, `false` otherwise.
    # 
    def symlink?
        return File.symlink?(@target)
    end
    
    # <!--
    #   - LinkItem.symlink -> file_name
    # -->
    # Returns the name of the file referenced by the given link.
    # 
    def symlink
        return File.readlink(@target)
    end

    # <!--
    #   - LinkItem.create_symlink -> 0
    # -->
    # Creates a symbolic link on @target for the existing file @source.
    # Early exit if @target exists as a file or symbolic link
    def create_symlink
        return if existing?(@target) || File.symlink?(@target) || here?
        File.symlink(@source, @target)
    end

    # <!--
    #   - LinkItem.remove_symlink -> 0
    # -->
    # Removes the symbolic link for @target.
    # Early exit if @target is not a symbolic link or it does not point to @source.
    # 
    def remove_symlink
        return unless symlink? && here?
        File.delete(@target)
    end

=begin
    # Backup

    def backup?
        return File.file?(@backup)
    end

    def create_backup(dry_run)
        return unless File.file?(@target) && !backup?

        if dry_run
            puts "🔁     Would make backup: #{@backup}"
        else
            File.rename(@target, @backup)
            puts "🔁     Moved existing file to: #{@backup}"
        end
    end

    def restore_backup(dry_run)
        return unless backup?
        
        if dry_run
            puts "🔁     Would restore backup: #{@backup} ~> #{@target}"
        else
            File.rename(@backup, @target)
            puts "🔁     Restored backup: #{@backup} ~> #{@target}"
        end
    end

    # Symlink
    
    def symlink?
        return File.symlink?(@target)
    end

    def create_symlink(dry_run)
       if dry_run
            puts "📝     Would link: #{@source} ~> #{@target}"
       else
            File.symlink(@source, @target)
            puts "🔗     Linked: #{@source} ~> #{@target}"
       end
    end

    def remove_symlink(dry_run)
        return unless symlink? && here?

        if dry_run
            puts "🗑️     Would unlink: #{item.self}"
        else
            File.delete(@target)
            puts "🗑️     Unlinked: #{item.self}"
        end
    end

    # Util functions
    
    def ignore_empty?(ignore_empty)
        if ignore_empty && empty?(@source)
            puts "⚠️     Skipping #{@source}: Source #{item_type(@source)} is empty"
            return true
        end
        return false
    end

    def conflict?(conflict)
        return false unless symlink?
        return true if here?
        
        if conflict == "skip"
            puts "⚠️     Skipping #{@source}: Conflict with another symbolic link"
            return true
        end

        return false
    end

    def here?
        return File.readlink(@target) == @source
    end
=end

=begin
    # Return absolute path to this file/directory
    def self
        return @source
    end
 
    # Return absolute path to the target file/directory
    def target
        return @target
    end

    def exists?
        return File.file?(@target) && !File.symlink?(@target)
    end

    # Get path to backup
    def backup
        return "#{@target}.bak"
    end

    # Check if backup exists
    def backup?
        return File.file?(backup)
    end
    
    # Create backup
    def make_backup
        return unless exists?

        File.rename(@target, backup)
    end

    # Restore the backup
    def restore_backup
        return unless backup?

        File.rename(backup, @target)
    end

    # Check if symbolic link exists
    def symlink?
        return File.symlink?(@target)
    end

    # Check if the symbolic link points to this file
    def here?
        return File.readlink(@target) == @source
    end

    # Create the symbolic link
    def make_link
        File.symlink(@source, @target)
    end

    # Remove the symbolic link
    def delete_link
        return unless symlink? && here?

        File.delete(@target)
    end
=end
end