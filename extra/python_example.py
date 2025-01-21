import os
import sys
import pandas as pd
import yfinance as yf
import yfinance.shared as shared
from datetime import date

today = date.today()
# path_to_file = 'C:\\Users\\kalpesh\\OneDrive\\QuickenStuff\\HELPERS\\'

def eprint(*args, **kwargs) :
    print(*args, file=sys.stderr, **kwargs)

def stream_out(lhs, rhs) :
	print ('!{}:{}'.format(lhs.replace(" ", "_"), rhs), end='')
	if os.environ.get('DEBUG') or os.environ.get('FQ_DEBUG') :
		eprint (lhs, rhs, sep=":")

def main() -> int:
	
	if os.environ.get('DEBUG') :
		yf.enable_debug_mode()

	tickers = "^DJI!BK"
	if len (sys.argv) > 1 :
		tickers = sys.argv[1]

	symbols = tickers.split("!")
	tickers = yf.Tickers(symbols)

	# with open(path_to_file + 'quotes.qif', 'w') as qif,\
	#     open(path_to_file + 'quicken_quotes.csv', 'w') as quicken,\
	#     open(path_to_file + 'gnucash_quotes.csv', 'w') as gnucash :

	for ticker in tickers.tickers :
		success = 0

		stream_out ("ticker", ticker)
		stream_out ("isin", tickers.tickers[ticker].isin)
		
		info = tickers.tickers[ticker].info
		for key,value in sorted(info.items()) :
			stream_out (key, value)

		fast_info = tickers.tickers[ticker].fast_info
		for key,value in sorted(fast_info.items()) :
			stream_out (key, value)
			# if "lastprice" in key.lower():
			# 	stream_out ("last", round(value, 9))
			# 	stream_out ("date", today)
			# 	success = 1
			# if "lastvolume" in key.lower():
			# 	stream_out ("volume", round(value, 9))
			# 	stream_out ("date", today)

		hist = tickers.tickers[ticker].history(period='1mo', auto_adjust=True)

		for ts in hist.index : # hist.index gives date timestamps
			date = pd.Timestamp(ts)
			stream_out ('isodate', ts)
			stream_out ('date', date.strftime('%m/%d/%Y'))
			for pricing in hist.columns : # hist.columns give us column names such as high, low, etc
				attrib = pricing.lower()
				stream_out (attrib, round(hist[pricing][ts], 9))
				if "close" in attrib:
					success = 1
					if "MUTUALFUND" in fast_info['quoteType'] :
						stream_out ("nav", round(hist[pricing][ts], 9))
					else : 
						stream_out ("last", round(hist[pricing][ts], 9))

			# quicken.write("{},{},---,{},---,{},{},{},*\n".format (ticker.replace("^", "INDEX:"), close, date, high, low, volume))
			# gnucash.write("\"{}\",\"{}\",\"{}\",{},\"{}\"\n".format (exchange, ticker, date, close, "USD"))
			# qif.write("!Type:Prices\n\"{}\",{},\"{}\"\n^\n".format(ticker.replace("^", "INDEX:"), close, date))

		if ticker in shared._ERRORS :
			stream_out ("error", shared._ERRORS[ticker])

		stream_out ("success", success)
			
	return 0

if __name__ == '__main__' :
	sys.exit(main())
