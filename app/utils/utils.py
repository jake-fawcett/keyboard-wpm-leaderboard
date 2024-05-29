import pandas as pd
from azure.core.exceptions import ResourceExistsError
from azure.data.tables import TableClient, UpdateMode
from azure.identity import DefaultAzureCredential
from azure.mgmt.storage import StorageManagementClient

SUBSCRIPTION_ID = "a33b898e-c78f-4532-a747-0598abda68a7"
GROUP_NAME = "keyboard-leaderboard"
STORAGE_ACCOUNT_NAME = "keyboardleaderboard"


def get_table_client():
    credential = DefaultAzureCredential()
    storage_client = StorageManagementClient(credential, SUBSCRIPTION_ID)
    storage_keys = storage_client.storage_accounts.list_keys(GROUP_NAME, STORAGE_ACCOUNT_NAME)
    storage_keys = {v.key_name: v.value for v in storage_keys.keys}
    key = storage_keys["key1"]
    table_client = TableClient.from_connection_string(
        conn_str=f"DefaultEndpointsProtocol=https;AccountName={STORAGE_ACCOUNT_NAME};AccountKey={key};EndpointSuffix=core.windows.net", table_name="keyboardleaderboard"
    )
    return table_client


def get_leaderboard_data():
    table_client = get_table_client()
    my_filter = "PartitionKey eq 'Users'"
    entities = table_client.query_entities(query_filter=my_filter, select=["User", "WPM"])

    pd.set_option("display.width", 1000)
    pd.set_option("colheader_justify", "center")

    leaderboard_df = pd.DataFrame(entities)
    sort = leaderboard_df.sort_values(by=["WPM"], ascending=False)
    tables = sort.to_html(classes="leaderboard", header="true", index=False)
    return tables


def get_or_create_user(table_client, username, keyboard):
    try:
        entity = {"PartitionKey": "Users", "RowKey": f"{username} - {keyboard}".lower(), "User": f"{username} - {keyboard}", "WPM": "0"}
        table_client.create_entity(entity)
    except Exception:
        print(f"""User: {username} already exists!""")
        entity = table_client.get_entity(partition_key="Users", row_key=f"{username} - {keyboard}".lower())
    return entity


def update_user(table_client, user):
    table_client.update_entity(mode=UpdateMode.MERGE, entity=user)


def check_wpm(username, keyboard, wpm):
    table_client = get_table_client()
    user = get_or_create_user(table_client, username, keyboard)
    if int(user["WPM"]) < int(wpm):
        user["WPM"] = wpm
        update_user(table_client, user) 
    return user
