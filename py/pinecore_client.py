from pinecone import Pinecone
import os
from dotenv import load_dotenv
from langchain_pinecone import PineconeVectorStore
from langchain_openai import OpenAIEmbeddings
from langchain.chains import RetrievalQA
from langchain_openai import ChatOpenAI

load_dotenv()
pc = Pinecone(api_key=os.environ["PINECONE_API_KEY"])

index = pc.Index("matsue-castle")
stats = index.describe_index_stats()
print("describe_index_stats:", stats)
emb = OpenAIEmbeddings(model="text-embedding-3-large")

vectorstore = PineconeVectorStore.from_existing_index(
    index_name="matsue-castle",
    embedding=emb
)

retriever = vectorstore.as_retriever(search_kwargs={"k": 3})

qa = RetrievalQA.from_chain_type(
    llm=ChatOpenAI(model="gpt-4o-mini"),
    retriever=retriever,
    chain_type="stuff"
)

result = qa.run("松江城の別名は？")
print("RetrievalQA Answer:", result)

query = "松江城の別名は？"
vector = emb.embed_query(query)

res = index.query(
    vector=vector,
    top_k=3,
    include_metadata=True
)

print("embed_query:", query)

if res.matches:
    for i, match in enumerate(res.matches, start=1):
        text = match.metadata.get("text", "") if match.metadata else ""
        print(f"Match {i}: score={match.score:.4f}")
        print("Text:", text[:120])  # print first 120 chars
        print("-" * 40)
else:
    print("No matches found")

