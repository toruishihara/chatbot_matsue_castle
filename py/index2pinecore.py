import sys, os, glob
import re
sys.path.append(os.path.join(os.path.dirname(__file__), "."))  # add current folder
from langchain_core.documents import Document
from dotenv import load_dotenv

from langchain_community.document_loaders import TextLoader, PyPDFLoader, WikipediaLoader, WebBaseLoader, CSVLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_text_splitters import MarkdownHeaderTextSplitter, RecursiveCharacterTextSplitter
from langchain_text_splitters import CharacterTextSplitter
from langchain_openai import OpenAIEmbeddings
from langchain_pinecone import PineconeVectorStore
from pinecone import Pinecone, ServerlessSpec
from langchain_community.document_loaders import UnstructuredURLLoader
from typing import Dict, List, Optional
from uuid import uuid5, NAMESPACE_URL
from md import load_markdown_with_headers

def strip_furigana(text: str) -> str:
    # 例: 「大 おお 海 み 崎 さき 石」 → 「大海崎石」
    # 1) 「漢字 空白 かな」の繰り返しを落とす
    pat1 = re.compile(r'([一-龠々〆ヶ])\s*[ぁ-んァ-ンー]+\s*')
    text = pat1.sub(r'\1', text)

    # 2) 括弧付きルビ「漢字（かな）」や「漢字(かな)」を落とす
    pat2 = re.compile(r'([一-龠々〆ヶ]+)[（(][ぁ-んァ-ンー]+[)）]')
    text = pat2.sub(r'\1', text)

    # 3) 連続スペース縮約
    text = re.sub(r'[ \t]+', ' ', text)
    return text

def load_pdf_strip_ruby(path: str):
    loader = PyPDFLoader(path)
    docs = loader.load()
    cleaned = []
    for d in docs:
        text = strip_furigana(d.page_content)  # 1) の関数
        print("Original:", d.page_content[:100])
        print("Cleaned:", text[:100])
        cleaned.append(Document(page_content=text, metadata=d.metadata))
    return cleaned

def sanitize_meta(m: dict) -> dict:
    out = {}
    for k, v in (m or {}).items():
        if v is None:
            continue  # drop nulls entirely

        # --- normalize key names (optional, Pinecone prefers short lowercase)
        key = str(k).strip().lower()

        # --- primitive types
        if isinstance(v, (str, bool, int, float)):
            # strip whitespace from strings, skip empty strings
            if isinstance(v, str):
                v = v.strip()
                if not v:
                    continue
            out[key] = v

        # --- list types
        elif isinstance(v, list):
            # only allow list[str], coercing to strings
            vals = [str(x).strip() for x in v if x not in (None, "")]
            if vals:
                out[key] = vals

        # --- fallback: coerce everything else to string
        else:
            val = str(v).strip()
            if val:
                out[key] = val

    return out

load_dotenv()
print("USER_AGENT:", os.getenv("USER_AGENT"))

