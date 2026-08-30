import type { CodegenConfig } from "@graphql-codegen/cli"

// The Ruby schema is dumped to schema.graphql by `bin/rails graphql:dump_schema`,
// and the TypeScript hooks are generated from that dump. The SPA therefore
// cannot drift from the API without the build going red.
const config: CodegenConfig = {
  schema: "app/javascript/graphql/schema.graphql",
  documents: [
    "app/javascript/**/*.graphql",
    "app/javascript/**/*.ts",
    "app/javascript/**/*.tsx",
  ],
  ignoreNoDocuments: true,
  generates: {
    "app/javascript/graphql/generated/": {
      preset: "client",
      config: {
        useTypeImports: true,
        scalars: {
          Upload: "File",
        },
      },
    },
  },
}

export default config
