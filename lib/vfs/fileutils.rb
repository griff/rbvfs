module VFS
    module FileUtils
        def blksize(file, default_size=1024)
            ret = file.blksize if file.respond_to? :blksize
            ret = default_size unless ret && ret > 0;
            ret
        end

        def rm_r( list, options = {} )
            list = [list].flatten
            
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
    end
end