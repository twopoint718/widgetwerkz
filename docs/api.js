const express = require('express');
const swaggerUI = require('swagger-ui-express');
const http = require('http');
const fs = require('fs');

const app = express();
var request = http.get('http://widgetwerkz.development', (resp) => {
    var rawDoc = '';

    resp.on('data', (chunk) => { rawDoc += chunk; });
    resp.on('end', () => {
        try {
            const doc = JSON.parse(rawDoc);
            console.log('Read current schema');
            app.use('/docs', swaggerUI.serve, swaggerUI.setup(doc));
            app.listen(4000, () => console.log('Docs on http://widgetwerkz.development/docs'));
        } catch (e) {
            console.error('Failed reading schema: ' + e.message);
        }
    });       
}).on('error', (e) => console.error(`Got HTTP error: ${e.message}`));

