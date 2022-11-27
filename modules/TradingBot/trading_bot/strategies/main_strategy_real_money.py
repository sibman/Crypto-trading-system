import pandas as pd
import pandas_ta as ta
import awswrangler as wr
import json
import logging 
logger = logging.getLogger()

from binance_connector.binance import binance_connector

class strategy_implement:
    def __init__(self, testnet, symbol, timeframe):
        # Get credential from credential_info.json to interact with Binance APIs 
        f = open("credential_info.json")
        credential_info = json.load(f)
        if testnet:
            credential = credential_info['testnet']
        else:
            credential = credential_info['real']
        
        try:
            self.Binance_connector = binance_connector(
                public_key = credential['public_key'], 
                secret_key= credential['secret_key'], 
                testnet = testnet, 
                symbol = symbol,
                timeframe = timeframe
            )
        except Exception as e:
            logger.error(e)

        # OHLC data
        self.open = []
        self.close = []
        self.high = []
        self.low = []
        self.current = float()

        self.current_timestamp = self.Binance_connector.get_server_time()
        
        #  Query historical price data from Timestream 
        historical_candle_data= self.Binance_connector.get_historical_candles(timeframe)
        for candle in historical_candle_data:
            self.new_candle(candle)
        logger.warning(f"Sucessfully initiate OHLC data")

        # Indicator
        self.ema = pd.Series(dtype='float64')
        self.rsi = pd.Series(dtype='float64')
        self.macd_line = pd.Series(dtype='float64')
        self.signal_line = pd.Series(dtype='float64')

        # Additional parameters
        self.cash: int = 20
        self.entry_timestamp =int()
        self.take_profit: float = 0.04
        self.stop_loss: float = 0.02
        self.ongoing_position: bool = False
        self.filled_status: bool = False
        self.order_id = []
        self.filled_buy_order ={}
        self.filled_sell_order = {}

    
    def new_candle(self, candle):
        ''' 
        This function will be used to update OHLC and calculate indicators when new candle stick is completed
        '''
        if len(candle)==6:
            # Check if candle is closed or not:
            if candle[5]:
                # self.all_candle.append(candles)
                self.open.append(float(candle[1]))
                self.high.append(float(candle[2]))            
                self.low.append(float(candle[3]))
                self.close.append(float(candle[4]))
                self.current=(float(candle[4]))

                # Calculate indicator 
                self.ema = ta.ema(close = pd.Series(self.close), length= 150)# EMA 150
                self.rsi = ta.rsi(close = pd.Series(self.close))
                macd = ta.macd(close=pd.Series(self.close),fast=12,low=26) # MACD with same default setting as tradingview
                self.macd_line =  pd.Series(macd['MACD_12_26_9'])
                self.signal_line = pd.Series(macd['MACDs_12_26_9'])

                # Check buy condition if we are not in position after calculating indicators of new candle
                if not self.ongoing_position:
                    self.check_trade()
                    # self.check_signal()
            else:
                self.current=(float(candle[4]))

            # Check if we are already in position or not. If we are, check price until hit sell condition
            if self.ongoing_position:    
                if not self.filled_status:
                    order_id = self.order_id
                    try:
                        order_info= self.Binance_connector.get_order_status(order_id)
                    except Exception as e:
                        logger.error("Failed to request current order status, error: {e}")
                
                    if order_info['FILLED']:
                        self.filled_status = True
                        self.filled_buy_order['quantity'] = round(order_info['executedQty'], 3)
                        self.filled_buy_order['price'] = round(order_info['price'], 3)
                        self.filled_buy_order['time'] = round(order_info['time'], 3)
                        logger.warning(f"Order has been filled at {pd.to_datetime(order_info['time'])}, price: {order_info['price']}")
                else:
                    self.order_trace(candle[5]) 

        # initiate historical OHLC data 
        elif isinstance(candle[5], str):
            self.open.append(float(candle[1]))
            self.high.append(float(candle[2]))            
            self.low.append(float(candle[3]))
            self.close.append(float(candle[4]))
            self.current=(float(candle[4]))  

    def check_trade(self):
        '''
        Check buy condition and if satisfied, open position
        '''
        check_signal_results= self.check_signal()

        if check_signal_results == 1:
            logger.warning(f"Buy condition is satisfied at {pd.to_datetime(self.current_timestamp)}")
            self.open_position(check_signal_results)
        else:
            logger.warning('Ongoing position: False')
        
    def check_signal(self):
        ema_buy = self.ema.iloc[-1] < self.close[-1]
        rsi_buy = self.rsi.iloc[-1] > 50
        macd_buy = (self.macd_line.iloc[-1] > self.signal_line.iloc[-1]) & (self.macd_line.iloc[-2] < self.signal_line.iloc[-2])
        try:   
            if ema_buy & rsi_buy & macd_buy:
                    return 1     #Long
        except Exception as e:
            logger.warning(f"Insufficient data for indicator, error: {e}.  Please wait a few periods")
            

    def open_position(self,check_signal_result):
        '''
        If buy condition satisfied, place buy limit, stop loss, and take profit orders with order quantity worth $20
        '''
        self.entry_timestamp = self.current_timestamp
        self.ongoing_position == True
        order_side = 'BUY'

        try:
            order_info = self.Binance_connector.place_order(
                order_side = order_side, 
                quantity = self.cash/self.close[-1], 
                type_order = 'MARKET',  
            )
        except Exception as e:
            logger.error("Failed to set up buy orders, error: {e}")
        
        # Check if orders are placed successfully
        if order_info is not None:
            if order_info['status'] == "NEW":
                self.order_id.append(order_info['orderId'])
                logger.warning(f"Successfully placed buy order, waiting until fullfilled!!")
               

    def order_trace(self,closed_candle):
        '''
        Place sell order when hit stoploss or take profit point
        '''
        current_price= self.current    

        buy_price = self.filled_buy_order['price']
        SL_price = round(buy_price * (1-self.stop_loss), 3)
        TP_price = round(buy_price * (1+ self.take_profit), 3) 

        if closed_candle:
            ema_sell = self.ema.iloc[-1] > self.close[-1]
            rsi_buy = self.rsi.iloc[-1] < 50
            macd_buy = (self.macd_line.iloc[-1] < self.signal_line.iloc[-1]) & (self.macd_line.iloc[-2] > self.signal_line.iloc[-2])
            if current_price==SL_price | current_price==TP_price | ema_sell | rsi_buy | macd_buy:
                try:
                    order_info = self.Binance_connector.place_order(
                        order_side = 'SELL', 
                        quantity = self.filled_buy_order['quantity'], 
                        type_order = 'MARKET',  
                    )
                except Exception as e:
                    logger.error("Failed to set up sell orders, error: {e}")
                order_quantity = self.filled_buy_order['quanity']
                logger.warning(f"Profit: {(current_price-buy_price)*order_quantity}")
                

        if not closed_candle:
            if current_price==SL_price | current_price==TP_price:
                try:
                    order_info = self.Binance_connector.place_order(
                        order_side = 'SELL', 
                        quantity = self.filled_buy_order['quantity'], 
                        type_order = 'MARKET',  
                    )
                except Exception as e:
                    logger.error("Failed to set up sell orders, error: {e}")  
                  
        self.ongoing_position = False
        self.filled_status = False


