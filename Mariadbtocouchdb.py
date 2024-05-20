import mariadb
import requests
import uuid
import decimal

# Connect to MariaDB
maria_connection = mariadb.connect(
    host="127.0.0.1",
    user="root",
    password="mariadb",
    database="MusicCompDimDB"
)
# Use a dictionary cursor to access columns by name
maria_cursor = maria_connection.cursor(dictionary=True)

# CouchDB URL with partitioned=true parameter
couchdb_url = 'http://moose:mooses@127.0.0.1:5984/c20379081_db?partitioned=true'
# Create a partitioned database using the REST API
response = requests.put(couchdb_url)

# Function to create a document in CouchDB
def create_document(doc_id, doc_type, data):
    # Convert Decimal fields to float for JSON serialization
    for key, value in data.items():
        if isinstance(value, decimal.Decimal):
            data[key] = float(value)
    response = requests.post(f'{couchdb_url}', json={"_id": doc_id, "type": doc_type, "data": data})
    if response.status_code not in [200, 201]:
        print(f"Failed to create document: {response.status_code}, {response.text}")

edition_year_to_id = {}
maria_cursor.execute("SELECT * FROM EditionDim")
for row in maria_cursor:
    edition_id = f"edition:{uuid.uuid4()}"
    edition_year_to_id[row['EditionYear']] = edition_id
    edition_data = {
        "EditionYear": row['EditionYear'],
        "Presenter": row['Presenter']
    }
    create_document(edition_id, "edition", edition_data)


participant_id_to_doc_id = {}
maria_cursor.execute("SELECT * FROM ParticipantDim")
for row in maria_cursor:
    participant_id = row['ParticipantName']
    participant_doc_id = f"participant:{uuid.uuid4()}"
    participant_id_to_doc_id[participant_id] = participant_doc_id
    participant_data = {
        "Name": row['ParticipantName']
    }
    create_document(participant_doc_id, "participant", participant_data)

age_group_id_to_doc_id = {}
maria_cursor.execute("SELECT * FROM AgeGroupDim")
for row in maria_cursor:
    age_group_id = row['AgeGroupID']
    age_group_doc_id = f"agegroup:{uuid.uuid4()}"
    age_group_id_to_doc_id[age_group_id] = age_group_doc_id
    age_group_data = {
        "AgeGroupDescription": row['AgeGroupDescription']
    }
    create_document(age_group_doc_id, "agegroup", age_group_data)



# Function to determine the partition key based on the CountyID
def get_partition_key(county_id):
    if county_id == 1: 
        return "cork"
    elif county_id == 2: 
        return "galway"
    return None


# Process ViewerActivityFact table
maria_cursor.execute("SELECT * FROM ViewerActivityFact WHERE CountyID IN (1, 2)")
for row in maria_cursor:
    partition_key = get_partition_key(row['CountyID'])
    if partition_key is not None:
        doc_id = f"{partition_key}:{uuid.uuid4()}"
        vote_date = row['VoteDate'].strftime("%Y-%m-%d") if row['VoteDate'] else None
        fact_data = {
            "FactKey": row['FactKey'],
            "ViewerID": row['ViewerID'],
            "VoteDate": vote_date,
            "ViewerCategoryID": row['ViewerCategoryID'],
            "VOTEMODE": row['VOTEMODE'],
            "Vote": row['Vote'],
            "Charge": row['Charge'],
            "edition_id": edition_year_to_id.get(row['EditionYear']),
            "participant_id": participant_id_to_doc_id.get(row['ParticipantName']),
            "age_group_id": age_group_id_to_doc_id.get(row['AgeGroupID'])
        }
        create_document(doc_id, "fact", fact_data)
        
# Close MariaDB connection
maria_cursor.close()
maria_connection.close()
