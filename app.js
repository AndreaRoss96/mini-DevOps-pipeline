const express = require('express');
const client = require('prom-client');
const app = express();
const collectDefaultMetrics = client.collectDefaultMetrics;

// Collect default metrics like CPU, memory, etc.
collectDefaultMetrics({ prefix: 'node_app_' });


// Expose the metrics endpoint
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', client.register.contentType);
    res.end(await client.register.metrics());
});

app.get('/', (req, res) => {
  res.send('Hello, World!');
});

module.exports = app;
