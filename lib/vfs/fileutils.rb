module VFS
    class BaseNode
        def cp( dest )
        end
        
        def cp_r( dest )
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
          if src.is_a?(Array)
            src.each do |s|
                if s.respond_to? :name && s.respond_to? :path
                    basename = s.name
                    s = s.path
                else
                    s = s.to_str
                    basename = File.basename(s)
                end
                  
              yield s, dest + basename
            end
          else
            src = src.to_str
            if File.directory?(dest)
              yield src, File.join(dest, File.basename(src))
            else
              yield src, dest.to_str
            end
          end
        end
    end
end