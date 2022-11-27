import logging
logging.basicConfig(level = logging.INFO)
logger = logging.getLogger()
import pandas as pd
import numpy as np
import requests
from urllib.parse import urlencode
import hmac
import hashlib

class binance_connector:
    def __init__(self, public_key: str, secret_key: str, testnet: bool, symbol: str, timeframe :str):
        if testnet:
            self.base_url='https://testnet.binancefuture.com'
        else: 
            self.base_url='https://api.binance.com'

        # self.Strategy_implement = Strategy_implement()
        self.symbol: str = symbol
        self.timeframe: str = timeframe
        self.public_key = public_key
        self.secret_key = secret_key
        self.headers= {'X-MBX-APIKEY': self.public_key} 
        self.Initial_historical_interval :int = 365  # 7 days

        self.id_ws: int = 1


        # self.leverage: int = 15
        # self.marginType: str = 'ISOLATED'
   
        logger.warning('Initialized crypto bot successfully')    
        self.current_timestamp = self.get_server_time()

        # self.ws = None        
        # self.start_ws()
        # t=Thread(target=self.start_ws)
        # t.start()
    
    def signature(self, data):
        return hmac.new(self.secret_key.encode(), urlencode(data).encode(), hashlib.sha256).hexdigest()
        
    def make_requests(self, method: str, endpoint:  str, data: dict):
        
        if method == 'get':
            response = requests.get(self.base_url+endpoint,params=data, headers=self.headers)
        elif method == 'post':
            response = requests.post(self.base_url+endpoint,params=data, headers=self.headers)
        elif method == 'delete':
            response = requests.delete(self.base_url+endpoint,params=data, headers=self.headers)
        else: 
            raise ValueError()

        return response.json()             

    def get_server_time(self):
        data = dict()
        servertime= self.make_requests('get','/api/v3/time',data)
        return (int(servertime['serverTime']))

    def Check_order_status(self,orderID):
        order_info = self.get_order_status(orderID)

        if order_info is not None:
            if order_info['status'] == "FILLED":
                Entry_price = order_info['avgPrice']
                return Entry_price

    def get_order_status(self, order_id):
        data = dict()
        data['timestamp'] = self.current_timestamp
        data['symbol'] = self.symbol
        data['orderId'] = order_id
        data['signature'] = self._generate_signature(data)

        order_status = self.make_requests("get", "/api/v3/order", data)
        return order_status

    def place_order(self,order_side,quantity,type_order,price=None,time_in_force=None,stopPrice=None):
        data=dict()
        data['symbol']=self.symbol
        data['side']=order_side
        data['quantity']=quantity
        data['type']=type_order # LIMIT, MARKET,STOP, STOP_MARKET, TAKE_PROFIT, TAKE_PROFIT_MARKET, TRAILING_STOP_MARKET

        if price is not None:
            data['price']=price

        if time_in_force is not None:
            data['timeInForce']=time_in_force  
            # GTC - Good Till Cancel
            # IOC - Immediate or Cancel
            # FOK - Fill or Kill
            # GTX - Good Till Crossing (Post Only)   
        
        if stopPrice is not None:
            data['stopPrice']=stopPrice

        data['timestamp']= self.current_timestamp
        data['signature']= self.signature(data)    

        order_data= self.make_requests('post','/api/v3/order',data)
        return order_data
        
    def cancel_order(self,orderID):
        data=dict()
        data['symbol']= self.symbol
        data['orderID']= orderID
        data['timestamp']= self.current_timestamp
        data['signature']= self.signature(data)

        cancel_data= self.make_requests('delete','/api/v3/order',data)
        return cancel_data

    def get_historical_candles(self,interval):
        if interval[-1] == 'm':
            unix_interval = 60000 * int(interval[:-1])     
        elif interval[-1] == 'h':
            unix_interval = 60000 * 60 * int(interval[:-1])    
        elif interval[-1] == 'd':
            unix_interval = 60000 * 60 * 24 * int(interval[:-1])

        data=dict()
        data['interval']=self.timeframe
        data['symbol']=self.symbol
        data['startTime']= self.current_timestamp - 200 * unix_interval
        data['endTime']=self.current_timestamp - unix_interval
        data['limit']=1000

        historical_candle_data=self.make_requests('get','/api/v3/klines',data)
        if historical_candle_data is not None:
            return historical_candle_data



