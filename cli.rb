#!/usr/bin/env ruby

VERSION = 1

require 'choice'

opts = Choice.options do
  banner <<-EOS
USAGE: #{$0} -t example.com
       #{$0} -T targets.txt --dir-recursive --at=10
       #{$0} -T targets.txt -dr -at=10 -st 10 -sl sub_base.txt
EOS

  header ''
  header 'DESCRIPTION:'
  header '   Who\'s that fazzeon?'
  header '   Simple site scanner'

  separator ''
  separator 'Target:'

  option :target do
    long '--target=HOST'
    short '-t'
    desc 'Set target host (ip or domain)  (127.0.0.1 or example.com or 127.0.0.1:80)'
  end

  option :'targets-list' do
    long '--targets-list=hosts.txt'
    short '-tl'
    desc 'Target hosts file'
  end

  separator ''
  separator 'AXFR scanner:'

  option :'axfr-threads' do
    long '--axfr-threads=10'
    short '-at'
    desc 'Set number of threads in AXFR scanner (default 5)'
  end

  separator ''
  separator 'Subdomain bruteforce:'

  option :'sub-threads' do
    long '--sub-threads=10'
    short '-st'
    desc 'Set number of threads in subdomain bruteforce (default 5)'
  end

  option :'sub-list' do
    long '--sub-list=subnames.txt'
    short '-sl'
    desc 'Set subdomains list'
  end

  option :'sub-recursive' do
    long '--sub-recursive'
    short '-sr'
    desc 'Use recursive subdomain bruteforce'
  end

  separator ''
  separator 'Directory bruteforce:'

  option :'dir-threads' do
    long '--dir-threads=10'
    short '-dt'
    desc 'Set number of threads in directory bruteforce (default 5)'
  end

  option :'dir-list' do
    long '--dir-list=dirnames.txt'
    short '-dl'
    desc 'Set directories list'
  end

  option :'dir-recursive' do
    long '--dir-recursive'
    short '-dr'
    desc 'Use recursive directory bruteforce'
  end

  separator ''
  separator 'File bruteforce:'

  option :'file-threads' do
    long '--file-threads=10'
    short '-ft'
    desc 'Set number of threads in file bruteforce (default 5)'
  end

  option :'files-list' do
    long '--files-list=dict.txt'
    short '-fl'
    desc 'Set files list'
  end

  option :'extensions-list' do
    long '--ext-list=ext-list.txt'
    short '-el'
    desc 'Set extensions list'
  end

  option :'extensions-direct-list' do
    long '--ext-direct-list=php,html'
    short '-edl'
    desc 'Set extensions list directly'
  end

  option :'file-download' do
    long '--file-download'
    short '-fd'
    desc 'Automate downloading found files (default false)'
  end

  option :'file-download-path' do
    long '--file-download-path'
    short '-fdp'
    desc 'Automate downloading found files path (default ~/.fuzzyon/output/<target>/files/)'
  end

  separator ''
  separator 'Git dumper: '

  option :'git-enabled' do
    long '--git-enabled'
    short '-ge'
    desc 'Use git dumper to dump source code from .git/index (default false)'
  end

  option :'git-path' do
    long '--git-path=~/result'
    short '-gp'
    desc 'Set path to download sources (default ~/.fuzzyon/output/<target>/git/)'
  end

  separator ''
  separator 'Common options: '

  option :help do
    long '--help'
    short '-h'
    desc 'Show this message'

    action do
      Choice.help
    end
  end

  option :version do
    short '-v'
    long '--version'
    desc 'Show version'
    action do
      puts "Fuzzyon CLI v#{VERSION}"
      exit
    end
  end

end

p opts