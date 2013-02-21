
class EmptyGitReposManager

  def initialize cap
    @cap = cap
  end

  def compute_override env
    if @cap.exists? :master_chef_version
      return {"http://github.com/octo-technology/master-chef.git" => @cap.master_chef_version}
    end
    nil
  end

  def list
    ["http://github.com/octo-technology/master-chef.git"]
  end

  def compute_local_path
    ""
  end

end

class SimpleGitReposManager

  def initialize cap
    @cap = cap
    @repos = @cap.fetch(:git_repos, [])
  end

  def compute_override env
    result = {}
    @repos.each do |x|
      result[x[:url]] = x[:ref] if x[:ref]
    end
    result.size == 0 ? nil : result
  end

  def list
    @repos.map{|x| x[:url]}
  end

  def compute_local_path
    @repos.map{|x| x[:local_path] ? File.expand_path(x[:local_path]) : ""}.join(' ')
  end

end
