const fs = require("fs");
const path = require("path");

const BLOCK_NAMES = new Set([
  "introduction",
  "definition",
  "theorem",
  "lemma",
  "corollary",
  "proposition",
  "example",
  "exercise",
  "problem",
  "proof",
  "solution",
  "remark",
  "note",
]);

const BOX_ENVS = {
  definition: { cls: "definition", label: "Def", counter: "definition", mark: "♣" },
  theorem: { cls: "theorem", label: "Theorem", counter: "theorem", mark: "♥" },
  lemma: { cls: "theorem", label: "Lemma", counter: "lemma", mark: "♥" },
  corollary: { cls: "theorem", label: "Corollary", counter: "corollary", mark: "♥" },
  proposition: { cls: "proposition", label: "Proposition", counter: "proposition", mark: "♠" },
};

const INLINE_ENVS = {
  example: { cls: "example", label: "Example", counter: "example" },
  exercise: { cls: "exercise", label: "✎ Exercise", counter: "exercise" },
  problem: { cls: "example", label: "Problem", counter: "problem" },
};

const SIMPLE_ENVS = {
  proof: { cls: "proof", label: "Proof." },
  solution: { cls: "solution", label: "Sol." },
  remark: { cls: "remark", label: "Remark" },
  note: { cls: "remark", label: "Note" },
};

class TypstWebConverter {
  constructor(source) {
    const extracted = this.extractPreamble(source);
    this.source = extracted.source;
    this.meta = extracted.meta;
    this.heading = [0, 0, 0, 0, 0, 0];
    this.chapter = 0;
    this.toc = [];
    this.counters = this.freshCounters();
    this.usedIds = new Map();
  }

  freshCounters() {
    return {
      definition: 0,
      theorem: 0,
      lemma: 0,
      corollary: 0,
      proposition: 0,
      example: 0,
      exercise: 0,
      problem: 0,
    };
  }

