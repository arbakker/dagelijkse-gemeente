#!/usr/bin/env python3
import os
from posixpath import basename
import tweepy
from datetime import date
import json

CONSUMER_KEY = os.getenv('CONSUMER_KEY')
CONSUMER_SECRET = os.getenv('CONSUMER_SECRET')
ACCESS_TOKEN = os.environ.get('ACCESS_TOKEN')
ACCESS_TOKEN_SECRET = os.environ.get('ACCESS_TOKEN_SECRET')

if not CONSUMER_KEY:
    print(f"CONSUMER_KEY not set as environmental variable")
    exit(1)
if not CONSUMER_SECRET:
    print(f"CONSUMER_SECRET not set as environmental variable")
    exit(1)
if not ACCESS_TOKEN:
    print(f"ACCESS_TOKEN not set as environmental variable")
    exit(1)
if not ACCESS_TOKEN_SECRET:
    print(f"ACCESS_TOKEN_SECRET not set as environmental variable")
    exit(1)

# Authenticate to Twitter
auth = tweepy.OAuthHandler(CONSUMER_KEY, CONSUMER_SECRET)
auth.set_access_token(ACCESS_TOKEN, ACCESS_TOKEN_SECRET)

today = date.today()
date_string = today.strftime("%Y-%m-%d")
schedule = json.load(open('./schedule.json', 'r'))
gm_code = schedule[date_string]

# Create API object
api = tweepy.API(auth)
basedir = "../atlas/maps/"
filename = f"{basedir}{gm_code}.png"
message = f"Gemeente {gm_code}: https://arbakker.github.io/dagelijkse-gemeente-bot/#gmcode={gm_code}"
api.update_with_media(filename, status=message)
print("tweet send successfully")
