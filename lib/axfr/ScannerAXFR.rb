require 'net/dns'

class ScannerAXFR
  def initialize(target_list, threads=5)
    return nil if target_list.nil?
    @target_list = target_list

    @threads = threads
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
            result.push(answer.name.chomp('.'))
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
          puts "[Resolver] Target: #{target} Resolved: #{results.size}"
          # TODO: событие ONE_TARGET_FINISH axfr

          found_domains[target] = results
        end

      end
    end

    threads_list.each {|thr| thr.join }
    found_domains
  end

end

if $0 == __FILE__
  puts '[INFO] Start AXFR resolver ... [ OK ]'
  brt = ScannerAXFR.new(
      target_list = ['merron.ru', 'mr-ozio.ru'],
      threads=1,
  )
  puts '[INFO] Finish AXFR resolver ... [ OK ]'

  p brt.run
end