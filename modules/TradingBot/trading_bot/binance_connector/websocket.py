import logging
logger=logging.getLogger()
import websocket
import json
import time
import concurrent.futures
import boto3
import pandas as pd
from strategies.main_strategy import strategy_implement
# import os
# import json

dynamodb_tb = "demo-dynamodb_tb"
dynamo_client = boto3.client('dynamodb', region_name = 'ap-northeast-1')

# Get the best trading pair and timeframe before start websocket
items = dynamo_client.scan(TableName=dynamodb_tb)['Items']
sorted_items = []
for item in items:
    nested_items = {}
    for i,j in item.items():
        nested_items[i] = j['S']
    sorted_items.append(nested_items)
df = pd.DataFrame(sorted_items)
columns = list(df.columns)
columns.remove('Symbol')
columns.remove('TimeFrame')
df[columns] =df[columns].astype(float)

df['score'] = df['Return']*0.4 + df['Win_rate']*0.6 # Get best trading pair by return and win rate
best_trading_pair = df[df['score']==df['score'].max()]
symbol = best_trading_pair['Symbol'].iloc[0]
timeframe = '30m'
logger.info(f"Start trading on {symbol},{timeframe}")

class websocket_connection:
    def __init__(self,testnet):
        if testnet:
            self.ws_url='wss://stream.binancefuture.com/ws'
        else: 
            self.ws_url='wss://stream.binance.com:9443/ws'    
    
        self.ws = None  
        self.id_ws: int = 1
        self.symbol = symbol
        self.timeframe :str = timeframe

        try:
            # Initiate Strategy_implement class to interact with Websocket
            self.strategy_implement = strategy_implement(
                testnet = testnet, 
                symbol = symbol, 
                timeframe= timeframe
            )
        except Exception as e:
            logger.error(f"Failed to initialize Strategy_implement class, error: {e}")

        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                executor.submit(self.start_ws())
        except Exception as e:
            logger.error(f"Failed to start websocket streaming, error: {e}")
        
    def on_error(self, ws, error):
        logger.error(error)

    def on_close(self, ws, close_status_code, close_msg):
        logger.warning("Closing connection")

        try:
            self.Close_ws('UNSUBSCRIBE')
        except Exception as e:
            logger.error(f"Failed to unsubscribe to channel, error: {e}")
        
    def on_open(self, ws):
        logger.warning("Opened connection")
        self.Live_Klines('SUBSCRIBE')
#       self.Live_ticker('ATOMUSDT','SUBSCRIBE')
    
    def start_ws(self):
        self.ws=websocket.WebSocketApp(self.ws_url, on_open=self.on_open, on_close=self.on_close,
                              on_error=self.on_error, on_message=self.on_message)
        while True:
            try:
                self.ws.run_forever()
            except Exception as e:
                logger.error(f"Error in websocket , error: {e}")
            time.sleep(2)
        
    def Close_ws(self, method: str):
        data=dict()
        data['method']=method
        data['params']=[self.symbol.lower()+'@kline_'+self.timeframe]
        data['id']=self.id_ws
        
    def on_message(self, ws, message): 
        candle_data=json.loads(message)['k']
        candle=[candle_data['t'],candle_data['o'],candle_data['h'],candle_data['l'],candle_data['c'],candle_data['x']]      
        self.strategy_implement.new_candle(candle)
        
    def Live_Klines (self, method: str):
        data=dict()
        data['method']=method
        data['params']=[]
        data['params'].append(self.symbol.lower()+ '@kline_'+ self.timeframe)
        # m -> minutes; h -> hours; d -> days; w -> weeks; M -> months
        data['id']=self.id_ws
        try:
            self.ws.send(json.dumps(data))
        except Exception as e:
                logger.error(f"Failed to send json.dumps, error: {e}")
        self.id_ws+=1

