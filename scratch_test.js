// scratch_test.js
const http = require('http');

const WAHA_URL = 'http://localhost:3000/api/sendText';

const payload = JSON.stringify({
  chatId: '6281321076699@c.us',
  text: 'Test tanpa API Key'
});

const url = new URL(WAHA_URL);
const options = {
  hostname: url.hostname,
  port: url.port || 80,
  path: url.pathname,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload)
  }
};

const req = http.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log('STATUS:', res.statusCode);
    console.log('BODY:', data);
  });
});

req.on('error', (err) => {
  console.error('ERROR:', err);
});

req.write(payload);
req.end();
