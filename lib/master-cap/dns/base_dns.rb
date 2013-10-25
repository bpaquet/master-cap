
class BaseDns

  def full_name name, record
    "#{record[:name]}.#{name}"
  end

  def sync name, records, purge, no_dry
    current = read_current_records name
    modified = false
    start_diff current
    records.sort_by{|x| x[:ip]}.each do |x|
      same = current.find{|z| z[:full_name] == full_name(name, x) || z[:name] == x[:name]}
      if same
        if x[:ip] != same[:ip]
          puts "Replacing #{full_name(name, x)} by #{x[:ip]}"
          delete_record name, full_name(name, x), x if no_dry
          add_record name, full_name(name, x), x if no_dry
          modified = true
        end
      else
        puts "Adding record #{full_name(name, x)} : #{x[:ip]}"
        add_record name, full_name(name, x), x if no_dry
        modified = true
      end
    end
    if purge
      current.each do |z|
        current_full_name = z[:full_name] || full_name(name, z)
        unless records.find{|x| current_full_name == full_name(name, x) || z[:name] == x[:name]}
          puts "Deleting record #{current_full_name} : #{z[:ip]}"
          delete_record name, current_full_name, z if no_dry
          modified = true
        end
      end
    end
    end_diff
    reload name if modified && no_dry
    puts "Zone #{name} synced"
  end
end