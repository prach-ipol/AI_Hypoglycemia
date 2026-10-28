import csv, os

NUTRIENT_FIELDS = {
    "Calories (kcal)": "Calories (kcal)",
    "Carbohydrates (g)": "Carbohydrates (g)",
    "Protein (g)": "Protein (g)",
    "Fats (g)": "Fats (g)",
    "Free Sugar (g)": "Free Sugar (g)",
    "Fibre (g)": "Fibre (g)",
    "Sodium (mg)": "Sodium (mg)",
    "Calcium (mg)": "Calcium (mg)",
    "Iron (mg)": "Iron (mg)",
    "Vitamin C (mg)": "Vitamin C (mg)",
    "Folate (µg)": "Folate (µg)",
}

def _nutrients(row):
    values = {}
    for source, label in NUTRIENT_FIELDS.items():
        # The provided CSV has a mojibake folate header; accept either spelling.
        raw = row.get(source)
        if raw is None and label == "Folate (µg)":
            raw = next((v for k, v in row.items() if k.startswith("Folate")), None)
        try: values[label] = float(raw) if raw not in (None, "") else None
        except (ValueError, TypeError): values[label] = None
    return values

def load_foods(path=None):
    path = path or os.getenv("FOOD_CSV_PATH", "../Indian_Food_Nutrition_Processed.csv")
    path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", path)) if not os.path.isabs(path) else path
    foods = []
    if not os.path.exists(path): return foods
    with open(path, newline="", encoding="utf-8-sig") as f:
        for i, row in enumerate(csv.DictReader(f)):
            try:
                name = row["Dish Name"].strip()
                nutrients = _nutrients(row)
                carbs = nutrients["Carbohydrates (g)"]
                if name and carbs is not None and carbs >= 0:
                    foods.append({"id": str(i + 1), "name": name, "category": "Indian food", "serving_unit": "100 g", "reference_grams": 100, "carbohydrates_per_100g": carbs, "nutrients_per_100g": nutrients, "source": "Indian_Food_Nutrition_Processed.csv", "notes": "Nutrition values are estimates; preparation and serving size vary."})
            except (KeyError, ValueError): continue
    return foods

def analyze_intake(food_name, portion_grams, intake_time, foods):
    import re
    if not isinstance(food_name, str) or not food_name.strip(): raise ValueError("Intake or food name is required")
    if not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", str(intake_time or "")):
        raise ValueError("Time must use 24-hour HH:MM format")
    try: grams = float(portion_grams)
    except (TypeError, ValueError): raise ValueError("Portion must be a number in grams")
    if grams <= 0 or grams > 5000: raise ValueError("Portion must be from 0.01 to 5000 grams")
    match = next((f for f in foods if f["name"].casefold() == food_name.strip().casefold()), None)
    if not match: raise ValueError("Select a food item from the search results")
    multiplier = grams / 100
    nutrients = {label: (round(value * multiplier, 2) if value is not None else None) for label, value in match["nutrients_per_100g"].items()}
    return {"intake_name": match["name"], "intake_time": intake_time, "portion_grams": grams, "nutrition": nutrients, "source": match["source"], "is_estimate": True}

def calculate(items, foods):
    by_id = {food["id"]: food for food in foods}
    result, total = [], 0.0
    for item in items:
        food = by_id.get(str(item.get("food_id")))
        grams = float(item.get("portion_grams", 0))
        if not food or grams <= 0 or grams > 5000: raise ValueError("Choose a listed food and a portion from 0.01 to 5000 grams")
        carbs = round(food["carbohydrates_per_100g"] * grams / 100, 2)
        result.append({"food_id": food["id"], "name": food["name"], "portion_grams": grams, "estimated_carbohydrates_g": carbs})
        total += carbs
    if not result: raise ValueError("At least one food item is required")
    return {"items": result, "total_estimated_carbohydrates_g": round(total, 2), "is_estimate": True}
