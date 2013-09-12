
require 'master-cap/hypervisors/ssh_helper'

class DnsDnsmasq

  include SshHelper

  def initialize(cap, params)
    @cap = cap
    @params = params
    [:user, :host, :sudo, :hosts_path].each do |x|
      raise "Missing params :#{x}" unless @params[x]
    end
    @ssh = SshDriver.new @params[:host], @params[:user], @params[:sudo]
  end

  def line name, r
    "#{r[:ip]} #{r[:name]}.#{name}"
  end
  def sync name, records, purge
    file = "#{@params[:hosts_path]}/#{name}"
    if purge
      content = []
      records.sort_by{|x| x[:ip]}.each do |x|
        content << line(name, x)
      end
      content << ""
      content = content.join("\n")
      @ssh.scp file, content
      @ssh.exec "killall -HUP dnsmasq"
      puts "Dnsmasq reconfigured on #{@params[:host]} for zone #{name}"
    else
      res = @ssh.capture "cat #{file} || true"
      modified = false
      records.sort_by{|x| x[:ip]}.each do |x|
        unless res =~ /#{x[:name]}.#{name}/
          puts "Added #{x[:name]}.#{name}"
          res += line(name, x) + "\n"
          modified = true
        end
      end
      if modified
        @ssh.scp file, res
        @ssh.exec "killall -HUP dnsmasq"
        puts "Dnsmasq updated on #{@params[:host]} for zone #{name}"
      end
    end
  end

end