  extractPreamble(source) {
    const meta = {
      title: "Typst Notes",
      subtitle: "",
      author: "",
      date: "",
    };

    let text = source.replace(/^#import[^\n]*(?:\n|$)/gm, "");
    const showIndex = text.indexOf("#show:");

    if (showIndex >= 0) {
      const withIndex = text.indexOf("elegantbook.with", showIndex);
      const open = withIndex >= 0 ? text.indexOf("(", withIndex) : -1;

      if (open >= 0) {
        const close = findMatching(text, open, "(", ")");
        if (close >= 0) {
          const args = text.slice(open + 1, close);
          for (const key of Object.keys(meta)) {
            const match = args.match(new RegExp(`${key}:\\s*"([^"]*)"`));
            if (match) meta[key] = match[1];
          }
          text = text.slice(0, showIndex) + text.slice(close + 1);
        }
      }
    }

    text = removeFunctionCalls(text, "outline");
    return { source: text, meta };
  }

  convert() {
    const body = this.renderFragment(this.source);
    const toc = this.renderToc();
    return this.renderDocument(toc, body);
  }

  renderDocument(toc, body) {
    const title = escapeHtml(this.meta.title);
    const subtitle = this.meta.subtitle
      ? `<p class="subtitle">${escapeHtml(this.meta.subtitle)}</p>`
      : "";
    const metaParts = [];
    if (this.meta.author) metaParts.push(`Author: ${escapeHtml(this.meta.author)}`);
    if (this.meta.date) metaParts.push(`Date: ${escapeHtml(this.meta.date)}`);
    const meta = metaParts.length ? `<p class="meta">${metaParts.join(" &nbsp;&nbsp; ")}</p>` : "";

    return `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${title}</title>
    <link rel="stylesheet" href="elegant.css">
    <script>
      window.MathJax = {
        tex: {
          inlineMath: [["\\\\(", "\\\\)"]],
          displayMath: [["\\\\[", "\\\\]"]]
        },
        svg: {
          fontCache: "global"
        }
      };
    </script>
    <script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"></script>
  </head>
  <body>
    <div class="site">
${indent(toc, 6)}

      <main class="page">
        <header class="doc-header">
          <h1>${title}</h1>
          ${subtitle}
          ${meta}
        </header>

${indent(body, 8)}
      </main>
    </div>
  </body>
</html>
`;
  }

  renderToc() {
    const items = this.toc
      .filter((item) => item.level <= 3)
      .map((item) => {
        const label = item.level === 1 ? item.title : `${item.number} ${item.title}`;
        return `<li class="toc-level-${item.level}"><a href="#${item.id}">${escapeHtml(label)}</a></li>`;
      })
      .join("\n");

    return `<nav class="toc" aria-label="Contents">
  <h2 class="toc-title">Contents</h2>
  <ol>
${indent(items, 4)}
  </ol>
</nav>`;
  }

  renderFragment(src) {
    let pos = 0;
    let plain = "";
    const html = [];

    const flushPlain = () => {
      const rendered = this.renderPlain(plain);
      if (rendered.trim()) html.push(rendered);
      plain = "";
    };

    while (pos < src.length) {
      if (isLineStart(src, pos) && src[pos] === "=") {
        const match = src.slice(pos).match(/^(={1,6})\s+([^\n]*)/);
        if (match) {
          flushPlain();
          html.push(this.renderHeading(match[1].length, match[2].trim()));
          pos += match[0].length;
          if (src[pos] === "\n") pos += 1;
          continue;
        }
      }

      if (src[pos] === "#") {
        const call = this.tryParseCall(src, pos);
        if (call) {
          flushPlain();
          html.push(this.renderCall(call.name, call.args, call.body));
          pos = call.end;
          continue;
        }
      }

      plain += src[pos];
      pos += 1;
    }

    flushPlain();
    return html.join("\n\n");
  }

  tryParseCall(src, pos) {
    if (src[pos] !== "#") return null;
    const nameMatch = src.slice(pos + 1).match(/^([A-Za-z][A-Za-z0-9_-]*)/);
    if (!nameMatch) return null;

    const name = nameMatch[1];
    if (!BLOCK_NAMES.has(name)) return null;

    let cursor = pos + 1 + name.length;
    cursor = skipWhitespace(src, cursor);

    let args = "";
    if (src[cursor] === "(") {
      const close = findMatching(src, cursor, "(", ")");
      if (close < 0) return null;
      args = src.slice(cursor + 1, close);
      cursor = skipWhitespace(src, close + 1);
    }

    if (src[cursor] !== "[") return null;
    const closeBody = findMatching(src, cursor, "[", "]");
    if (closeBody < 0) return null;

    return {
      name,
      args,
      body: src.slice(cursor + 1, closeBody),
      end: closeBody + 1,
    };
  }

  renderHeading(level, rawTitle) {
    this.heading[level - 1] += 1;
    for (let i = level; i < this.heading.length; i += 1) this.heading[i] = 0;

    if (level === 1) {
      this.chapter = this.heading[0];
      this.counters = this.freshCounters();
    }

    const number = this.heading.slice(0, level).filter(Boolean).join(".");
    const id = this.uniqueId(slugify(rawTitle || `section-${number}`));
    this.toc.push({ level, number, title: rawTitle, id });

    if (level === 1) {
      return `<h2 id="${id}">Module ${number}&nbsp; ${this.renderInline(rawTitle)}</h2>`;
    }

    const tag = level === 2 ? "h3" : "h4";
    return `<${tag} id="${id}">${number}&nbsp; ${this.renderInline(rawTitle)}</${tag}>`;
  }

  renderCall(name, args, body) {
    const title = extractTitle(args);

    if (name === "introduction") {
      const rendered = this.renderPlain(body);
      const introTitle = title || "Introduction";
      return `<section class="intro" aria-labelledby="${this.uniqueId("intro-title")}">
  <div class="intro-label">${this.renderInline(introTitle)}</div>
  <div class="intro-body">
${indent(rendered, 4)}
  </div>
</section>`;
    }

    if (BOX_ENVS[name]) {
      return this.renderBoxEnv(BOX_ENVS[name], title, body);
    }

    if (INLINE_ENVS[name]) {
      return this.renderNumberedInlineEnv(INLINE_ENVS[name], title, body);
    }

    if (SIMPLE_ENVS[name]) {
      return this.renderSimpleInlineEnv(SIMPLE_ENVS[name], title, body);
    }

    return this.renderPlain(body);
  }

  renderBoxEnv(config, title, body) {
    const number = this.nextCounter(config.counter);
    const label = this.labelText(config.label, number, title);
    const rendered = this.renderFragment(body);

    return `<section class="env ${config.cls}">
  <div class="env-label">${label}</div>
  <div class="env-body">
${indent(rendered, 4)}
    <span class="env-mark">${config.mark}</span>
  </div>
</section>`;
  }

  renderNumberedInlineEnv(config, title, body) {
    const number = this.nextCounter(config.counter);
    const label = this.labelText(config.label, number, title);
    const rendered = this.renderFragment(body);

    return `<section class="inline-env ${config.cls}">
  <p><span class="inline-label">${label}</span></p>
${indent(rendered, 2)}
</section>`;
  }

  renderSimpleInlineEnv(config, title, body) {
    const label = title ? `${config.label} (${this.renderInline(title)})` : config.label;
    const rendered = this.renderFragment(body);

    return `<div class="inline-env ${config.cls}">
  <p><span class="inline-label">${label}</span></p>
${indent(rendered, 2)}
</div>`;
  }

  labelText(label, number, title) {
    return title
      ? `${escapeHtml(label)} ${number} (${this.renderInline(title)})`
      : `${escapeHtml(label)} ${number}`;
  }

  nextCounter(name) {
    this.counters[name] += 1;
    const local = this.counters[name];
    return this.chapter > 0 ? `${this.chapter}.${local}` : String(local);
  }

  renderPlain(text) {
    const trimmed = text.trim();
    if (!trimmed) return "";

    const blocks = trimmed.split(/\n\s*\n/);
    return blocks
      .map((block) => this.renderPlainBlock(block))
      .filter(Boolean)
      .join("\n");
  }

  renderPlainBlock(block) {
    const lines = block
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);

    if (lines.length === 0) return "";

    if (lines.every((line) => line.startsWith("- "))) {
      const items = lines
        .map((line) => `<li>${this.renderInline(line.slice(2).trim())}</li>`)
        .join("\n");
      return `<ul>\n${indent(items, 2)}\n</ul>`;
    }

    const pieces = [];
    let paragraph = [];
    let math = [];

    const flushParagraph = () => {
      if (paragraph.length === 0) return;
      pieces.push(`<p>${this.renderInline(paragraph.join(" "))}</p>`);
      paragraph = [];
    };

    const flushMath = () => {
      if (math.length === 0) return;
      pieces.push(`<div class="math-display">\\[${convertMath(math.join(" "))}\\]</div>`);
      math = [];
    };

    for (const line of lines) {
      if (math.length > 0) {
        if (line.endsWith("$")) {
          math.push(line.slice(0, -1).trim());
          flushMath();
        } else {
          math.push(line);
        }
        continue;
      }

      const oneLineDisplay = line.match(/^\$\s*([\s\S]*)\s*\$$/);
      if (oneLineDisplay) {
        flushParagraph();
        pieces.push(`<div class="math-display">\\[${convertMath(oneLineDisplay[1])}\\]</div>`);
        continue;
      }

      if (line.startsWith("$")) {
        flushParagraph();
        math.push(line.slice(1).trim());
        continue;
      }

      paragraph.push(line);
    }

    flushParagraph();
    flushMath();

    return pieces.join("\n");
  }

