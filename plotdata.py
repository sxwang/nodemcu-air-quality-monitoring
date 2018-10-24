#!/usr/local/bin/python3

# Run this file as a crontab to get data from thingspeak to plot.ly.

import pandas as pd
import datetime as dt
import requests, json

import plotly.plotly as py
import plotly.graph_objs as go
import plotly.tools as pytools

THINGSPEAK_CHANNEL_ID = 599471

# Get data from thingspeak; limit is 8000 results per call.
r = requests.get('https://api.thingspeak.com/channels/' + str(THINGSPEAK_CHANNEL_ID) +
                 '/feeds.json?results=10000&timezone=America%2FLos_Angeles')

df = pd.read_json(json.dumps(r.json()['feeds']))
# convert original timezone to utc, then again to offset Plotly's timezone issue
df.loc[:, 'time'] = df['created_at'] - dt.timedelta(hours=7*2)
df.rename(columns={k:r.json()['channel'][k] for k in ['field'+str(i) for i in range(1, 8)]}, inplace=True)

# temperature/humidity/eTVOC plot
t1 = go.Scatter(x = df['time'], y = df['temp(C)'], name = 'temp(C)')
t2 = go.Scatter(x = df['time'], y = df['hum(%)'], name = 'hum(%)')
t3 = go.Scatter(x = df['time'], y = df['eTVOC(ppb)'], name = 'eTVOC(ppb)')
fig = pytools.make_subplots(
    rows=3, cols=1, specs=[[{}], [{}], [{}]],
    shared_xaxes=True, shared_yaxes=True,
    vertical_spacing=0.001, print_grid=False)
fig.append_trace(t1, 1, 1)
fig.append_trace(t2, 2, 1)
fig.append_trace(t3, 3, 1)

fig['layout'].update(height=600, width=1000, title='Temperature, Humidity, eTVOC')
py.plot(fig, filename='temp_hum_tvoc', auto_open=False)

# eTVOC, raw I/V, baseline plot
t4 = go.Scatter(x = df['time'], y = df['rawI(uA)'], name = 'rawI(uA)')
t5 = go.Scatter(x = df['time'], y = df['rawV'], name = 'rawV')
t6 = go.Scatter(x = df['time'], y = df['baseline'], name = 'baseline')
fig = pytools.make_subplots(
    rows=4, cols=1, specs=[[{}], [{}], [{}], [{}]],
    shared_xaxes=True, shared_yaxes=True,
    vertical_spacing=0.001, print_grid=False)
fig.append_trace(t3, 1, 1)
fig.append_trace(t4, 2, 1)
fig.append_trace(t5, 3, 1)
fig.append_trace(t6, 4, 1)

fig['layout'].update(height=800, width=1000, title='eTVOC, rawI, rawV, baseline')
py.plot(fig, filename='tvoc_raw_baseline', auto_open=False)

print("Last updated:", dt.datetime.now())