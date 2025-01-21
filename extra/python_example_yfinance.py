import csv
import os
import yfinance as yf
import pandas as pd
import time
import sys
import logging
from warnings import simplefilter

start = time.time()

DEBUG = os.environ.get('DEBUG')

logger = logging.getLogger('yfinance')
logger.setLevel(logging.CRITICAL)
logger.disabled = True
logger.propagate = True

simplefilter(action="ignore", category=pd.errors.PerformanceWarning)

def eprint(*args, **kwargs) :
    print(*args, file=sys.stderr, **kwargs)

def stream_out(lhs, rhs) :
    print ('!{}:{}'.format(lhs.replace(" ", "_"), rhs), end='')
    if DEBUG :
        eprint (lhs, rhs, sep=":")

path_to_file = 'C:\\Users\\kalpesh\\OneDrive\\QuickenStuff\\HELPERS\\'

ticker_list = []
    
if len (sys.argv) > 1 :
    tickers = sys.argv[1]
    ticker_list = tickers.split("!")
else :
    with open(path_to_file + 'tickers.txt', 'r') as csvfile:
        reader = csv.reader(csvfile, delimiter=',')
        for row in reader:
            if row[0]:
                ticker_list.append(row[0].replace ("INDEX:", '^'))
        ticker_list = pd.Series(ticker_list).drop_duplicates().tolist()

if DEBUG :
    yf.enable_debug_mode()

# See https://github.com/ranaroussi/yfinance/blob/main/yfinance/multi.py 
data = yf.download(
        tickers = ticker_list,
        period = '1mo',
        interval = '1d',
        group_by = 'ticker',
        auto_adjust = True,
        prepost = False,
        threads = True,
        proxy = None,
        progress = False,
        keepna = False,
        repair = True
    )

tickers = yf.Tickers(ticker_list)

data.reset_index(inplace=True)
data['Date'] = data['Date'].dt.strftime('%m/%m/%Y')


with open(path_to_file + 'quotes.qif', 'w') as qif,\
    open(path_to_file + 'quicken_quotes.csv', 'w') as quicken,\
    open(path_to_file + 'gnucash_quotes.csv', 'w') as gnucash :

    for ticker in ticker_list :

        close=None
        high=None
        low=None
        volume=None
        date=None
        exchange=None

        info = tickers.tickers[ticker].info

        for i in data.index :

            if (pd.isna(data[ticker]['Close'][i])) :
                continue

            close=data[ticker]['Close'][i]
            high=data[ticker]['High'][i]
            low=data[ticker]['Low'][i]
            volume=data[ticker]['Volume'][i]
            date=data['Date'][i]
            
            exchange=info['exchange']

            quicken.write("{},{},---,{},---,{},{},{},*\n".format (ticker.replace("^", "INDEX:"), close, date, high, low, volume))
            gnucash.write("\"{}\",\"{}\",\"{}\",{},\"{}\"\n".format (exchange, ticker, date, close, "USD"))
            qif.write("!Type:Prices\n\"{}\",{},\"{}\"\n^\n".format(ticker.replace("^", "INDEX:"), close, date))
        
        try:
            info['currency']
            info['timeZoneShortName']
            info['exchange']
            info['date']
            info['last']
        except:
            eprint ("ERROR", "Data not available for {} at this time.".format (ticker), sep=":")
            stream_out ("ticker", ticker)
            stream_out ("success", 0)
        else:
            stream_out ("ticker", ticker)
            stream_out ('currency', info['currency'])
            stream_out ('timezone', info['timeZoneShortName'])
            stream_out ('exchange', info['exchange'])
            stream_out ("date", date)
            stream_out ("last", close)
            stream_out ("success", 1)

# print('It took', time.time()-start, 'seconds.')

