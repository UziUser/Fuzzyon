#!/usr/bin/env ruby

require 'httpclient'
require 'net/dns'

config = {
    :dir_base => 'dir_base.txt',
    :subdomain_base => 'sub_base.txt',
    :targets => 'sites.txt',

    :timeout_http_client => 5,
    :threads_resolver => 1,
    :threads_subdomain_scanner => 1,
    :threads_dir_scanner => 1,
}

def loadDictionary(name, path)
  STDOUT.sync = false
  puts "Loading #{name} ..."
  dir_base = File.readlines(path).each.map(&:chomp)
  puts "Loading #{name} ... OK"
  STDOUT.sync = true
  return dir_base
end

dir_base = loadDictionary('dir base', config[:dir_base])
sub_base = loadDictionary('subdomain base', config[:subdomain_base])
sites = loadDictionary('targets base', config[:targets])


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

  return result
end

targets = sites.clone
found_domains = {}

axfr_resolver_threads = []
config[:threads_resolver].times do
  axfr_resolver_threads << Thread.new do
    while targets.size > 0
      target = targets.pop

      begin
        results = resolverGetInfo(target)
      rescue
        results = []
      end

      results.delete(target)
      puts "[Resolver] Target: #{target} Resolved: #{results.size}"
      found_domains[target] = results
    end
  end
end

puts "[INFO] Start AXFR resolver ..."
axfr_resolver_threads.each {|thr| thr.join }

def checkDomain(target, found_domains = {}, ua = HTTPClient.new)
  if found_domains.include?(target)
    return false
  end

  begin
    resp = ua.head("http://#{target}/")
  rescue
    return false
  end

  if resp.respond_to?('status') and resp.status == 200
    return true
  end

  return false
end

http_client = HTTPClient.new
http_client.follow_redirect_count = 1
http_client.receive_timeout = config[:timeout_http_client]
http_client.send_timeout = config[:timeout_http_client]
http_client.cookie_manager = nil

targets = []
sites.each do |site|
  sub_base.each do |sub|
    targets.push( {:sub_domain => sub + '.' + site, :original => site} )
  end
end

dir_scanner_threads = []
config[:threads_subdomain_scanner].times do
  dir_scanner_threads << Thread.new do
    while targets.size > 0
      target = targets.pop

      begin
        result = checkDomain(target[:sub_domain], found_domains, http_client)
      rescue
        next
      end

      unless result
        next
      end

      puts "[Scanner] Target: #{target[:original]} Found: #{target[:sub_domain]}"

      if found_domains.include?(target[:original])
        found_domains[target[:original]].push(target[:sub_domain])
      else
        found_domains[target[:original]] = [target[:sub_domain]]
      end

      sub_base.each do |sub|
        targets.push( {:sub_domain => "#{sub}.#{target[:sub_domain]}", :original => target[:sub_domain]} )
      end

    end
  end
end

puts "[INFO] Start subdomain scanner ..."
dir_scanner_threads.each {|thr| thr.join }

if File.exist?('tmp1.txt')
  File.delete('tmp1.txt')
end

tmp_file = File.open('tmp1.txt', 'a')
found_domains.each do |key, value|
  value.each do |subdomain|
    dir_base.each do |dir|
      tmp_file.puts "#{key}|#{subdomain}|#{dir}"
    end
  end
end
tmp_file.close

tasks_file = File.open('tmp1.txt')

found_path = {}

dir_scanner_threads = []
config[:threads_dir_scanner].times do
  dir_scanner_threads << Thread.new do
    until tasks_file.eof?
      target = tasks_file.gets.chomp.split('|')
      next if target.empty?
      url = "http://#{target[1]}/#{target[2]}"

      if found_path.include?(target[1]) and found_path[target[1]].include?(url)
        next
      end

      begin
        resp = http_client.head(url)
      rescue
        next
      end

      next unless resp.respond_to?('status') and resp.status == 200
      puts "[Dir Scanner] Target: #{target[0]} Found: #{url}"

      if found_path.include?(target[0])
        found_path[target[0]].push(url)
      else
        found_path[target[0]] = [url]
      end
    end
  end
end

puts "[INFO] Start dir scanner ..."
dir_scanner_threads.each {|thr| thr.join }
File.delete('tmp1.txt')

found_domains.each do |key, value|
  puts "---------------------------------------------------------------------------------------------"
  puts "Target: #{key}"
  puts "Subdomains: #{value.size.to_s} Files and directories: #{found_path[key].size.to_s}"

  if value.size > 0
    puts "============================================\nSubdomains:\n#{value.join("\n")}"
  end

  if found_path[key].size > 0
    puts "============================================\nFiles and directories:\n#{found_path[key].join("\n")}"
  end

  puts "---------------------------------------------------------------------------------------------\n\n"
end