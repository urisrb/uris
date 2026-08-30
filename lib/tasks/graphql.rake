namespace :graphql do
  desc "Dump the schema for codegen — the SPA's types are generated from this"
  task dump_schema: :environment do
    path = Rails.root.join("app/javascript/graphql/schema.graphql")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, ThingsSchema.to_definition)
    puts "wrote #{path.relative_path_from(Rails.root)}"
  end
end
