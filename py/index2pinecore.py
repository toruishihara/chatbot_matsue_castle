# index_to_pinecone.py
import os, glob
from dotenv import load_dotenv

from langchain_community.document_loaders import TextLoader, PyPDFLoader, WikipediaLoader, WebBaseLoader, CSVLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_text_splitters import CharacterTextSplitter
from langchain_openai import OpenAIEmbeddings
from langchain_pinecone import PineconeVectorStore
from pinecone import Pinecone, ServerlessSpec
from langchain_community.document_loaders import UnstructuredURLLoader

#with open("data/nickname.txt", "rb") as f:
#    raw = f.read(400)
#print(raw[:300])

load_dotenv()
OPENAI_API_KEY   = os.getenv("OPENAI_API_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")

# Optional: set a UA for polite crawling
os.environ.setdefault("USER_AGENT", "MatsueBot/1.0 (+https://example.com)")

# ---- 1) Collect files (both .txt and .pdf) ----
paths = []
paths += glob.glob("data/**/*.txt", recursive=True)
paths += glob.glob("data/**/*.pdf", recursive=True)
paths += glob.glob("data/**/*.csv", recursive=True)

# ---- 2) Load docs with proper loader per type ----
docs = []
for p in paths:
    print(f"Loading: {p}")
    if p.lower().endswith(".pdf"):
        # PyPDFLoader returns one Document per page (metadata has page number)
        loader = PyPDFLoader(p)
        docs.extend(loader.load())
    elif p.lower().endswith(".csv"):
        loader = CSVLoader(p, encoding="utf-8")
        docs.extend(loader.load())
    else:
        loader = TextLoader(p, encoding="utf-8")
        docs.extend(loader.load())

print(f"Loaded {len(docs)} raw documents")

loader = WikipediaLoader(query="松江城", lang="ja", load_max_docs=1)
docs.extend(loader.load())

urls = [
    "https://www.japan-guide.com/e/e5801.html",
    "https://www.matsue-castle.jp/highlight/citadel",
    "https://www.homemate-research-castle.com/useful/16943_tour_024/",
]
loader = UnstructuredURLLoader(urls)
#for url in urls:
#    loader = WebBaseLoader(url)
docs.extend(loader.load())

print(f"Loaded {len(docs)} document segments from {len(paths)} files.")

# ---- 3) Split into chunks (keep some overlap) ----
splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,          # 文字数ベース（300–800が一般的）
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
for i, chunk in enumerate(merged_chunks[:10]):  # 最初の10件だけ
    print("=" * 40)
    print(f"Chunk {i+1}")
    print(f"Source: {chunk.metadata.get('source', 'N/A')}")
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

# ---- 5) Embed + upsert to Pinecone ----
emb = OpenAIEmbeddings(model="text-embedding-3-large", api_key=OPENAI_API_KEY)
vs = PineconeVectorStore.from_documents(
    merged_chunks,
    embedding=emb,
    index_name=index_name
)

print("✅ Uploaded to Pinecone with PDF+TXT support.")

