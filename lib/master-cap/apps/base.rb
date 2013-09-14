
class AppsBase

  attr_reader :cap
  attr_reader :name
  attr_reader :config

  def initialize cap, name, config
    @cap = cap
    @name = name
    @config = config
    [:finder, :cap_directory].each do |x|
      raise "Please specify :#{x} attr" unless config[x]
    end
  end

  def get_topology(map)
    list = Hash.new { |hash, key| hash[key] = [] }
    map.each do |role, mapped_roles|
      cap.find_servers(:roles => role).each do |n|
        mapped_roles.each do |r|
          unless list[n].include? r
            list[n] << r
          end
        end
      end
    end
    list
  end

  def run_sub_cap cap_command, opts = {}
    f = Tempfile.new File.basename("sub_cap")
    f.write JSON.dump(get_topology(config[:finder]))
    f.close
    files_to_load = config[:cap_files_to_load] || []
    params = opts.map{|k, v| "-s #{k}=#{v}"}.join(" ")
    params += "-S http_proxy='#{cap.fetch(:http_proxy)}'" if cap.exists? :http_proxy
    params += "-S no_proxy='#{cap.fetch(:no_proxy)}'" if cap.exists? :no_proxy
    cmd = "cd #{cap.fetch(:apps_cap_directory)}/#{config[:cap_directory]} && TOPOLOGY=#{f.path} LOAD_INTO_CAP=#{files_to_load.join(':')} cap #{params} #{cap_command}"
    cap.exec_local cmd
  end

end