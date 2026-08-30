import type { CodegenConfig } from '@graphql-codegen/cli'

const config: CodegenConfig = {
  schema: 'app/javascript/graphql/schema.graphql',
  documents: [
    'app/javascript/**/*.graphql',
    'app/javascript/**/*.ts',
    'app/javascript/**/*.tsx',
  ],
  ignoreNoDocuments: true,
  generates: {
    'app/javascript/graphql/generated/': {
      preset: 'client',
      config: {
        useTypeImports: true,
        scalars: {
          Upload: 'File',
        },
      },
    },
  },
}

export default config
