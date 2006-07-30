#
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

#
# == VFS
#
# Extendable Virtual File System
# 
module VFS
    
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
    
    # Voodoo
    class OverlayFileObject
        attr_reader :proxy, :parent, :name
        #delegate :class, :to => :context
        #delegate :is_a?, :to => :context
        
        def initialize( fs, proxy, name=nil, parent=nil )
            @fs = fs
            @proxy = proxy
            @name = VFS.to_path(name).dup if name
            @parent = parent
        end

        def path( end_slash=false )
            if @name
                parentpath + @name + (end_slash ? '/' : '')
            else
                parentpath
            end
        end
        alias :to_str :path
        alias :to_s :path
        
        def ==( other )
            #other = other.to_str if other.respond_to? :str
            self.path == other
        end

        def parentpath
            if @parent
                loc_path = @parent.path
                loc_path += '/' unless /\/$/ =~ loc_path
                loc_path
            else
                '/'
            end
        end
        
        def exist?
            !@fs.overlayset( self.path ).empty? || @proxy.exist?
        end
        
        def entries
            overlays = @fs.overlayset( self.path )
            overlays.merge( @proxy.entries )
            overlays.to_a
        end
        
        def resolve( name )
            mountpath = self.path(true) + name
            if @fs.mount?( mountpath )
                wrap( @fs.mount( mountpath ), name, self )
            else
                wrap( @proxy.resolve( name ), name, self )
            end
        end
            
        def wrap( proxy, name, parent )
            OverlayFileObject.new( @fs, proxy, name, parent ) unless proxy.nil?
        end
        
        def method_missing( method, *args, &block )
            puts "Ruby is doing magic"
            @proxy.send( method, *args, &block )
        end
        private :method_missing
    end
    
    #
    # FileSystem's primary purpose is to maintain the @mounts table
    # @entries contains the list of all paths and parent paths
    # mount and unmount does what you think they do ..
    class FileSystem
        def initialize( rootfile )
            @mounts = {'/' => OverlayFileObject.new( self, rootfile )}
            @overlays = {} # path => set
        end
      
        # mount also adds all parent paths to @entries
        def mount( path, rootfile=nil )
            path = VFS.cleanpath(path)
            if @rootfile.nil?
                return @mounts[path]
            end
            @mounts[path] = OverlayFileObject.new( self, rootfile )
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
    
    # Objects of this class corresponds to an entry in the physical fs.
    # Same with derivatives.
    class FSBaseFileObject
        def resolve( name )
            FSFileObject.new( name, self )
        end
    end

    class FSFileObject < FSBaseFileObject
        def initialize( name, fs_parent )
            @name = name
            @fs_parent = fs_parent
        end

        def fs_filepath
            (@fs_parent ? @fs_parent.fs_filepath : "" ) + File::SEPARATOR + @name
        end
    end
    
    class FSFileRoot < FSBaseFileObject
        def initialize( rootpath )
            @rootpath = VFS.to_path( rootpath )
            self.taint if @rootpath.tainted?
        end
       
        def fs_filepath
            @rootpath
        end
    end

    # Also a physical fs object
    class FSFileObjectMeta
        def initialize( fileObject )
            @file = fileObject
        end

        def atime
            File.atime( @file.fs_filepath )
        end

        def ctime
            File.ctime( @file.fs_filepath )
        end

        def mtime
            File.mtime( @file.fs_filepath )
        end

        def size
            File.size( @file.fs_filepath )
        end

        def size?
            File.size?( @file.fs_filepath )
        end

        def zero?
            File.zero?( @file.fs_filepath )
        end
    end
end

