#!/bin/env python3

# Builtins
import time, sys, sqlite3
import datetime as dt

# Make sure we're in Python 3 (just because everything should be Python 3)
try:
    assert sys.version_info.major == 3
except:
    raise Exception('web_speed_trends must be run via Python3')

import speedtest
import queue as q

# For development, hardcoded time: run for a week, once every 60 minutes
days_run = 7
hours_run = 0
minutes_run = 0
minutes_interval = 60

# Convert everything to minutes
#(add an extra minute of buffer time because we're spending a (tiny) amount of time on initialization)
minutes_run = 24 * 60 * days_run + 60 * hours_run + minutes_run
# Calculate how many runs you'll need
# (the +1 is for the first run, which doesn't occur after a time interval)
n_runs = int(minutes_run/minutes_interval) + 1


# Calculate all the date/times at which a run should happen
now = dt.datetime.now()
interval = dt.timedelta(minutes = minutes_interval)
# Create FIFO queue to store the times
times = q.Queue(maxsize = n_runs)
q_time = now # Time iterator
i = 0 # Loop counter
while (not times.full()):
    times.put(q_time)
    q_time = q_time + interval

# Running & Waiting
next_time = times.get()
while(1):
    # If it's time to run the next test
    if(dt.datetime.now() >= next_time):
        # Run the speedtest
        s = speedtest.Speedtest()
        s.get_servers([])
        s.get_best_server()
        s.download()
        s.upload()
        s.results.share()
        results = s.results.dict()

        # Extract only the values we want.
        download = results['download']
        upload = results['upload']
        ping = results['ping']
        timestamp = results['timestamp']
        # Create a record to be inserted into our DB.
        record = (timestamp, download, upload, ping)
        # Add single quotes around each item of the record.
        record = tuple("'" + str(item) + "'" for item in record)
        print(record)
        # Open the database.
        con = sqlite3.connect('data.db')
        # Insert the new record.
        cur = con.cursor()
        cur.execute('INSERT INTO data(download, upload, ping, timestamp) VALUES (%s)' %
                    ', '.join(record))
        # Commit and close.
        con.commit()
        con.close()

        # If we've emptied the queue, end the loop
        if(times.empty()):
                break
        # If there are more times left, get the next one
        else:
                next_time = times.get()
    # Wait for a minute
    time.sleep(1)
