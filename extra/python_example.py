import os
import sys
import pandas as pd
import yfinance as yf
import yfinance.shared as shared
from datetime import date

today = date.today()

def eprint(*args, **kwargs) :
    print(*args, file=sys.stderr, **kwargs)

def stream_out(lhs, rhs) :
	print ('!{}:{}'.format(lhs.replace(" ", "_"), rhs), end='')
	if os.environ.get('DEBUG') :
		eprint (lhs, rhs, sep=":")

def main() -> int:
	
	if os.environ.get('DEBUG') :
		yf.enable_debug_mode()

	tickers = "^DJI!BK"
	if len (sys.argv) > 1 :
		tickers = sys.argv[1]

	symbols = tickers.split("!")
	tickers = yf.Tickers(symbols)

	for ticker in tickers.tickers :
		success = 0

		stream_out ("ticker", ticker)
		stream_out ("isin", tickers.tickers[ticker].isin)
		
		info = tickers.tickers[ticker].info
		for key,value in sorted(info.items()) :
			stream_out (key, value)

		hist = tickers.tickers[ticker].history(period='1mo', auto_adjust=True)

		# for stamp in hist.index :
		# for attrib in hist :
		sf = hist['Close']
		for ts,price in sf.items() :
			date = pd.Timestamp(ts)
			stream_out ('isodate', ts)
			stream_out ('date', date.strftime('%m/%d/%Y'))
			stream_out ('close', round(price,9))
			success = 1

		fast_info = tickers.tickers[ticker].fast_info
		for key,value in sorted(fast_info.items()) :
			stream_out (key, value)
			if "lastprice" in key.lower():
				stream_out ("last", round(value,9))
				stream_out ("date", today)
				success = 1

		if ticker in shared._ERRORS :
			stream_out ("error", shared._ERRORS[ticker])

		stream_out ("success", success)
		
	return 0

if __name__ == '__main__' :
	sys.exit(main())
