return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        json = { "prettier" },
        jsonc = { "prettier" },
        css = { "prettier" },
        kdl = { "kdlfmt" },
        csharp = { "csharpier" },
      },
      formatters = {
        kdlfmt = {
          command = "kdl-fmt",
          stdin = false,
          args = { "--in-place", "--indent-level", "4", "$FILENAME" },
        },
      },
    },
  },
}
