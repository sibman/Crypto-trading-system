import pandas as pd
import numpy as np
import concurrent.futures
import pandas_ta as ta
import awswrangler as wr
import boto3
pd.options.mode.chained_assignment = None

# Get list of symbol name available in datalake
symbol_list = wr.s3.read_json(path='s3://bucket-phrase-1/top_cap.json')[0].values.tolist()[0:10]
interval = ['15m','1h','4h','1d']

# Define the resources on AWS
glue_catalog_tb = 'demo_catalog_tb'
glue_catalog_db = 'demo_catalog_db'
ts_tb = 'demo-ts-tb'
ts_db = 'demo-ts-db'
bucket = 'bucket-phrase-2'
my_session = boto3.Session(region_name="ap-northeast-1")
s3_client = boto3.client('s3')

# Get information of all historical price objects stored in datalake
result = s3_client.list_objects_v2(Bucket=bucket)['Contents']

def get_latest_timestamp(result,symbol):
    datetime_dict = {idx:i['LastModified'] for idx,i in enumerate(result) if symbol in i['Key']}
    datetime_list = list(datetime_dict.values())
    datetime_list.sort()
    try:
        latest_datetime = datetime_list[-2]
        for idx, j in datetime_dict.items(): 
            if j == latest_datetime:
                return int(result[idx]['Key'].replace('/','.').split('.')[1][0:13]) + 60000
    except:
        if len(datetime_list) <= 1:
            return 1500000000000
            

def get_read_timestamp(last_ts,interval):
    start_ts_interval = 365
    seconds_per_unit = {
        "m": 60,
        "h": 60 * 60,
        "d": 24 * 60 * 60,
        "w": 7 * 24 * 60 * 60,
    }
    start_ts = last_ts - start_ts_interval* (int(interval[:-1]) * seconds_per_unit[interval[-1]] * 1000)
    return interval,start_ts

def sql_generator(start_ts_list):
    base_sql = f"""
        SELECT *
            FROM {glue_catalog_tb}
        WHERE 
    """
    first_iterate = True
    for symbol,ts_dict in start_ts_list.items():
        for timeframe,ts in ts_dict.items():
            if first_iterate:
                base_sql += (f" (par='{symbol}' and time >= {ts} and interval ='{timeframe}')")
                first_iterate = False
            else:
                base_sql += (f" or (par='{symbol}' and time >= {ts} and interval ='{timeframe}')")
    return base_sql

def write_timestream(df,dimensions_cols):
    my_session = boto3.Session(region_name="ap-northeast-1")
    wr.timestream.write(
        df=df,
        database=ts_db,
        table=ts_tb,
        time_col="time",
        measure_col = 'close',
        dimensions_cols = dimensions_cols,
        boto3_session=my_session,
    )    

def indicator(df,write_timestamp):
    #Trend Indicators (50EMA and 200EMA)
    df['EMA50'] = ta.ema(df['close'], length = 50)
    df['EMA200'] = ta.ema(df['close'], length = 200)

    #Momentum Indicators (MACD, RSI)
    df['RSI'] = ta.rsi(close = df['close']).round(decimals=2)

    #Volume Indicators (MFI, OBV)
    df['MFI'] = ta.mfi(
        high = df['high'], 
        low = df['low'],
        close = df['close'], 
        volume = df['volume']
    )
    df['OBV'] = ta.obv(
        close = df['close'], 
        volume = df['volume']
    )
    df = df[df['time']>write_timestamp]
    df['time'] = pd.to_datetime(df['time'],unit='ms') + pd.Timedelta(hours = 7)
    dimensions_cols = list(df.columns)[1:]
    dimensions_cols.remove('close')
    
    # Write data to timestream database
    write_timestream(df,dimensions_cols)

# Get the start timestamp for each timeframe of each symbol before querying timeseries data from datalake
start_ts_list = {}
for symbol in symbol_list:
    start_ts_dict = {}
    latest_ts = get_latest_timestamp(result,symbol)
    start_ts_dict['write_timestamp'] = latest_ts
    for timeframe in interval:
        response =  get_read_timestamp(latest_ts,timeframe)
        start_ts_dict[response[0]] = response[1]
    start_ts_list[symbol] = start_ts_dict

# Query enough data (last 365 points for each timeframe) to perform indicator calculation and write to timestream database
df = wr.athena.read_sql_query(
    sql=sql_generator(start_ts_list), 
    ctas_approach=False,
    database=glue_catalog_db,
    data_source='AwsDataCatalog',
    boto3_session=my_session,
    keep_files=False
)

# Perform indicator calculation and store all data timestream database
for partition_keys,par_df in df.groupby(['par','interval']):
    with concurrent.futures.ProcessPoolExecutor() as executor:
        write_df = df[(df['par']==partition_keys[0]) & (df['interval']==partition_keys[1])]
        write_timestamp = start_ts_list[partition_keys[0]]['write_timestamp'] 
        executor.submit(indicator(write_df,write_timestamp))




# from awsglue.dynamicframe import DynamicFrame

# dynamic_df = glueContext.create_dynamic_frame.from_catalog(
#     database = "demo_catalog_db",
#     table_name = "demo_catalog_tb"
# ) 
    
# # Convert to Pandas df
# from pyspark.sql import functions as F
# spark_df = dynamic_df.toDF()

# from pyspark.sql.types import TimestampType
# spark_df = spark_df.select('*', (F.from_unixtime(F.col("time")/1000).alias("timestamp")).cast(TimestampType())).drop('time')