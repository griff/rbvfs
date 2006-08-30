module VFS
    module Utils
        def self.private_module_function(name)   #:nodoc:
          module_function name
          private_class_method name
        end

        def rm_r( list, options = {} )
            list = fu_list(list)
            
            list.each do |path|
                postorder_traverse(path) do |file|
                    begin
                      file.delete
                    rescue
                      raise unless options[:force]
                    end
                end
            end
        end
        
        def rm_rf( list, options={} )
            options = options.dup
            options[:force] = true
            rm_r list, options
        end
        
        def postorder_traverse( file )
            if file.directory?
                file.entries.each do |ent|
                    postorder_traverse(ent) do |e|
                        yield e
                    end
                end
            end
            yield file
        end
        private_module_function :postorder_traverse
        
        def fu_list(arg)   #:nodoc:
          [arg].flatten
        end
        private_module_function :fu_list
        
    class BaseNode
        def cp( dest )
            fu_each_src_dest( dest) do |d|
              copy_file d
            end
        end
        
        def cp_r( dest )
            fu_each_src_dest(src, dest) do |s, d|
              copy_entry s, d, options[:preserve], options[:dereference_root]
            end
        end
        
        def copy_file( dest )
            dest = fs.lookup( dest, self ) unless dest.respond_to? :open
            open( 'rb' ) { |r|
                dest.open( 'wb' ) { |w|
                    blksize = self.blksize
                    while s = src.read(blksize)
                      dest.write s
                    end
                }
            }
        end
        
        def copy( dest )
            case
            when file?
              copy_file dest
            when directory?
              begin
                Dir.mkdir dest
              rescue
                raise unless File.directory?(dest)
              end
          else
            raise "unknown file type: #{path}"
          end
        end
        
        def fu_each_src_dest(dest)   #:nodoc:
            dest = fs.lookup(dest) unless dest.respond_to? :directory?
            if dest.directory
                yield dest + name
            else
                yield dest
            end
          end
        end
    end
end