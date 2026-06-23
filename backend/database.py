import os
import certifi
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv

load_dotenv()

def get_db():
    uri = os.getenv("MONGODB_URI")
    db_name = os.getenv("MONGODB_DB", "invernadero_g19")
    client = MongoClient(uri, server_api=ServerApi("1"), tlsCAFile=certifi.where())
    return client[db_name]
