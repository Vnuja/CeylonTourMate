from icrawler.builtin import GoogleImageCrawler
import os

# Food list with search terms
foods = {
    "kottu_roti": "kottu roti sri lanka food",
    "kiribath": "kiribath sri lanka milk rice",
    "pol_sambol": "pol sambol sri lanka coconut",
    "string_hoppers": "string hoppers sri lanka idiyappam",
    "hoppers": "hoppers appam sri lanka",
    "pittu": "pittu sri lanka food",
    "dhal_curry": "dhal curry sri lanka lentil",
    "pizza": "pizza margherita top view",
    "burger": "beef burger top view",
    "fried_rice": "fried rice top view"
}

base_folder = "training_data"

for food_name, search_term in foods.items():
    save_path = os.path.join(base_folder, food_name)
    print(f"\nDownloading images for: {food_name}")
    
    crawler = GoogleImageCrawler(storage={"root_dir": save_path})
    crawler.crawl(keyword=search_term, max_num=10)
    
    print(f"Done! Images saved to {save_path}")

print("\n All images downloaded!")