OPENAI_API_KEY   = os.getenv("OPENAI_API_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
USER_AGENT = os.getenv("USER_AGENT")

# ---- 1) Collect files (both .txt and .pdf) ----
paths = []
paths += glob.glob("data/**/*.md", recursive=True)
paths += glob.glob("data/**/*.pdf", recursive=True)
paths += glob.glob("data/**/*.csv", recursive=True)
paths += glob.glob("data/**/*.txt", recursive=True)

# ---- 2) Load docs with proper loader per type ----
docs = []
for p in paths:
    print(f"Loading: {p}")
    if p.lower().endswith(".pdf"):
        # PyPDFLoader returns one Document per page (metadata has page number)
        docs.extend(load_pdf_strip_ruby(p))
    elif p.lower().endswith(".csv"):
        loader = CSVLoader(p, encoding="utf-8")
        docs.extend(loader.load())
    elif p.endswith(".md") or p.endswith(".markdown"):
        md_docs = load_markdown_with_headers(p)
        docs.extend(md_docs)
    else:
        loader = TextLoader(p, encoding="utf-8")
        docs.extend(loader.load())

print(f"Loaded {len(docs)} raw documents")

loader = WikipediaLoader(query="松江城", lang="ja", load_max_docs=1)
docs.extend(loader.load())
loader = WikipediaLoader(query="日本の城", lang="ja", load_max_docs=1)
docs.extend(loader.load())
loader = WikipediaLoader(query="天守", lang="ja", load_max_docs=1)
docs.extend(loader.load())
loader = WikipediaLoader(query="現存天守", lang="ja", load_max_docs=1)
docs.extend(loader.load())

loader = WikipediaLoader(query="Matsue Castle", lang="en", load_max_docs=1)
docs.extend(loader.load())
loader = WikipediaLoader(query="Japanese castle", lang="en", load_max_docs=1)
docs.extend(loader.load())
loader = WikipediaLoader(query="Tenshu", lang="en", load_max_docs=1)
docs.extend(loader.load())

urls = [
    "https://www.japan.travel/en/spot/933/",
    "https://www.matsue-castle.jp/highlight/citadel",
    "https://www.homemate-research-castle.com/useful/16943_tour_024/",
    "https://www.kankou-shimane.com/en/destinations/9289",
    "https://www.kanpai-japan.com/matsue/castle"
]
loader = UnstructuredURLLoader(urls)
#for url in urls:
#    loader = WebBaseLoader(url)
docs.extend(loader.load())

print(f"Loaded {len(docs)} document segments from {len(paths)} files.")

# ---- 3) Split into chunks (keep some overlap) ----
splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,          # 文字数ベース（300-800が一般的）
    chunk_overlap=50,        # コンテキストを維持するための重なり
    separators = ["\n\n", "\n", "。", "、", " "],
    keep_separator=False  # 優先順位つき
)

first_chunks = splitter.split_documents(docs)

# Merge too-small chunks (<50 chars) with the previous one
merged_chunks = []
for chunk in first_chunks:
    if merged_chunks and len(chunk.page_content) < 50:
        merged_chunks[-1].page_content += " " + chunk.page_content
    else:
        merged_chunks.append(chunk)

print(f"Split into {len(merged_chunks)} chunks.")
# 各チャンクを確認
for i, chunk in enumerate(merged_chunks[:99]):  # 最初の10件だけ
    print("=" * 40)
    print(f"Chunk {i+1}")
    print(f"Source: {chunk.metadata.get('source', 'N/A')}")
    print(f"h1: {chunk.metadata.get('h1', 'N/A')}")
    print(f"h2: {chunk.metadata.get('h2', 'N/A')}")
    print(f"h3: {chunk.metadata.get('h3', 'N/A')}")
    print(f"Content:\n{chunk.page_content[:200]}")  # 最初の200文字だけ表示

# ---- 4) Pinecone index (create if missing) ----
pc = Pinecone(api_key=PINECONE_API_KEY)
index_name = "matsue-castle"

# Delete if exists
if index_name in pc.list_indexes().names():
    pc.delete_index(index_name)
    print(f"Deleted index: {index_name}")

# Create index if it does not exist
if index_name not in pc.list_indexes().names():
    pc.create_index(
        name=index_name,
        dimension=3072,         # embedding size for text-embedding-3-large
        metric="cosine",
        spec=ServerlessSpec(
            cloud="aws",        # or "gcp"
            region="us-east-1"  # pick your Pinecone region
        )
    )

# Apply to every doc before from_documents()
for d in merged_chunks:
    d.metadata = sanitize_meta(d.metadata)

# ---- 5) Embed + upsert to Pinecone ----
emb = OpenAIEmbeddings(model="text-embedding-3-large", api_key=OPENAI_API_KEY)
vs = PineconeVectorStore.from_documents(
    merged_chunks,
    embedding=emb,
    index_name=index_name
)

print(" Uploaded to Pinecone with PDF+TXT support.")

pc = Pinecone(api_key=PINECONE_API_KEY)
idx = pc.Index(index_name)

# Grab one inserted id from the LangChain store if you kept them,
# otherwise query and inspect the first match:
res = idx.query(
    vector=[0.0]*3072,  # or use a real embedding to query
    top_k=1,
    include_metadata=True
)
print(res.matches[0].metadata)  # Expect 'h1','h2','h3' when present
