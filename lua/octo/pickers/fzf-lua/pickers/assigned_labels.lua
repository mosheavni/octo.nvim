---@diagnostic disable
local fzf = require "fzf-lua"
local gh = require "octo.gh"
local graphql = require "octo.gh.graphql"
local picker_utils = require "octo.pickers.fzf-lua.pickers.utils"
local utils = require "octo.utils"

return function(opts)
  opts = opts or {}
  local cb = opts.cb

  local buffer = utils.get_current_buffer()

  if not buffer then
    return
  end

  local query, key
  if buffer:isIssue() then
    query = graphql("issue_labels_query", buffer.owner, buffer.name, buffer.number)
    key = "issue"
  elseif buffer:isPullRequest() then
    query = graphql("pull_request_labels_query", buffer.owner, buffer.name, buffer.number)
    key = "pullRequest"
  end

  local function get_contents(fzf_cb)
    gh.run {
      args = { "api", "graphql", "-f", string.format("query=%s", query) },
      cb = function(output, stderr)
        if stderr and not utils.is_blank(stderr) then
          utils.error(stderr)
        elseif output then
          local resp = vim.json.decode(output)
          local labels = resp.data.repository[key].labels.nodes

          for _, label in ipairs(labels) do
            local colored_name = picker_utils.color_string_with_hex(label.name, "#" .. label.color)
            fzf_cb(string.format("%s %s", label.id, colored_name))
          end
        end

        fzf_cb()
      end,
    }
  end

  fzf.fzf_exec(
    get_contents,
    vim.tbl_deep_extend("force", picker_utils.multi_dropdown_opts, {
      fzf_opts = {
        ["--delimiter"] = "' '",
        ["--with-nth"] = "2..",
      },
      actions = {
        ["default"] = function(selected)
          local labels = {}
          for _, row in ipairs(selected) do
            local id, _ = unpack(vim.split(row, " "))
            table.insert(labels, { id = id })
          end
          cb(labels)
        end,
      },
    })
  )
end
