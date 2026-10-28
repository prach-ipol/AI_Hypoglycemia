import os
from pymongo import MongoClient, ASCENDING, DESCENDING

COLLECTIONS = ("users", "login_events", "intake_analyses", "glucose_readings", "food_database", "meal_records", "activity_records", "predictions", "user_preferences", "feedback")

class Database:
    def __init__(self, database):
        self.db = database
    @classmethod
    def from_env(cls):
        uri = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
        client = MongoClient(uri, serverSelectionTimeoutMS=2000)
        database = client[os.getenv("MONGODB_DATABASE", "AI_Hypoglycemia")]
        return cls(database)
    def ping(self):
        self.db.command("ping")
    def initialize(self):
        for name in COLLECTIONS:
            self.db.create_collection(name) if name not in self.db.list_collection_names() else None
        self.db.users.create_index("email", unique=True)
        self.db.users.create_index("contact", unique=True, partialFilterExpression={"contact": {"$type": "string"}})
        for collection in ("glucose_readings", "meal_records", "activity_records", "predictions", "intake_analyses"):
            self.db[collection].create_index([("user_id", ASCENDING), ("timestamp", DESCENDING)])
        self.db.login_events.create_index([("user_id", ASCENDING), ("created_at", DESCENDING)])
        self.db.feedback.create_index([("created_at", DESCENDING)])
        self.db.food_database.create_index("name", unique=True)
        if self.db.food_database.count_documents({}) == 0:
            from .services.foods import load_foods
            foods = load_foods()
            if foods:
                self.db.food_database.insert_many([{k:v for k,v in item.items() if k != "id"} for item in foods])
    def __getattr__(self, name):
        return getattr(self.db, name)
    def __getitem__(self, collection_name):
        return self.db[collection_name]
