import json
from datetime import datetime, timedelta

import boto3
import pandas as pd

BUCKET = "james-cloud-resume-events"
PREFIX = "events/"
PROFILE = "prod-account"


def get_events(days_back=7):
    """Get events from S3."""
    print("Connecting to S3...")
    session = boto3.Session(profile_name=PROFILE)
    s3 = session.client("s3")
    print("Connected!")

    events = []

    print("Fetching events...")
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days_back)

    for day_offset in range(days_back):
        date = start_date + timedelta(days=day_offset)
        prefix = f"{PREFIX}year={date.year}/month={date.month:02d}/day={date.day:02d}/"

        try:
            response = s3.list_objects_v2(Bucket=BUCKET, Prefix=prefix)

            if "Contents" in response:
                for obj in response["Contents"]:
                    if obj["Key"].endswith(".json"):
                        data = s3.get_object(Bucket=BUCKET, Key=obj["Key"])
                        event = json.loads(data["Body"].read())
                        events.append(event)

        except Exception:
            print(f"No data for {date.date()}")

    print(f"Fetched {len(events)} events.")
    return pd.DataFrame(events)


def analyze(df):
    print("Visitor Analytics")
    print("=" * 50)

    # Convert timestamp
    df["timestamp"] = pd.to_datetime(df["timestamp"])
    df["date"] = df["timestamp"].dt.date

    print(f"Total visits: {len(df)}")
    print(f"Unique IPs: {df['source_ip'].nunique()}")
    print(f"Date range: {df['date'].min()} to {df['date'].max()}")

    print("Visits by Day:")
    print(df.groupby("date").size().to_string())

    # Top referrers
    print("Top Referrers:")
    print(df["referer"].value_counts().head(5).to_string())

    # Geographic analysis
    print("\nVisits by Country:")
    print(df["country"].value_counts().head(10).to_string())

    print("\nVisits by City:")
    print(df["city"].value_counts().head(10).to_string())

    print("\nTop ISPs:")
    print(df["isp"].value_counts().head(5).to_string())


if __name__ == "__main__":
    df = get_events(days_back=2)

    if not df.empty:
        analyze(df)
    else:
        print("No data found!")
