module VFS
  class FileSystem
    class FileNode
      class FileMeta
        attr_reader :owner
        
        def initialize(file_owner)
          @owner = file_owner
        end
        
        def namespaces
          owner.real_mounts.collect{|m| m.meta.namespaces}.flatten.to_set.to_a
        end
        
        def prefix_get(sym)
          
        end
        
        def prefix_defined?(sym)
          
        end
        
        def namespace_get(ns)
          
        end
        
        def namespace_defined?(ns)
          
        end
        
        def open
          if block_given?
            begin
            ensure
              self.close
            end
          end
        end
        
        def close
        end
        
        def []( ns )
            namespace_get( ns )
        end
        
        def method_missing(name)
          
        end
      end
      
      include Enumerable
      attr_reader :parent, :fs, :name
      
      def initialize(fs, parent=nil, name=nil)
        @fs = fs
        @parent = parent
        @name = name
        @restrictions = [].to_set
      end
      
      def inherited_restrictions
        self.mounts.map{|m| m.restrictions}.flatten.to_set
      end
      
      def restrictions
        @restrictions.to_a.to_set
      end
      
      def delegates
        d = @fs.mounts(self.path)
        d.sort!{|a,b| a.sort_key <=> b.sort_key}
        d.map!{|d2| d2.delegate}
        d.compact!
        d
      end
      
      def mounts
        d = @fs.mounts(self.path)
        d.sort!{|a,b| a.sort_key <=> b.sort_key}
        d
      end
      
      def real_mounts
        d = @fs.real_mounts(self.path)
        d.sort!{|a,b| a.sort_key <=> b.sort_key}
        d
      end
      
      def path( trail_slash=false )
        if @parent
          parentpath = @parent.path
          parentpath += '/' unless %r{/$} =~ parentpath
        else
          parentpath = '/'
        end
        if @name
          parentpath + @name + (trail_slash ? '/' : '')
        else
          parentpath
        end
      end
      alias :to_str :path
      alias :to_s :path

      def +(other)
        other = other.to_str if other.respond_to? :to_str
        @fs.lookup( self.path(true) + other )
      end
      
      def ==( other )
        #other = other.to_str if other.respond_to? :str
        self.path == other
      end
      alias === ==
      alias eq? == 
      
      def <=>(other)
        self.path.tr('/', "\0") <=> other.to_s.tr('/', "\0")
      end

      def hash # :nodoc:
        self.path.hash
      end
      
      def resolve(name)
        FileNode.new(@fs, self, name)
      end
      
      def each(&block)
        e = []
        self.mounts.each{ |m| e.concat(m.entries) }
        e.to_set.each(&block)
      end
      
      def restrict(*operations)
        @restrictions.merge operations.map{|e| e.to_sym}
        @restrictions.subtract operations.map{|e| "-#{e}".to_sym}
      end
      
      def unrestrict(*operations)
        @restrictions.subtract operations.map{|e| e.to_sym}
        @restrictions.merge operations.map{|e| "-#{e}".to_sym}
      end
      
      def file?
        h = VFS.exists_handler(self.delegates)
        h.file?
      end
      
      def exists?
        self.delegates.inject(false) {|memo, d| memo || d.exists?}
      end
      
      def directory?
        h = VFS.exists_handler(self.delegates)
        h.directory?
      end
      
      def mkdir
        if self.restrictions.member?(:create_dir)
          raise Errno::EACCES
        end
        VFS.handler_call(:mkdir, self.delegates) do
          if self.exists?
            raise Errno::EEXIST
          else
            raise Errno::EACCES
          end
        end
      end
      
      def blksize(default_size=1024)
        ret = VFS.handler_call(:blksize, self.delegates, default_size)
        ret = default_size unless ret > 0;
        ret
      end
      
      def delete
        if self.restrictions.member?(:delete_dir) && self.directory?
          raise Errno::EACCES
        end
        if self.restrictions.member?(:delete_file) && self.file?
          raise Errno::EACCES
        end
          
        VFS.handler_call(:delete, self.delegates) do
          raise Errno::EACCES
        end
      end
      
      def open( mode="r", &block )
        mode = VFS.to_mode(mode)
        if (self.restrictions.member?(:write_file) && (mode & File::WRONLY) == File::WRONLY) ||
           (self.restrictions.member?(:read_file) && (mode & File::RDONLY) == File::RDONLY) ||
           (self.restrictions.member?(:create_file) && (mode & File::CREATE) == File::CREATE)
          raise Errno::EACCES
        end
          
        h = VFS.exists_handler(self.delegates)
        if h
          h.open(mode, &block)
        elsif self.delegates.length > 0
          self.delegates[0].open(mode, &block)
        else
          raise Errno::EACCES
        end
      end
      
      def meta
        @meta |= FileMeta.new(self)
      end
    end
  end
end