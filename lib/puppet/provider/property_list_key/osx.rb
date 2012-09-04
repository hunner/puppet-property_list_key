require 'facter/util/plist'
require 'pp'

Puppet::Type.type(:property_list_key).provide(:osx) do
  desc "An OS X provider for creating property list keys and values"

  mk_resource_methods
  commands :plutil => 'plutil'

  def exists?
    return false unless File.file? @resource[:domain]
    if @resource[:domain].nil? or @resource[:key].nil?
      fail("The 'key' and 'domain' parameters are required for the property_list_key type")
    end

    plist_hash = open_plist_file(@resource[:domain])
    plist_hash.keys.include? @resource[:key]
  end

  def create
    if File.file? @resource[:domain]
      plist_hash = open_plist_file(@resource[:domain])
    else
      plist_hash = Hash.new
    end

    value_type = @resource[:value_type].downcase || 'string'

    case value_type
    when 'integer'
      plist_value = Integer(@resource[:value].first)
    when 'array'
      plist_value = Array(@resource[:value])
    else
      plist_value = @resource[:value].first
    end

    plist_hash[@resource[:key]] = plist_value

    write_plist_file(plist_hash, @resource[:domain])
  end

  def destroy
    if File.file?(@resource[:domain])
      plist_hash = open_plist_file(@resource[:domain])
    else
      return true
    end

    plist_hash.delete(@resource[:key])

    write_plist_file(plist_hash, @resource[:domain])
  end

  def value
    open_plist_file(@resource[:domain])[@resource[:key]]
  end

  def value=(item_value)
    plist_hash = open_plist_file(@resource[:domain])

    # EVERY value out of the resource becomes an array, so take the first value
    case @resource[:value_type].downcase
    when 'integer'
      plist_hash[@resource[:key]] = Integer(item_value.first)
    else
      plist_hash[@resource[:key]] = item_value.first
    end

    write_plist_file(plist_hash, @resource[:domain])
  end

  def open_plist_file(file_path)
    retries = 1
    begin
      plist_hash = Plist.parse_xml(read_file_contents(file_path))
    rescue => e
      if retries > 0
        plutil '-convert', 'xml1', file_path
        retries -= 1
        retry
      else
        fail("Unable to open the file #{file_path}.  #{e.class}: #{e.inspect}")
      end
    end

    plist_hash
  end

  def read_file_contents(file_path)
    File.open(@resource[:domain], 'r') do |f|
      @contents = f.read
    end
  end

  def write_plist_file(plist_hash, file_path)
    Plist::Emit.save_plist(plist_hash, file_path)
  end
end

