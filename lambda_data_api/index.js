'use strict'
const mysql = require('mysql2/promise');
const AWS = require('aws-sdk');
const REGION = process.env.REGION;
const LOG_LEVEL = process.env.LOG_LEVEL || 'DEBUG'; // DEBUG, INFO, WARN
const DB_HOST = process.env.DB_HOST;
const DB_DATABASE = process.env.DB_DATABASE;

async function run(database, query, secret, params) {
    const conn = await mysql.createConnection({
        database: typeof database === 'undefined' ? DB_DATABASE : database,
        host: DB_HOST,
        user: secret.username,
        password: secret.password,
    });
    return await conn.execute(query, params);
}

exports.handler = async (event, context) => {
    console.log(`event`, JSON.stringify(event));
    console.log(`context`, JSON.stringify(context));
    context.callbackWaitsForEmptyEventLoop = false;
    const query = Buffer.from(event.query, 'base64').toString('utf-8');
    const secret = JSON.parse(Buffer.from(event.secret, 'base64'));
    console.log(`query`, query);
    let result = await run(event.database, query, secret, event.params && Buffer.from(event.params, 'base64'));
    result = result && result[0] || result;
    console.log(`result`, result);
    if (result && result.affectedRows) {
        return result
    }
    return result && {
        records: result,
    } || {};
};