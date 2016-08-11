require 'net/dns'

class ScannerAXFR
  def initialize(target_list, threads = 5)
    return nil if target_list.nil?
    @target_list = target_list

    return nil if threads <= 0
    @threads = threads

    @callbacks = {
        :FOUND => self.method(:defaultCallback_FOUND),
        :ON_TARGET_FINISH => self.method(:defaultCallback_ON_TARGET_FINISH),
    }
  end

  def resolverGetInfo(target, resolver = Net::DNS::Resolver.new)
    result = []

    resolver.query(target, Net::DNS::NS).each_nameserver do |ns|
      begin
        netDNS = Net::DNS::Resolver.new(:nameservers => IPSocket.getaddress(ns))
      rescue
        next
      end

      netDNS.log_level = Net::DNS::FATAL

      begin
        netDNS.axfr(target).answer.each do |answer|
          if answer.respond_to?('type') and answer.type == 'A'
            subdomain = answer.name.chomp('.')
            result.push(subdomain)
            @callbacks[:FOUND].call(target, subdomain)
          end
        end
      rescue
        next
      end

    end

    result
  end

  def run
    found_domains = {}

    threads_list = []
    @threads.times do
      threads_list << Thread.new do

        while @target_list.size > 0
          target = @target_list.pop

          begin
            results = resolverGetInfo(target)
          rescue
            results = []
          end

          results.delete(target)
          @callbacks[:ON_TARGET_FINISH].call(target, results)

          found_domains[target] = results
        end

      end
    end

    threads_list.each {|thr| thr.join }
    found_domains
  end

  def run_without_threads
    found_domains = {}

    while @target_list.size > 0
      target = @target_list.pop

      begin
        results = resolverGetInfo(target)
      rescue
        results = []
      end

      results.delete(target)
      @callbacks[:ON_TARGET_FINISH].call(target, results)

      found_domains[target] = results
    end

    found_domains
  end

  def defaultCallback_ON_TARGET_FINISH(target, results)
    puts "[Results] Target: #{target} Resolved: #{results.size}"
  end

  def defaultCallback_FOUND(target, subdomain)
    puts "[FOUND] #{subdomain}"
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

if $0 == __FILE__
  brt = ScannerAXFR.new(
      target_list = ['merron.ru', 'mr-ozio.ru', 'text.ru', 'nn.ru'],
      threads=1,
  )

  p brt.run
end