const express = require('express');
const _ = require('lodash');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.get('/', (_req, res) => res.json({ id: uuidv4(), msg: _.capitalize('hello sbom') }));
if (require.main === module) app.listen(3000, () => console.log('listening on :3000'));
module.exports = app;
