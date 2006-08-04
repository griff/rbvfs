$root = File.join(File.dirname(__FILE__), '..')
$:.unshift File.join($root, 'lib')
require 'test/unit'
require 'vfs'
class TestVFS < Test::Unit::TestCase
    def test_root
        fs = VFS::FileSystem.new( VFS::File::Root.new( File.join( $root, 'tmp' ) ) )
        rootfo = fs.lookup( '/' )
        assert_equal( rootfo, '/' )
        assert_equal( '/', rootfo )
        assert_equal( rootfo, fs.lookup( '' ) )
        assert_equal( fs.lookup( '/test' ), fs.lookup( 'test', rootfo ) )
    end
end
# vim: sts=4:sw=4:ts=4:et