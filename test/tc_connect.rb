# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

$root = File.join(File.dirname(__FILE__), '..')
$:.unshift File.join($root, 'lib')
require 'test/unit'
require 'vfs'
require 'pp'
class TestVFS < Test::Unit::TestCase
  def empty_test(fs)
    assert_equal 0, fs.lookup('/').delegates.size
    assert_equal 0, fs.lookup('/test').delegates.size
  end
  
  def root_test(fs, file)
    assert_equal 1, fs.lookup('/').delegates.size
    assert_equal [file], fs.lookup('/').delegates
    assert_equal [], fs.lookup('/').entries

    assert_equal 1, fs.lookup('/hello').delegates.size
    assert_equal [file.resolve('hello')], fs.lookup('/hello').delegates
    assert_equal [], fs.lookup('/hello').entries

    assert_equal 1, fs.lookup('/hello/world').delegates.size
    assert_equal [file.resolve('hello').resolve('world')], fs.lookup('/hello/world').delegates
    assert_equal [], fs.lookup('/hello/world').entries

    assert_equal 1, fs.lookup('/hello/world/war').delegates.size
    assert_equal [file.resolve('hello').resolve('world').resolve('war')], fs.lookup('/hello/world/war').delegates
    assert_equal [], fs.lookup('/hello/world/war').entries

    assert_equal 1, fs.lookup('/test').delegates.size
    assert_equal [file.resolve('test')], fs.lookup('/test').delegates
    assert_equal [], fs.lookup('/test').entries
  end
  
  def test_noroot
    empty_test(VFS::FileSystem.instance)
  end

  # Test of a lookup before a root file handler is assigned
  def test_lateroot
    fs = VFS::FileSystem.instance
    file = VFS::File.new( File.join( $root, 'tmp' ) )
    
    t = fs.lookup('/hello/world/war')
    empty_test(fs)
    fs.root = file
    root_test(fs, file)

    assert_equal 1, t.delegates.size
    assert_equal [file.resolve('hello').resolve('world').resolve('war')], t.delegates
    assert_equal [], t.entries
    
    fs.root = nil
    empty_test(fs)
  end
  
  def test_connect
    fs = VFS::FileSystem.instance
    file = VFS::File.new( File.join( $root, 'tmp' ) )
    t = fs.lookup('/hello/world/war')

    empty_test(fs)
    fs.root = file
    root_test(fs, file)
    fs.connect '/hello/world', file

    assert_equal 1, fs.lookup('/').delegates.size
    assert_equal [file], fs.lookup('/').delegates
    assert_equal ['hello'], fs.lookup('/').entries

    assert_equal 1, fs.lookup('/hello').delegates.size
    assert_equal [file.resolve('hello')], fs.lookup('/hello').delegates
    assert_equal ['world'], fs.lookup('/hello').entries

    assert_equal 2, fs.lookup('/hello/world').delegates.size
    assert_equal [file,file.resolve('hello').resolve('world')], fs.lookup('/hello/world').delegates
    assert_equal [], fs.lookup('/hello/world').entries

    assert_equal 2, fs.lookup('/hello/world/war').delegates.size
    assert_equal [file.resolve('war'),file.resolve('hello').resolve('world').resolve('war')], 
          fs.lookup('/hello/world/war').delegates
    assert_equal [], fs.lookup('/hello/world/war').entries

    assert_equal 1, fs.lookup('/test').delegates.size
    assert_equal [file.resolve('test')], fs.lookup('/test').delegates
    assert_equal [], fs.lookup('/test').entries

    assert_equal 2, t.delegates.size
    assert_equal [file.resolve('war'), file.resolve('hello').resolve('world').resolve('war')], t.delegates
    assert_equal [], t.entries
    
    fs.disconnect('/hello/world')
    root_test(fs, file)
    fs.root = nil
    empty_test(fs)
  end
  
  def test_connect_noroot
    fs = VFS::FileSystem.instance
    file = VFS::File.new( File.join( $root, 'tmp' ) )
    t = fs.lookup('/hello/world/war')
    
    empty_test(fs)
    fs.connect '/hello/world', file
    
    assert_equal 0, fs.lookup('/').delegates.size
    assert_equal ['hello'], fs.lookup('/').entries
    
    assert_equal 0, fs.lookup('/hello').delegates.size
    assert_equal ['world'], fs.lookup('/hello').entries
    
    assert_equal 1, fs.lookup('/hello/world').delegates.size
    assert_equal [file], fs.lookup('/hello/world').delegates
    assert_equal [], fs.lookup('/hello/world').entries

    assert_equal 1, fs.lookup('/hello/world/war').delegates.size
    assert_equal [file.resolve('war')], fs.lookup('/hello/world/war').delegates
    assert_equal [], fs.lookup('/hello/world/war').entries
    
    assert_equal 0, fs.lookup('/test').delegates.size
    assert_equal [], fs.lookup('/test').entries

    assert_equal 1, t.delegates.size
    assert_equal [file.resolve('war')], t.delegates
    assert_equal [], t.entries
    
    fs.disconnect('/hello/world')
    empty_test(fs)
  end
  
  def test_lookup
      fs = VFS::FileSystem.instance
      rootfo = fs.lookup( '/' )
      assert_equal( rootfo, '/' )
      assert_equal( '/', rootfo )
      assert_equal( rootfo, fs.lookup( '' ) )
      assert_equal( fs.lookup( '/test' ), fs.lookup( 'test', rootfo ) )
  end
end