# EXTRA

This directory contains example use of GenericExecutor module that calls 
a Python script. 

Python script utilizes yfinance to fetch and then pandas library for date 
conversion, thus they will need to be installed in Python.

In order for GNUCash to use the module, two required environment variables 
named `GENERIC_EXECUTOR` and `GENERIC_FETCHER` will need to be set. 
`GENERIC_EXECUTOR` set to your favorite interpreter (for enclosed script 
it will simply be 'python') and for `GENERIC_FETCHER` it will be a script
name. Either or both can be relative if they are located in OS's search 
path, or full path that includes the runnable as part of that path.

