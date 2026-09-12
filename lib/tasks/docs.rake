namespace :docs do
  desc "Write the reference pages under docs/ from the code they describe"
  task reference: :environment do
    [
      ReferencePages::Graphql,
      ReferencePages::Mcp,
      ReferencePages::Resources,
      ReferencePages::Scopes,
      ReferencePages::Environment
    ].each do |page|
      puts "wrote #{page.write.relative_path_from(Rails.root)}"
    end
  end
end
