$root = File.join(File.dirname(__FILE__), '..')
$:.unshift File.join($root, 'lib')
require 'test/unit'
require 'vfs'
require 'vfs/dav'
class TestModule < Test::Unit::TestCase
  def test_module
    t = Class.new() do 
      include VFS::FilePathDAV
    end
  end 
end