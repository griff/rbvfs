$root = File.join(File.dirname(__FILE__), '..')
$:.unshift File.join($root, 'lib')
require 'test/unit'
require 'vfs'
require 'vfs/file_path_dav'
require 'vfs/simple_dav_lock'
require 'pp'

class TestVFS < Test::Unit::TestCase
    def test_meta
        fs = VFS::FileSystem.new do |map|
            map.connect('/', VFS::File.new(File.join($root, 'tmp' ) ) ) do |root|
                root.define_namespace(:dav, :'DAV:') do
                    include VFS::FilePathDAV
                    include VFS::SimpleDAVLock
                end
                puts "Hello"
                pp root.meta.namespaces
                pp root.meta.prefix_defined?(:dav)
                pp root.meta.dav.properties
                puts "Your fool"
            end
        end
        fs = VFS::FileSystem.new do |map|
            map.root = VFS::File.new(File.join($root, 'tmp' ) )
            map.define_namespace(:dav, :'DAV:') do
                include VFS::FilePathDAV
            end
        end
        fs = VFS::FileSystem.new do |map|
            map.root = VFS::File.new(File.join($root, 'tmp' ) )
            map.connect('/files', VFS::File.new(File.join($root, 'tmp'))) do |n|
                n.restrict :create_dir, :delete_file
            end
#            map.connect '/tags', VFS::Tagging::TagFile.new
            
#            map.dynamic_namespaces = VFS::Tagging::Tags.new
            map.define_namespace(:dav, :'DAV:') do
                include VFS::FilePathDAV
                include VFS::SimpleDAVLock
            end
        end
    end
end
# vim: sts=4:sw=4:ts=4:et