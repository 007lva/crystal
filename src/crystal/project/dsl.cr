struct Crystal::Project::DSL
  def initialize(@project)
  end

  def deps
    with Deps.new(@project) yield
  end

  struct Deps
    def initialize(@project)
    end

    def github(repository, name = nil : String, ssl = nil : Bool, branch = nil : String)
      @project.dependencies << GitHubDependency.new(repository, name, ssl, branch)
    end

    def path(path, name = nil : String)
      @project.dependencies << PathDependency.new(path, name)
    end
  end
end
