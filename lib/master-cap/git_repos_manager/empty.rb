
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
