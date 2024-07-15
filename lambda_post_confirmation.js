'use strict'
const { SecretsManager } = require('@aws-sdk/client-secrets-manager');
const secretsmanager = new SecretsManager({
    region: process.env.AWS_DEFAULT_REGION
});
const https = require('https');
const qs = require('querystring');

async function callApi(method, path, parameters, data, apiContext) {
    let credentials = apiContext.credentials;
    const qsString = qs.stringify({
        'api-user': credentials.username,
        'api-key': credentials.key
    });

    let options = {
        ...apiContext.options,
        method,
        path: `/${apiContext.options.path}/${path}?${qsString}${parameters ? `&${parameters}` : ''}`
    };
    console.log(method + ' ' + path + (parameters ? '?' + parameters : ''), data);
    return new Promise((resolve, reject) => {
        const req = https.request(options, res => {
            let body = '';
            res.setEncoding('utf8');
            res.on('data', chunk => body += chunk.toString());
            res.on('error', reject);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode <= 299) {
                    resolve(res.headers['content-type'] === 'application/json' ? JSON.parse(body) : body);
                } else if (res.statusCode === 404) {
                    resolve(null);
                } else {
                    reject('Request failed. status: ' + res.statusCode + ', body: ' + body);
                }
            });
        });
        req.on('error', reject);
        if (typeof data === 'string') {
            req.write(data);
        } else if (typeof data === 'undefined' || data === null) {
            req.write('');
        } else {
            req.write(JSON.stringify(data));
        }
        req.end();
    });
}
exports.handler = async (event, context) => {
    console.log(JSON.stringify(event));
    console.log(JSON.stringify(context));

    let endpoint = process.env.API_ENDPOINT.replace(/\/$/, '');
    let secretArn = process.env.SECRET_ARN;
    let grantRole = process.env.GRANT_ROLE;
    let createProject = process.env.CREATE_PROJECT == 'true';
    let createSubscriptions = JSON.parse(process.env.CREATE_SUBSCRIPTION || '[]');
    let username = event.userName;

    // Get API key from secret
    const secretHolder = await secretsmanager.getSecretValue({
        SecretId: secretArn
    });
    let credentials = JSON.parse(secretHolder.SecretString);
    console.log("secretData", credentials);
    let apiOptions = {
        host: endpoint.split("//")[1].split("/")[0],
        path: endpoint.split("//")[1].split("/").slice(1).join("/"),
        headers: {
            'content-type': 'application/json'
        },
    };
    let apiContext = {
        credentials: credentials,
        options: apiOptions
    };

    try {
        await completeData(apiContext, username, event.request.userAttributes.email, grantRole, createProject, createSubscriptions);
    } catch (e) {
        console.log('Application welcome creation failed', e);
    }

    return event;
};

async function getRoleByName(apiContext, role) {
    let userRoles = await callApi('GET', `system/security/role`, null, null, apiContext);
    return userRoles.data.filter(r => r.name === role).map(r => r.id);
}
async function completeData(apiContext, username, email, grantRole, createProject, createSubscriptions) {
    let userRoles = await callApi('GET', `system/user/roles`, `filters=${encodeURIComponent(JSON.stringify({ rules: [{ op: 'eq', field: 'login', data: username }] }))}`, null, apiContext);
    console.log("userRoles", userRoles);
    if (userRoles?.data?.length) {
        // User exists
        console.log("User already exists, add missing roles as needed");
        if (grantRole && userRoles.data[0].roles.filter(r => r === grantRole).length === 0) {
            // Add this role
            console.log("Role need to  be added");
            let userUpdate = await callApi('PUT', `system/user`, null, { login: username, roles: [...userRoles.data[0].roles.map(r => r.id), ...await getRoleByName(apiContext, grantRole)] }, apiContext);
            console.log("User update", userUpdate);
        } else {
            console.log("No additional role is needed");
        }
    } else {
        // Create user
        let userCreate = await callApi('POST', `system/user`, null, { login: username, roles: grantRole ? [...await getRoleByName(apiContext, grantRole)] : [] }, apiContext);
        console.log("User created", userCreate);
    }

    if (createProject) {
        // Create the projet owned by this user
        let projectKey = `welcome-${username}`;
        let project = await callApi('GET', `project/${projectKey}`, null, null, apiContext);
        let projectId = 0;
        console.log("Existing project", project);
        if (project === null) {
            // Project does not exist yet, create it
            let projectName = `Welcome ${email}`;
            projectId = await callApi('POST', `project`, null, { pkey: projectKey, name: projectName, teamLeader: username, description: `Personal project of ${username}` }, apiContext);
            console.log("Project created", projectId);
        } else {
            projectId = project.id;
        }

        // Create subscription as needed
        let subscriptions = createSubscriptions.filter(s1 => project === null || project.subscriptions.filter(s0 => s0.node.id === s1.node).length === 0);
        for (let s of subscriptions) {
            console.log("Subscription create ...", s);
            let subscriptionId = await callApi('POST', `subscription`, null, { mode: 'create', ...s, project: projectId, node: s.node, parameters: s.parameters || [] }, apiContext);
            console.log("Subscription created", subscriptionId);
        }
    }
}