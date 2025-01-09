import os
import sys
import pandas as pd
import yfinance as yf
import yfinance.shared as shared
from datetime import date

def eprint(*args, **kwargs) :
    print(*args, file=sys.stderr, **kwargs)

def stream_out(lhs, rhs) :
	print ('!{}:{}'.format(lhs.replace(" ", "_"), rhs), end='')
	if os.environ.get('DEBUG') :
		eprint (lhs, rhs, sep=":")

if os.environ.get('DEBUG') :
	yf.enable_debug_mode()

tickers = "AAPL"
if len (sys.argv) > 1 :
	tickers = sys.argv[1]

symbols = tickers.split("!")
download = yf.download(symbols, period='1d', group_by='tickers', auto_adjust=True, progress=False)
tickers = yf.Tickers(symbols)

for ticker in symbols :
	success = 0

	stream_out ("ticker", ticker)

	info = tickers.tickers[ticker].info
	fast_info = tickers.tickers[ticker].fast_info

	for column in download[(ticker,)] :
		data = download[(ticker, column)]
		if len(data) > 0 :
			for ts,price in data.items() :
				date = pd.Timestamp(ts)
				stream_out ('date', date.strftime('%m-%d-%Y'))
				stream_out (column, round(price,9))
				success = 1

	for key in info.keys() :
		stream_out (key, info[key])

	for key in fast_info.keys() :
		stream_out (key, fast_info[key])
	
	stream_out ('currency', info['currency'])
	stream_out ('timezone', info['timeZoneShortName'])

	stream_out ('success', success)
