-- Normalize semantic QLNotes HTML before Pandoc writes editable snapshots.

local function has_class(element, wanted)
  for _, class in ipairs(element.classes) do
    if class == wanted then
      return true
    end
  end
  return false
end

local function first_child_div(element)
  for _, block in ipairs(element.content) do
    if block.t == "Div" then
      return block
    end
  end
  return nil
end

local function attribute(element, name)
  return element.attributes["data-" .. name] or element.attributes[name]
end

local function split_pipe(value)
  local values = {}
  if value == nil or value == "" then
    return values
  end
  for item in string.gmatch(value, "([^|]+)") do
    table.insert(values, item)
  end
  return values
end

local function join_comma(values)
  return table.concat(values, ", ")
end

local function flatten_semantic(element)
  if not has_class(element, "ql-semantic") then
    return nil
  end

  local child = first_child_div(element)
  if child == nil then
    return element.content
  end

  child.identifier = attribute(element, "ql-id") or child.identifier
  child.attributes["kind"] = attribute(element, "ql-kind") or ""
  child.attributes["concepts"] =
    join_comma(split_pipe(attribute(element, "ql-concepts")))
  child.attributes["depends"] =
    join_comma(split_pipe(attribute(element, "ql-depends")))
  child.attributes["aliases"] =
    join_comma(split_pipe(attribute(element, "ql-aliases")))
  return child
end

local function strip_leading_number(inlines)
  if #inlines == 0 or inlines[1].t ~= "Str" then
    return inlines
  end
  if not string.match(inlines[1].text, "^%d+[%.%d]*$") then
    return inlines
  end

  table.remove(inlines, 1)
  if #inlines > 0 and inlines[1].t == "Space" then
    table.remove(inlines, 1)
  end
  return inlines
end

local function title_from_head(head, kind)
  local text = pandoc.utils.stringify(head)
  local labels = {
    definition = "Definition",
    theorem = "Theorem",
    lemma = "Lemma",
    corollary = "Corollary",
    proposition = "Proposition",
    example = "Example",
  }
  local label = labels[kind] or kind
  local escaped = string.gsub(label, "([^%w])", "%%%1")
  text = string.gsub(text, "^" .. escaped .. "%s+%d+[%.%d]*%s*:%s*", "")
  text = string.gsub(text, "^" .. escaped .. "%s+%d+[%.%d]*%s*", "")
  return text
end

local function latex_escape_title(title)
  if title == "" then
    return ""
  end
  local document = pandoc.read(title, "markdown")
  if #document.blocks == 0 then
    return ""
  end
  local rendered = pandoc.write(document, "latex")
  rendered = string.gsub(rendered, "^%s+", "")
  rendered = string.gsub(rendered, "%s+$", "")
  -- `pandoc.utils.stringify` deliberately removes inline-math boundaries
  -- from the HTML heading. Keep theorem titles robust by using readable
  -- textual names for alphabet symbols that would otherwise leave commands
  -- such as `\mathbb` outside math mode.
  rendered = string.gsub(rendered, "\\{\\mathbb{P}\\}", "P")
  rendered = string.gsub(rendered, "\\mathbb{P}", "P")
  rendered = string.gsub(rendered, "\\mathcal{F}", "F")
  rendered = string.gsub(rendered, "\\Omega", "Omega")
  for command, word in pairs({
    ["\\sigma"] = "sigma",
    ["\\pi"] = "pi",
    ["\\lambda"] = "lambda",
    ["\\mu"] = "mu",
    ["\\rho"] = "rho",
    ["\\Gamma"] = "Gamma",
    ["\\Longrightarrow"] = "implies",
  }) do
    rendered = string.gsub(rendered, command, word)
  end
  return rendered
end

local function blocks_from_named_parts(element, head_class, body_class)
  local head = nil
  local body = {}
  for _, block in ipairs(element.content) do
    if block.t == "Div" and has_class(block, head_class) then
      head = block
    elseif block.t == "Div" and has_class(block, body_class) then
      body = block.content
    else
      table.insert(body, block)
    end
  end
  return head, body
end

local function markdown_semantic_div(element, kind, title, body)
  local attributes = {}
  for key, value in pairs(element.attributes) do
    if
      value ~= ""
      and key ~= "role"
      and key ~= "kind"
      and string.sub(key, 1, 5) ~= "data-"
    then
      attributes[key] = value
    end
  end

  local blocks = pandoc.List()
  local label = string.upper(string.sub(kind, 1, 1)) .. string.sub(kind, 2)
  local heading = label
  if title ~= "" and string.lower(title) ~= string.lower(label) then
    heading = heading .. ": " .. title
  end
  blocks:insert(pandoc.Para({ pandoc.Strong({ pandoc.Str(heading) }) }))
  blocks:extend(body)
  return pandoc.Div(
    blocks,
    pandoc.Attr(element.identifier, { kind }, attributes)
  )
