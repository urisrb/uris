import type { CodegenConfig } from '@graphql-codegen/cli'

const config: CodegenConfig = {
  schema: 'web/schema.graphql',
  documents: ['web/src/operations/**/*.graphql'],
  ignoreNoDocuments: true,
  generates: {
    'web/src/generated/graphql.ts': {
      plugins: ['typescript', 'typescript-operations', 'typed-document-node'],
      config: {
        useTypeImports: true,
        scalars: {
          Upload: 'File',
          ISO8601DateTime: 'string',
          JSON: 'Record<string, unknown>',
        },
      },
    },
  },
}

export default config
