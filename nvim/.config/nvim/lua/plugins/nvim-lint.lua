return {
  {
    "fussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        markdown = {'vale',},
        python = {'pylint',},
        }
      }
  }
}