module VFS
    class FSBaseFileObject # * FileTest *
        # See <tt>FileTest.executable?</tt>.
        def executable?() FileTest.executable?( fs_filepath ) end

        # See <tt>FileTest.executable_real?</tt>.
        def executable_real?() FileTest.executable_real?( fs_filepath ) end

        # See <tt>FileTest.exist?</tt>.
        def exist?() FileTest.exist?( fs_filepath ) end

        # See <tt>FileTest.grpowned?</tt>.
        def grpowned?() FileTest.grpowned?( fs_filepath ) end

        # See <tt>FileTest.directory?</tt>.
        def directory?() FileTest.directory?( fs_filepath ) end

        # See <tt>FileTest.file?</tt>.
        def file?() FileTest.file?( fs_filepath ) end

        # See <tt>FileTest.pipe?</tt>.
        def pipe?() FileTest.pipe?( fs_filepath ) end

        # See <tt>FileTest.socket?</tt>.
        def socket?() FileTest.socket?( fs_filepath ) end

        # See <tt>FileTest.owned?</tt>.
        def owned?() FileTest.owned?( fs_filepath ) end

        # See <tt>FileTest.readable?</tt>.
        def readable?() FileTest.readable?( fs_filepath ) end

        # See <tt>FileTest.readable_real?</tt>.
        def readable_real?() FileTest.readable_real?( fs_filepath ) end

        # See <tt>FileTest.setuid?</tt>.
        def setuid?() FileTest.setuid?( fs_filepath ) end

        # See <tt>FileTest.setgid?</tt>.
        def setgid?() FileTest.setgid?( fs_filepath ) end

        # See <tt>FileTest.size</tt>.
        def size() FileTest.size( fs_filepath ) end

        # See <tt>FileTest.size?</tt>.
        def size?() FileTest.size?( fs_filepath ) end

        # See <tt>FileTest.sticky?</tt>.
        def sticky?() FileTest.sticky?( fs_filepath ) end

        # See <tt>FileTest.symlink?</tt>.
        def symlink?() FileTest.symlink?( fs_filepath ) end

        # See <tt>FileTest.writable?</tt>.
        def writable?() FileTest.writable?( fs_filepath ) end

        # See <tt>FileTest.writable_real?</tt>.
        def writable_real?() FileTest.writable_real?( fs_filepath ) end

        # See <tt>FileTest.zero?</tt>.
        def zero?() FileTest.zero?( fs_filepath ) end
    end
end

module VFS
    class FSBaseFileObject    # * Dir *
        # Return the entries (files and subdirectories) in the directory, each as a
        # String. See <tt>Dir.entries</tt>. With the difference that if the referenced 
        # path doesn't exist or isn't a directory this method will simple return ['.', '..']
        def entries() File.directory? ? Dir.entries( fs_filepath ) : ['.', '..'] end

        # Iterates over the entries (files and subdirectories) in the directory.  It
        # yields a Pathname object for each entry.
        def each_entry( &block )  # :yield: p
            entries.each( &block )
        end

        # See <tt>Dir.mkdir</tt>.  Create the referenced directory.
        def mkdir(*args) Dir.mkdir( fs_filepath, *args) end

        # See <tt>Dir.rmdir</tt>.  Remove the referenced directory.
        def rmdir() Dir.rmdir( fs_filepath ) end
    end
end

module VFS
    class FSBaseFileObject    # * Find *
        #
        # Pathname#find is an iterator to traverse a directory tree in a depth first
        # manner.  It yields a Pathname for each file under "this" directory.
        #
        # Since it is implemented by <tt>find.rb</tt>, <tt>Find.prune</tt> can be used
        # to control the traverse.
        #
        # If +self+ is <tt>.</tt>, yielded pathnames begin with a filename in the
        # current directory, not <tt>./</tt>.
        #
        def find(&block) # :yield: p
            require 'find'
            Find.find( fs_filepath, &block ) }
        end
    end
end

module VFS
    class FSBaseFileObject    # * FileUtils *
        # See <tt>FileUtils.mkpath</tt>.  Creates a full path, including any
        # intermediate directories that don't yet exist.
        def mkpath
          require 'fileutils'
          FileUtils.mkpath( fs_filepath )
          nil
        end

        # See <tt>FileUtils.rm_r</tt>.  Deletes a directory and all beneath it.
        def rmtree
          # The name "rmtree" is borrowed from File::Path of Perl.
          # File::Path provides "mkpath" and "rmtree".
          require 'fileutils'
          FileUtils.rm_r( fs_filepath )
          nil
        end
    end
end

module VFS
    class FSBaseFileObject    # * mixed *
        # Removes a file or directory, using <tt>File.unlink</tt> or
        # <tt>Dir.unlink</tt> as necessary.
        def unlink()
            begin
                Dir.unlink @path
            rescue Errno::ENOTDIR
                File.unlink @path
            end
        end
        alias delete unlink
    end
end

if $0 == __FILE__
    def test( names )
    #    return absolute ? '/' : '.' if names.empty?
        path = '/'
        path << names.join('/')
    end

    module TestI
      include VFS
    end

    t = TestI::FileSystem.new( VFS::FSFileRoot.new("/tmp"))
    #TestI.new
    #t = VFS::FileSystem.new( VFS::FSFileRoot.new("/Users/griff/Pictures"))
    t.mount( '/test/molla', VFS::FSFileRoot.new('/Users/griff/Music') )
    t.mount( '/molla/ff', VFS::FSFileRoot.new('/Users/griff/Music') )
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
