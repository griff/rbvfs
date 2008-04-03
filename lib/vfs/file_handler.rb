# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

module VFS
  # Container module for classes implementing a filesystem based on the physical filesystem.
  # All the classes in this module are basicly wrappers that map the API of VFS into the file handeling
  # APIs made available by Ruby.
  #
  # Two kinds of file nodes exists; Node and Root. These share some common code implemented in the common
  # parent BaseNode. Root is the base of a file resolve and can be used as an argument to both a new 
  # VFS::FileSystem or to VFS::FileSystem.mount. Node are on the other hand child nodes with a Root object
  # further up the parent path.
  module FileHandlerModule
    def file?() ::FileTest.file?( fs_filepath ) end
    def exists?() ::FileTest.exists?( fs_filepath ) end
    def directory?() ::FileTest.directory?( fs_filepath ) end

    def entries
      if ::FileTest.directory?(fs_filepath)
        ::Dir.entries( fs_filepath ).delete_if {|i| i=='..' || i=='.'}
      else
        []
      end
    end

    def mkdir
      ::Dir.mkdir( fs_filepath )
    end

    def blksize
      ::File.blksize( fs_filepath )
    end

    def delete
      if file?
        ::File.unlink( fs_filepath )
      elsif directory?
        ::Dir.rmdir( fs_filepath )
      end
    end

    def open( mode="r", &block )
      if block_given?
        ::File.open( fs_filepath, mode, &block )
      else
        ::File.new( fs_filepath, mode )
      end
    end
  end
end