return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jsonls = {
          settings = {
            json = {
              schemas = {
                {
                  fileMatch = { "*.json", "*.jsonc" },
                  schema = { allowTrailingCommas = true },
                },
              },
            },
          },
        },
      },
    },
  },
}
