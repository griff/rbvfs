# Author:: Brian Olsen (mailto:griff@rubyforge.org)
# Copyright:: Copyright (c) 2007, Brian Olsen
# Documentation:: Author and Christian Theil Have
# License::   rbvfs is free software distributed under a BSD style license.
#             See LICENSE[file:../License.txt] for permissions.

$root = File.join(File.dirname(__FILE__), '..')
$:.unshift File.join($root, 'lib')

require 'test/unit'
require 'vfs'
require 'vfs/file_path_dav'
require 'vfs/simple_dav_lock'
require 'pp'

class TestVFS < Test::Unit::TestCase
  def test_simple_fs_meta
    fs = VFS::FileSystem.instance
    fs.root = VFS::File.new( File.join( $root, 'tmp' ) )
    
    fs.define_namespace(:dav, :'DAV:') do
      def hello
        "test"
      end
      property :hello
    end
    
    assert_equal [[:dav,:'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal [[:'DAV:', :hello]].to_set, fs.lookup('/files').meta.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.dav.properties
    assert_equal "test", fs.lookup('/files').meta.dav.hello
    pp fs.lookup('/files').meta.mount_meta.class.name
  end
  
  def test_fs_meta
    fs = VFS::FileSystem.instance
    fs.root = VFS::File.new( File.join( $root, 'tmp' ) )
    
    fs.property_namespace(:dav, :'DAV:') do
      def hello
        "test"
      end
      property :hello
    end
    fs.property_namespace(:tav, :'TAV:') do
      def hello
        "test2"
      end
      property :hello
    end
    
    assert_equal [[:tav,:'TAV:'],[:dav,:'DAV:']].to_set, fs.lookup('/files').properties.namespaces
    assert_equal [[:'TAV:', :hello], [:'DAV:', :hello]].to_set, fs.lookup('/files').properties.properties
    assert_equal [:hello].to_set, fs.lookup('/files').properties.dav.properties
    assert_equal [:hello].to_set, fs.lookup('/files').properties.tav.properties
    assert_equal "test", fs.lookup('/files').properties.dav.hello
    assert_equal "test2", fs.lookup('/files').properties.tav.hello
  end
  
  def test_fs_include_meta
    fs = VFS::FileSystem.instance
    fs.root = VFS::File.new( File.join( $root, 'tmp' ) )
    
    fs.property_namespace(:dav, :'DAV:', :extend=>VFS::FilePathDAV)
    
    p = %w( lastaccessed creationdate getlastmodified getcontentlength getetag getcontenttype resourcetype )
    t = fs.lookup('/files').properties.dav.properties.to_set
    
    assert_equal [[:dav,:'DAV:']].to_set, fs.lookup('/files').properties.namespaces
    assert_equal p.map{|e| [:'DAV:', e.to_sym]}.to_set,fs.lookup('/files').properties.properties
    assert_equal p.map{|e| e.to_sym}.to_set, fs.lookup('/files').properties.dav.properties
  end

  def test_simple_root_meta
    fs = VFS::FileSystem.instance
    fs.connect('/', VFS::File.new( File.join( $root, 'tmp' ) ) ) do |m|
      m.property_namespace(:dav, :'DAV:') do
        def hello
          "test"
        end
        property :hello
      end
    end
    
    assert_equal [[:dav,:'DAV:']].to_set, fs.lookup('/files').properties.namespaces
    assert_equal [[:'DAV:', :hello]].to_set, fs.lookup('/files').properties.properties
    assert_equal [:hello].to_set, fs.lookup('/files').properties.dav.properties
    assert_equal "test", fs.lookup('/files').properties.dav.hello
  end
  
  def test_root_meta
    fs = VFS::FileSystem.instance
    fs.connect('/', VFS::File.new( File.join( $root, 'tmp' ) ) ) do |m|
      m.define_namespace(:dav, :'DAV:', :extend=>VFS::FilePathDAV) do
        def hello
          "test"
        end
        property :hello
      end
      m.define_namespace(:tav, :'TAV:') do
        def hello
          "test2"
        end
        property :hello
      end
    end
    
    assert_equal [[:tav, :'TAV:'],[:dav, :'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal [[:'TAV:', :hello], [:'DAV:', :hello]].to_set, fs.lookup('/files').meta.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.dav.properties
    assert_equal [:hello].to_set, fs.lookup('/files').meta.tav.properties
    assert_equal "test", fs.lookup('/files').meta.dav.hello
    assert_equal "test2", fs.lookup('/files').meta.tav.hello
  end
  
  def test_root_include_meta
    fs = VFS::FileSystem.instance
    fs.connect('/', VFS::File.new( File.join( $root, 'tmp' ) ) ) do |m|
      m.define_namespace(:dav, :'DAV:', :extend=>VFS::FilePathDAV)
    end
    
    p = %w( lastaccessed creationdate getlastmodified getcontentlength getetag getcontenttype resourcetype )
    assert_equal [[:dav,:'DAV:']].to_set, fs.lookup('/files').meta.namespaces
    assert_equal p.map{|e| [:'DAV:', e.to_sym]}.to_set,fs.lookup('/files').meta.properties
    assert_equal p.map{|e| e.to_sym}.to_set, fs.lookup('/files').meta.dav.properties
  end
  
  def test_tt
    fs = VFS::FileSystem.instance
    fs.connect('/', VFS::File.new(File.join($root, 'tmp' ) ) ) do |root|
      root.define_namespace(:dav, :'DAV:', :extend=>VFS::FilePathDAV)
    end
    fs.define_namespace(:dav, :'DAV:', :extend=>VFS::SimpleDAVLock)
    
    
    #fs.lookup('/files/tmp').meta.namespace => ????
    #fs.lookup('/tmp').meta.dav.properties => ????
    #fs.lookup('/files/tmp').meta.dav.properties => ????
    
    fs = VFS::FileSystem.instance
    fs.root = VFS::File.new(File.join($root, 'tmp' ) )
    fs.define_namespace(:dav, :'DAV:', :extend=>VFS::FilePathDAV)
    fs = VFS::FileSystem.instance
    fs.root = VFS::File.new(File.join($root, 'tmp' ) )
    fs.connect('/files', VFS::File.new(File.join($root, 'tmp'))) do |n|
      n.restrict :create_dir, :delete_file
    end
#            map.connect '/tags', VFS::Tagging::TagFile.new
      
#            map.dynamic_namespaces = VFS::Tagging::Tags.new
    fs.define_namespace(:dav, :'DAV:', :extend=>[VFS::FilePathDAV,  VFS::SimpleDAVLock])
  end
end
# vim: sts=4:sw=4:ts=4:et