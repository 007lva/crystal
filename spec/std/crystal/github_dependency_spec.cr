require "spec"
require "crystal/project/github_dependency"

module Crystal
  describe "GitHubDependency" do
    describe "#initialize" do
      it "uses the repository's name as the dependency name" do
        dependency = GitHubDependency.new("owner/repo")

        dependency.name.should eq("repo")
      end

      it "customizes GitHub dependency name" do
        dependency = GitHubDependency.new("owner/repo", "name")

        dependency.name.should eq("name")
      end

      ["space /you", "space/ you", "/hello/bello",
        "invalid-repo", "  owner/repo", "owner/repo "].each do |project|
        it "raises error with invalid GitHub project definition #{project}" do
          expect_raises ProjectError, "Invalid GitHub repository definition: #{project}" do
            GitHubDependency.new(project)
          end
        end
      end

      %w(crystal_repo crystal-repo repo.cr repo_crystal repo-crystal).each do |repo_name|
        it "guesses name from project name like #{repo_name}" do
          dependency = GitHubDependency.new("owner/#{repo_name}")

          dependency.name.should eq("repo")
        end

        it "doesn't guess name from project name when specifying name" do
          dependency = GitHubDependency.new("owner/#{repo_name}", "name")

          dependency.name.should eq("name")
        end
      end

      it "gets the target_dir" do
        dependency = GitHubDependency.new("owner/repo")
        dependency.target_dir.should eq(".deps/owner-repo")
      end
    end
  end
end
