# simple_md.py
import re
from typing import List, Dict
from langchain_core.documents import Document

import re, unicodedata

def normalize_md(md: str) -> str:
    # 1) Unicode normalize (keeps width consistent; try NFC first, NFKC if you want to fold widths)
    md = unicodedata.normalize("NFC", md)
    # 2) Newlines to LF
    md = md.replace("\r\n", "\n").replace("\r", "\n")
    # 3) Replace NBSP and ideographic spaces with ASCII space
    md = md.replace("\u00A0", " ").replace("\u3000", " ")
    # 4) Ensure a space after leading #'s in headers: "###Title" -> "### Title"
    md = re.sub(r"(?m)^(#{1,6})(\S)", r"\1 \2", md)
    # 5) Remove trailing #'s at end of header lines (e.g., "## Title ##")
    md = re.sub(r"(?m)^(#{1,6}\s+.*?)[ \t]*#+[ \t]*$", r"\1", md)
    # 6) Strip leading indentation on header lines (protects against indented headers)
    md = re.sub(r"(?m)^\s+(#{1,6}\s+)", r"\1", md)
    return md

def scan_suspicious(md: str):
    bads = {
        "NBSP": "\u00A0",
        "IDEOGRAPHIC_SPACE": "\u3000",
        "FULLWIDTH_PERIOD": "。",
        "FULLWIDTH_COMMA": "、",
        "ZWSP": "\u200B",
    }
    found = {}
    for name, ch in bads.items():
        idxs = [i for i, c in enumerate(md) if c == ch]
        if idxs:
            found[name] = idxs[:20]  # first 20 occurrences
    # Headers missing space after #'s
    no_space_headers = re.findall(r"(?m)^(#{1,6})(\S)", md)
    return found, bool(no_space_headers)

import re
from typing import List, Dict
from langchain_core.documents import Document  # or langchain.schema.Document

def normalize_md(text: str) -> str:
    # minimal normalizer (optional)
    return text.replace("\r\n", "\n").replace("\r", "\n")

def load_markdown_with_headers(path: str) -> List[Document]:
    with open(path, "r", encoding="utf-8") as f:
        text = normalize_md(f.read())

    header_re = re.compile(r'^(#{1,3})\s+(.*)$')
    docs: List[Document] = []

    current_meta: Dict[str, str] = {"source": path}
    current_lines: List[str] = []

    def breadcrumb(meta: Dict[str, str]) -> str:
        parts = [meta.get("h1"), meta.get("h2"), meta.get("h3")]
        return " › ".join([p for p in parts if p])

    def flush():
        if not current_lines:
            return
        body = "\n".join(current_lines).strip()
        if not body:
            current_lines.clear()
            return
        meta = dict(current_meta)  # copy
        meta["path"] = breadcrumb(current_meta)
        docs.append(Document(page_content=body, metadata=meta))
        current_lines.clear()

    for ln in text.split("\n"):
        m = header_re.match(ln)
        if m:
            # close previous section
            flush()

            level = len(m.group(1))
            title = m.group(2).strip()

            if level == 1:
                # reset to just source + h1
                current_meta = {"source": path, "h1": title}
            elif level == 2:
                # keep source + h1, replace h2/h3
                keep = {"source": current_meta.get("source"), "h1": current_meta.get("h1")}
                current_meta = {k: v for k, v in keep.items() if v}
                current_meta["h2"] = title
            else:  # level == 3
                # keep source + h1 + h2, set h3
                keep = {
                    "source": current_meta.get("source"),
                    "h1": current_meta.get("h1"),
                    "h2": current_meta.get("h2"),
                }
                current_meta = {k: v for k, v in keep.items() if v}
                current_meta["h3"] = title

            # include the header line in the content of that section
            current_lines.append(ln)
        else:
            current_lines.append(ln)

    flush()
    return docs

def load_markdown_with_headers2(path: str) -> List[Document]:
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    
    text = normalize_md(text)

    lines = text.split("\n")
    header_re = re.compile(r'^(#{1,3})\s+(.*)$')

    docs = []
    current_meta: Dict[str, str] = {"source": path}
    current_lines: List[str] = []

    def flush():
        if current_lines:
            body = "\n".join(current_lines).strip()
            if body:
                docs.append(Document(page_content=body, metadata=current_meta.copy()))
            current_lines.clear()

    for ln in lines:
        m = header_re.match(ln)
        if m:
            flush()
            level, title = len(m.group(1)), m.group(2).strip()
            if level == 1:
                current_meta["h1"] = title
            elif level == 2:
                current_meta["h2"] = title
            elif level == 3:
                current_meta["h3"] = title
            current_lines.append(ln)
        else:
            current_lines.append(ln)
    flush()

    return docs


# --------------- TEST CODE ---------------
#if __name__ == "__main__":
#    path = "data/textbook.md"
#    with open(path, "r", encoding="utf-8") as f:
#        text = f.read()
#    fixed = normalize_md(text)
#    found, bad_headers = scan_suspicious(text)
#    print(found, "headers_missing_space?" , bad_headers)
#    docs = load_markdown_with_headers(path)
#    print(f"Found {len(docs)} sections.\n")
#    for i, d in enumerate(docs):
#        print(f"--- Section {i} ---")
#        print(f"Metadata: {d.metadata}")
#        print(f"Content:\n{d.page_content[:200]}...\n")
