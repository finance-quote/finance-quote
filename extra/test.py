import pandas as pd
import yfinance as yf
from datetime import timedelta, datetime

# stock_list = pd.read_csv("ind_nifty500list.csv")
# stock_list = stock_list["Symbol"].to_list()
stock_list = ["3MINDIA", "ABB", "POWERINDIA"]

stock_list = [i+".NS" for i in stock_list]
#Adding .NS to represent national stock

delta = timedelta(days=-300)# I need 300 days history data
today = datetime.now()

data = yf.download(stock_list, today+delta)

print (data)

#Modifying the dataframe index so that we can eaisly extract the data in seprate file.
data.columns = pd.MultiIndex.from_tuples([i[::-1] for i in data.columns])

save_location = "stock_data"

for i in stock_list:
    try:
        TEMP = data[i].copy(deep=True)
        TEMP = TEMP.dropna()
        TEMP.to_csv(save_location+"/"+i+".csv")
    except:
        print("Unaable to load data for {}".format(i))