  renderInline(text) {
    let out = "";
    let pos = 0;

    while (pos < text.length) {
      const next = text.indexOf("$", pos);
      if (next < 0) {
        out += renderTextInline(text.slice(pos));
        break;
      }

      out += renderTextInline(text.slice(pos, next));
      const close = text.indexOf("$", next + 1);

      if (close < 0) {
        out += renderTextInline(text.slice(next));
        break;
      }

      out += `\\(${convertMath(text.slice(next + 1, close))}\\)`;
      pos = close + 1;
    }

    return out;
  }

  uniqueId(base) {
    const clean = base || "section";
    const count = this.usedIds.get(clean) || 0;
    this.usedIds.set(clean, count + 1);
    return count === 0 ? clean : `${clean}-${count + 1}`;
  }
}

function extractTitle(args) {
  if (!args) return "";
  const titleIndex = args.indexOf("title:");
  if (titleIndex < 0) return "";

  const open = args.indexOf("[", titleIndex);
  if (open < 0) return "";

  const close = findMatching(args, open, "[", "]");
  if (close < 0) return "";

  return args.slice(open + 1, close).trim();
}

function removeFunctionCalls(text, name) {
  let result = "";
  let pos = 0;

  while (pos < text.length) {
    const found = text.indexOf(`#${name}`, pos);
    if (found < 0) {
      result += text.slice(pos);
      break;
    }

    result += text.slice(pos, found);
    let cursor = found + name.length + 1;
    cursor = skipWhitespace(text, cursor);

    if (text[cursor] === "(") {
      const close = findMatching(text, cursor, "(", ")");
      pos = close >= 0 ? close + 1 : cursor;
    } else if (text[cursor] === "[") {
      const close = findMatching(text, cursor, "[", "]");
      pos = close >= 0 ? close + 1 : cursor;
    } else {
      const newline = text.indexOf("\n", cursor);
      pos = newline >= 0 ? newline + 1 : text.length;
    }
  }

  return result;
}

