// const conf = require('../conf/app.js');
const config = require('config');

/*
 * Logger
 */
let log4js = require('log4js');
log4js.configure('./conf/log4js.json');
let logger = log4js.getLogger('app');

/*
 * Web
 */
const express = require('express');
const ejs = require('ejs');
const bodyParser = require('body-parser');
const request = require('request');

/*
 * Divers
 */
fs = require('fs');
const async_series = require('async').series;
const middleware = require('./middleware');

/*
 * Process
 */
const { spawn } = require("child_process");

let app = express();
//app.use(express.static('scripts')); // Serves static files. Used in ./views/*.ejs files to include ./scripts/*.js
app.use(bodyParser.urlencoded({extended: true}));
//app.use(express.static('public'));
//app.use(express.json()); // Parse json object and put them in the request.body : https://stackoverflow.com/questions/10005939/how-do-i-consume-the-json-post-data-in-an-express-application
app.set('view engine', 'ejs');

app.get('/', function (req, res, next) {
    return res.render('pages/index', {});
});

// app.get('/test', /*middleware.checkToken, */function (req, res, next) {
// //	return res.status(200).json({"ok":"kk"});
//     let list = ["Louise", "Sadie", "Erik", "Raph", "Gina"];
//     return res.render('pages/index', {name: 'Pumbaa666', listnames: list});
// });

/*
app.post('/register', middleware.checkBaseUrl, function (req, res, next) {
    let phoneNumber = req.body.phoneNumber;
    if (!phoneNumber)
        return next({error: 'Missing phone number'});
    // TODO check phoneNumber validity

    let url = req.headers.baseUrl + '/v1/register/' + phoneNumber;
    console.debug('Sending sms to ' + url)

    request.post({
        headers: {'content-type': 'application/json'},
        url: url,
    }, function (error, response, body) {
        if (error) {
            return next(error);
        }

        let bodyObject = JSON.parse(body);
        if (bodyObject && bodyObject.error) {
            return next(bodyObject);
        }

        return res.render('pages/register', {phoneNumber: phoneNumber});
    });
});

app.post('/verify', middleware.checkBaseUrl, function (req, res, next) {
    let phoneNumber = req.body.phoneNumber;
    if (!phoneNumber)
        return next({error: 'Missing phone number'});

    let code = req.body.registerCode;
    if (!code)
        return next({error: 'Missing code'});

    let url = req.headers.baseUrl + '/v1/register/' + phoneNumber + '/verify/' + code;
    console.debug('verifying ' + url)

    request.post({
        headers: {'content-type': 'application/json'},
        url: url,
    }, function (error, response, body) {
        if (error) {
            return next(error);
        }

        let bodyObject = JSON.parse(body);
        if (bodyObject && bodyObject.error) {
            return next(bodyObject);
        }

        return res.render('pages/index', {message: "Vous êtes vérifié"});
    });
});

app.get('/test', function (req, res, next) {
    fs.readFile('./conf/docker-ip', 'utf8', function (err, data) {
        if (err) {
            return console.log(err);
        }
        console.log(data);
    });
});
*/

function spawnSignalCli(args) {
    const command = config.get('signalCli.command');
    const signalcliArgs = config.get('signalCli.args');
    args = signalcliArgs.concat(args);
    logger.debug("spawning : " + command + " / " + args);
    return spawn(command, args);
}

app.get('/link', middleware.checkBaseUrl, function (req, res, next) {
    let deviceName = req.query.deviceName; // TODO check not null
    const signalCli = spawnSignalCli("link");

    signalCli.stdout.on("data", data => {
        
        logger.debug(data);
        // let version = `${data}`.trim();
        // if(!version.includes("signal-cli")) {
        //     return res.status(400).send("Can't find version in "); // TODO next
        // }
        return res.status(200).json({"stdout":data});
    });

    signalCli.stderr.on("data", data => {
        logger.error(`api stderr: ${data}`);
        return next(data);
    });

    signalCli.on('error', (error) => {
        logger.error(`api error: ${error.message}`);
        return next(error);
    });

    signalCli.on("close", code => {
        logger.debug(`api child process exited with code ${code}`);
    });
});


app.get('/version', middleware.checkBaseUrl, function (req, res, next) {
    // const confPath="/home/.local/share/signal-cli"
    const signalCli = spawnSignalCli("-v");

    signalCli.stdout.on("data", data => {
        let version = `${data}`.trim();
        if(!version.includes("signal-cli")) {
            return res.status(400).send("Can't find version in "); // TODO next
        }
        return res.status(200).json({"version":version});
    });

    signalCli.stderr.on("data", data => {
        logger.error(`api stderr: ${data}`);
        return next(data);
    });

    signalCli.on('error', (error) => {
        logger.error(`api error: ${error.message}`);
        return next(error);
    });

    signalCli.on("close", code => {
        logger.debug(`api child process exited with code ${code}`);
    });
});

app.post('/send', middleware.checkBaseUrl, function (req, res, next) {
    let senderNumber = req.body.senderNumber; // TODO check
    let recipientNumber = req.body.recipientNumber;
    let message = req.body.message;
    // console.log(senderNumber);
    // console.log(recipientNumber);
    // console.log(message);

    let url = req.headers.baseUrl + '/v2/send';
    let data = {
        message: message,
        number: senderNumber,
        recipients: [recipientNumber]
    };

    console.debug('sending message on ' + url + ' : ' + JSON.stringify(data));
    // request(url, {json: true}, (err, res2, body) => {
    let messageSent = '';
    //
    //     res.setHeader('Content-Type', 'application/json');
    //     return res.render('pages/index', {messageSent: messageSent});
    // });
    request.post({
        headers: {'content-type': 'application/json'},
        url: url,
        body: JSON.stringify(data)
    }, function (error, response, body) {
        if (error) {
            return next(error);
        }

        let bodyObject = JSON.parse(body);
        if (bodyObject && bodyObject.error) {
            return next(bodyObject);
        }

        let sent = JSON.parse(response.request.body); // TODO check
        return res.render('pages/index', {message: "Message envoyé à " + sent.recipients + " : \"" + sent.message + "\" "});
    });
});

app.get('/receive', middleware.checkBaseUrl, function (req, res, next) {
    // TODO
    return res.render('pages/index', {messages: "TODO"});
});


function page404(req, res) {
    res.setHeader('Content-Type', 'application/json');
    res.status(404).send({error: 'Unknown page !'});
}

app.use(page404);

function errorHandler(error, req, res, next) {
    logger.error(error);
    res.setHeader('Content-Type', 'application/json');
    res.status(400).send(error);
}

app.use(errorHandler);

async_series([
    (done) => {
//		logger.info('Connecting to Database : ' + mongoDbUrl);
//		mongoose.connect(mongoDbUrl, { useNewUrlParser: true, useCreateIndex: true }); // useCreateIndex : https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&ved=2ahUKEwj01KKn4M_hAhUCKewKHZu3C_EQFjAAegQIBBAB&url=https%3A%2F%2Fgithub.com%2FAutomattic%2Fmongoose%2Fissues%2F6890&usg=AOvVaw1LQ5-k1g-Sr9xz0RQKIKlE
        done();
    },
    (done) => {
        logger.info('Listening on port ' + config.get('http.port'));
        app.listen(config.get('http.port'));
        done();
    }
]);
module.exports = app; // for testing