end

local function latex_environment(element, kind, title, body)
  local begin = "\\begin{" .. kind .. "}"
  local rendered_title = latex_escape_title(title)
  if rendered_title ~= "" then
    if kind == "example" then
      begin = begin .. "[" .. rendered_title .. "]"
    else
      begin = begin .. "{" .. rendered_title .. "}"
    end
  end
  if element.identifier ~= "" then
    begin = begin .. "\\label{" .. element.identifier .. "}"
  end

  local metadata = {}
  if element.identifier ~= "" then
    table.insert(metadata, "id=" .. element.identifier)
  end
  for _, key in ipairs({ "concepts", "depends", "aliases" }) do
    if element.attributes[key] ~= nil and element.attributes[key] ~= "" then
      local value = string.gsub(element.attributes[key], "[\r\n]+", " ")
      table.insert(metadata, key .. "=" .. value)
    end
  end
  if #metadata > 0 then
    begin = "% qlnotes: kind=" .. kind .. "; " ..
      table.concat(metadata, "; ") .. "\n" .. begin
  end

  local blocks = pandoc.List({ pandoc.RawBlock("latex", begin) })
  blocks:extend(body)
  blocks:insert(pandoc.RawBlock("latex", "\\end{" .. kind .. "}"))
  return blocks
end

local function convert_callout(element, kind)
  local head, body = blocks_from_named_parts(
    element,
    "ql-callout__head",
    "ql-callout__body"
  )
  local title = head and title_from_head(head, kind) or ""
  if FORMAT:match("latex") then
    return latex_environment(element, kind, title, body)
  end
  return markdown_semantic_div(element, kind, title, body)
end

local function convert_note(element)
  local head, body = blocks_from_named_parts(
    element,
    "ql-note__title",
    "ql-note__body"
  )
  local title = head and pandoc.utils.stringify(head) or "Note"

  if FORMAT:match("latex") then
    local begin = "\\begin{qlnote}{" .. latex_escape_title(title) .. "}"
    local blocks = pandoc.List({ pandoc.RawBlock("latex", begin) })
    blocks:extend(body)
    blocks:insert(pandoc.RawBlock("latex", "\\end{qlnote}"))
    return blocks
  end
  return markdown_semantic_div(element, "note", title, body)
end

local function convert_proof(element)
  local _, body = blocks_from_named_parts(
    element,
    "ql-proof__title",
    "ql-proof__body"
  )
  if FORMAT:match("latex") then
    local blocks = pandoc.List({ pandoc.RawBlock("latex", "\\begin{proof}") })
    blocks:extend(body)
    blocks:insert(pandoc.RawBlock("latex", "\\end{proof}"))
    return blocks
  end
  return markdown_semantic_div(element, "proof", "", body)
end

local function convert_titled_simple(
  element,
  kind,
  title_class,
  default_title,
  latex_environment_name
)
  local head, body = blocks_from_named_parts(
    element,
    title_class,
    kind .. "__body"
  )
  local title = head and pandoc.utils.stringify(head) or default_title
  if FORMAT:match("latex") then
    local begin = "\\begin{" .. latex_environment_name .. "}{" ..
      latex_escape_title(title) .. "}"
    local blocks = pandoc.List({ pandoc.RawBlock("latex", begin) })
    blocks:extend(body)
    blocks:insert(
      pandoc.RawBlock("latex", "\\end{" .. latex_environment_name .. "}")
    )
    return blocks
  end
  return markdown_semantic_div(element, kind, title, body)
end