function findMatching(text, openIndex, openChar, closeChar) {
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = openIndex; i < text.length; i += 1) {
    const ch = text[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }

    if (ch === "\"") {
      inString = true;
    } else if (ch === openChar) {
      depth += 1;
    } else if (ch === closeChar) {
      depth -= 1;
      if (depth === 0) return i;
    }
  }

  return -1;
}

function skipWhitespace(text, pos) {
  while (pos < text.length && /\s/.test(text[pos])) pos += 1;
  return pos;
}

function isLineStart(text, pos) {
  return pos === 0 || text[pos - 1] === "\n";
}

function renderTextInline(text) {
  let html = escapeHtml(text);
  html = html.replace(/`([^`]+)`/g, "<code>$1</code>");
  html = html.replace(/\*([^*\n]+)\*/g, "<strong>$1</strong>");
  return html;
}

function convertMath(input) {
  let expr = input.trim();

  expr = expr.replace(/binom\(([^,()]+),\s*([^)]+)\)/g, (_, top, bottom) => {
    return `\\binom{${convertMath(top)}}{${convertMath(bottom)}}`;
  });

  expr = expr.replace(/sum_\(([^)]*)\)\^([A-Za-z0-9_]+)/g, "\\sum_{$1}^{$2}");
  expr = expr.replace(/\^\(([^)]*)\)/g, "^{$1}");
  expr = expr.replace(/_\(([^)]*)\)/g, "_{$1}");
  expr = expr.replace(/\bNN\b/g, "\\mathbb{N}");
  expr = expr.replace(/\bRR\b/g, "\\mathbb{R}");
  expr = expr.replace(/\s+in\s+/g, " \\in ");
  expr = expr.replace(/\bdots\b/g, "\\cdots");
  expr = expr.replace(/\bdot\b/g, "\\cdot");
  expr = expr.replace(/\bcomma\b/g, ",");

  return expr;
}

function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function slugify(text) {
  const ascii = text
    .toLowerCase()
    .replace(/`/g, "")
    .replace(/\$[^$]*\$/g, "")
    .replace(/[^a-z0-9\u4e00-\u9fff]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return ascii || "section";
}

function indent(text, spaces) {
  const prefix = " ".repeat(spaces);
  return text
    .split("\n")
    .map((line) => (line ? prefix + line : line))
    .join("\n");
}

function main() {
  const input = process.argv[2] || path.join("notes", "new.typ");
  const output =
    process.argv[3] ||
    path.join(path.dirname(input), "web", `${path.basename(input, path.extname(input))}.html`);

  const source = fs.readFileSync(input, "utf8");
  const converter = new TypstWebConverter(source);
  const html = converter.convert();

  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, html, "utf8");

  const cssSource = path.join(path.dirname(output), "elegant.css");
  if (!fs.existsSync(cssSource)) {
    const defaultCss = path.join(__dirname, "..", "notes", "web", "elegant.css");
    if (fs.existsSync(defaultCss)) {
      fs.copyFileSync(defaultCss, cssSource);
    }
  }

  console.log(`Wrote ${output}`);
}

main();
