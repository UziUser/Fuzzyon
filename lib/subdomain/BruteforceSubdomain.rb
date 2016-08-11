require 'net/dns'
require 'httpclient'

class BruteforceSubdomain
  def initialize(target_list, dictionary = [], threads = 5, check_web_responses = false, respose_codes = [200])
    return nil if target_list.nil?
    @target_list = target_list

    return nil if dictionary.nil?
    @dictionary = dictionary

    @threads = threads
    return nil if threads <= 0

    if check_web_responses
      @ua = HTTPClient.new
      @checkWebResponses = check_web_responses
      @resposeCodes = respose_codes
    end

    @callbacks = {
        :FOUND => self.method(:defaultCallback_FOUND),
        :NOT_FOUND => self.method(:defaultCallback_NOT_FOUND),
        :ON_TARGET_FINISH => self.method(:defaultCallback_ON_TARGET_FINISH),
    }
  end

  def resolv(target, resolver = Net::DNS::Resolver)
    resolver.start(target).answer.each do |answer|
      return true if answer.respond_to?('type') and answer.type == 'A'
    end

    false
  end

  def checkStatusHttp(target, ua = @ua)
    begin
      resp_http = ua.head("http://#{target}")
    rescue

    end

    if resp_http.respond_to?('status') and @resposeCodes.include?(resp_http.status)
      return true
    end

    false
  end

  def checkStatusHttps(target, ua = @ua)
    begin
      resp_https = ua.head("https://#{target}")
    rescue

    end

    if resp_https.respond_to?('status') and @resposeCodes.include?(resp_https.status)
      return true
    end

    false
  end


  def run
    found_domains = {}

    threads_list = []
    @threads.times do
      threads_list << Thread.new do

        while @target_list.size > 0
          target = @target_list.pop

          results = []
          @dictionary.each do |subname|
            subdomain = subname+'.'+target
            if resolv(subdomain)
              if @checkWebResponses
                if (checkStatusHttp(subdomain) or checkStatusHttps(subdomain))
                  results.push(subdomain)
                  @callbacks[:FOUND].call(target, subdomain, subname)
                else
                  @callbacks[:NOT_FOUND].call(target, subdomain, subname)
                end
              else
                results.push(subdomain)
                @callbacks[:FOUND].call(target, subdomain, subname)
              end
            else
              @callbacks[:NOT_FOUND].call(target, subdomain, subname)
            end
          end

          @callbacks[:ON_TARGET_FINISH].call(target, results)
          found_domains[target] = results
        end

      end
    end

    threads_list.each {|thr| thr.join }
    found_domains
  end

  def defaultCallback_FOUND(target, subdomain, subname)
    puts "[FOUND] #{subdomain}"
  end

  def defaultCallback_NOT_FOUND(target, subdomain, subname)
    puts "[NOT EXIST] #{subdomain}"
  end

  def defaultCallback_ON_TARGET_FINISH(target, results)
    puts "[Results] Target: #{target} Resolved: #{results.size}"
  end

  def setCallback_FOUND(&block)
    if block.respond_to?('call')
      @callbacks[:FOUND] = block
      return true
    end

    false
  end

  def setCallback_NOT_FOUND(&block)
    if block.respond_to?('call')
      @callbacks[:NOT_FOUND] = block
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
  brt = BruteforceSubdomain.new(
      target_list = ['merron.ru', 'mr-ozio.ru'],
      dictionary = ['shok', 'test', 'azaza', 'lalka', 'pidor'],
      threads=1,
      check_web_responses=true
  )

  brt.setCallback_FOUND do |target, subdomain, subname|
    puts "[CUSTOM FOUND] #{target} #{subdomain} #{subname}"
  end

  brt.setCallback_NOT_FOUND do |target, subdomain, subname|
    puts "[CUSTOM NOT FOUND] #{target} #{subdomain} #{subname}"
  end

  brt.setCallback_ON_TARGET_FINISH do |target, results|
    puts "[CUSTOM Results] Target: #{target} Resolved: #{results.size}"
  end

  p brt.run
end