local function normalize_div(element)
  if has_class(element, "ql-main") then
    return element.content
  end
  if has_class(element, "ql-callout--definition") then
    return convert_callout(element, "definition")
  end
  if has_class(element, "ql-callout--theorem") then
    return convert_callout(element, "theorem")
  end
  if has_class(element, "ql-callout--lemma") then
    return convert_callout(element, "lemma")
  end
  if has_class(element, "ql-callout--corollary") then
    return convert_callout(element, "corollary")
  end
  if has_class(element, "ql-callout--proposition") then
    return convert_callout(element, "proposition")
  end
  if has_class(element, "ql-callout--example") then
    return convert_callout(element, "example")
  end
  if has_class(element, "ql-note") then
    return convert_note(element)
  end
  if has_class(element, "ql-remark") then
    return convert_titled_simple(
      element,
      "remark",
      "ql-remark__title",
      "Remark",
      "qlremark"
    )
  end
  if has_class(element, "ql-proof") then
    return convert_proof(element)
  end
  if has_class(element, "ql-solution") then
    return convert_titled_simple(
      element,
      "solution",
      "ql-solution__title",
      "Solution",
      "qlsolution"
    )
  end
  return nil
end

local function normalize_header(element)
  element.content = strip_leading_number(element.content)
  if element.level > 1 then
    element.level = element.level - 1
  end
  if string.match(element.identifier, "^loc%-%d+$") then
    element.identifier = ""
  end
  return element
end

local function normalize_span(element)
  if has_class(element, "ql-proof__qed") then
    return {}
  end
  if not has_class(element, "ql-citation") then
    return nil
  end

  local key = attribute(element, "ql-key")
  if key == nil or key == "" then
    return element
  end
  local citation = pandoc.Citation(key, "NormalCitation")
  citation.prefix = {}
  citation.suffix = {}
  return pandoc.Cite(element.content, { citation })
end

local function normalize_math(element)
  local replacements = {
    ["\\text{ℙ}"] = "\\mathbb{P}",
    ["\\text{𝔼}"] = "\\mathbb{E}",
    ["\\text{ℕ}"] = "\\mathbb{N}",
    ["\\text{ℚ}"] = "\\mathbb{Q}",
    ["\\text{ℝ}"] = "\\mathbb{R}",
    ["\\text{ℤ}"] = "\\mathbb{Z}",
  }
  for source, replacement in pairs(replacements) do
    element.text = string.gsub(element.text, source, replacement)
  end
  element.text = string.gsub(element.text, "\\mathbb{([PENQRZ])}\\ ", "\\mathbb{%1}")
  element.text = string.gsub(element.text, "≔", ":=")
  return element
end

local function normalize_meta(meta)
  meta.authors = nil
  meta.viewport = nil
  if meta["qlnotes-language"] ~= nil then
    meta.lang = meta["qlnotes-language"]
    meta["qlnotes-language"] = nil
  end
  if meta["qlnotes-keywords"] ~= nil then
    meta.keywords = meta["qlnotes-keywords"]
    meta["qlnotes-keywords"] = nil
  end
  return meta
end

local function normalize_link(element)
  if not FORMAT:match("latex") then
    return nil
  end
  local target = element.target
  if string.sub(target, 1, 1) ~= "#" then
    return nil
  end
  local identifier = string.sub(target, 2)
  if identifier == "" or string.match(identifier, "^loc%-%d+$") then
    return nil
  end
  local text = pandoc.utils.stringify(element)
  local kind = nil
  for _, candidate in ipairs({
    "Definition",
    "Theorem",
    "Lemma",
    "Corollary",
    "Proposition",
    "Example",
    "Figure",
    "Table",
    "Section",
    "Chapter",
  }) do
    if string.sub(text, 1, #candidate) == candidate then
      kind = candidate
      break
    end
  end
  local prefix = kind and (kind .. "~") or ""
  return pandoc.RawInline(
    "latex",
    "\\hyperref[" .. identifier .. "]{" .. prefix .. "\\ref*{" ..
      identifier .. "}}"
  )
end

local function normalize_image(element)
  if FORMAT:match("latex") then
    element.src = string.gsub(
      element.src,
      "^[^/]+%.assets/(.+)%.svg$",
      "assets/%1.pdf"
    )
    element.src = string.gsub(element.src, "%.svg$", ".pdf")
  end
  return element
end

local function normalize_figure(element)
  if #element.content == 1 and element.content[1].t == "Table" then
    local table = element.content[1]
    local caption = pandoc.utils.stringify(element.caption)
    caption = string.gsub(caption, "\194\160", " ")
    caption = string.gsub(caption, "^Table%s+%d+:%s*", "")
    table.caption = pandoc.Caption(caption)
    return table
  end
  return nil
end

return {
  {
    Div = flatten_semantic,
  },
  {
    Header = normalize_header,
    Div = normalize_div,
    Span = normalize_span,
    Link = normalize_link,
    Math = normalize_math,
    Image = normalize_image,
    Figure = normalize_figure,
    Meta = normalize_meta,
  },
}
