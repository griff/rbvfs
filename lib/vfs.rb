# = vfs.rb
#
# Object-Oriented Extendable Virtual Filesystem
#
# Author:: Brian Olsen <griff@maven-group.org>
# Documentation:: Author and Christian Theil Have
#
# For documentation, see module VFS.
#
require 'set'
require 'vfs/base'
require 'vfs/file'

#
# == VFS
#
# Extendable Virtual File System
# 
module VFS
    
    def VFS.fs_filepath( parent, name )
        loc_path = parent.fs_filepath
        loc_path += ::File::SEPARATOR unless %r{File::SEPARATOR$} =~ loc_path
        loc_path + name
    end
    
    # Convert a object (path) to a str (if you can ;-)
    def VFS.to_path( path )
        path = path.to_str if path.respond_to? :to_str
        if /\0/ =~ path
          raise ArgumentError, "pathname contains \\0: #{path.inspect}"
        end
        return path
    end
    
    # Starts with / ?
    def VFS.absolute?( path )
        path = VFS.to_path(path)
        %r{\A/} =~ path
    end
    
    # Removes redundant . and resolves .. (pure str magic)
    def VFS.cleanpath( path )
        path = VFS.to_path(path)
        if !VFS.absolute?(path)
            raise ArgumentError, "path is not absolute: #{path.inspect}"
        end
        
        names = []
        path.scan(%r{[^/]+}) {|name|
            next if name == '.'
            if name == '..'
                if !names.empty?
                    names.pop
                end
                next
            end
            names << name
        }
        path = '/'
        path << names.join('/')
    end
    
    #
    # FileSystem's primary purpose is to maintain the @mounts table
    # @entries contains the list of all paths and parent paths
    # mount and unmount does what you think they do ..
    class FileSystem
        def initialize( rootfile )
            rootfile.assignpath( self, nil, nil )
            @mounts = {'/' => rootfile}
            @overlays = {} # path => set
        end
      
        # mount also adds all parent paths to @entries
        def mount( path, rootfile=nil )
            path = VFS.cleanpath(path)
            if @rootfile.nil?
                return @mounts[path]
            end
            rootfile.assignpath( self, path, nil )
            @mounts[path] = rootfile
            names = []
            path.scan(%r{[^/]+}) {|name|
                overlay_path = '/' + names.join('/')
                @overlays[overlay_path] = [].to_set unless @overlays[overlay_path]
                @overlays[overlay_path].add name
                puts "#{entryname} => #{name}"
                names << name
            }
        end

        def mount?( path )
            @mounts.has_key?(path)
        end    
      
        def unmount( path )
            path = path.path if path.respond_to? :path
            path = path.to_str if path.repond_to? :to_str
            entries = @mounts.delete( path )
        end
        
        def overlayset(path)
            path = VFS.cleanpath(path)
            overlay = @overlays[path]
            overlay ? overlay : [].to_set
        end
      
        # Never fails if arguments are valid
        def lookup( path, basepath="/" )
            path = VFS.to_path(path)
            if !VFS.absolute?(path)
                basepath = basepath.path if basepath.respond_to? :path
                basepath = VFS.cleanpath( basepath )
                basepath += "/" unless /\/$/ =~ basepath
                path = basepath + path
            end
            path = VFS.cleanpath( path )
            
            fileobj = @mounts['/']
                
            # tokenize on / and resolve the name.
            # We need to do it this way because a fileobject is resposibly for all of the leafs below it.
            # Only the fileobject knows how to proceed 
            path.scan(%r{[^/]+}) {|name|
                fileobj = fileobj.resolve(name)
            }
            return fileobj
        end
      
    end
end

if $0 == __FILE__
    def test( names )
    #    return absolute ? '/' : '.' if names.empty?
        path = '/'
        path << names.join('/')
    end

    t = VFS::FileSystem.new( VFS::File::Root.new("/tmp"))
    t.mount( '/test/molla', VFS::File::Root.new('/Users/griff/Music') )
    t.mount( '/molla/ff', VFS::File::Root.new('/Users/griff/Music') )
    puts t.overlayset('/')
    puts t.lookup( "").directory?
    puts t.lookup( "").entries
    puts "Next"
    puts t.lookup("/heelo/../../../test")
    puts "Next"
    puts t.lookup( "/heelo/../../../test", "/per/ppf")
    puts t.lookup( "/heelo/../../../test", "/per/ppf/")
    puts t.lookup( "heelo/../../../test", "/per/ppf")
    puts t.lookup( "heelo/../../test", "/per/ppf/")
    puts t.lookup( "/heelo/../../../test", "per/ppf").fs_filepath

    ".././Heet/..\\nkll/Hell/../../../".scan(%r{[^/]+}) { |name|
      puts "File: #{name}"
    }
end

# vim: sts=4:sw=4:ts=4:et
