/*
 * Logger
 */
const log4js = require('log4js');
log4js.configure('./conf/log4js.json');
const logger = log4js.getLogger('middleware');

let checkBaseUrl = (req, res, next) => {
    // let baseUrl = req.headers.baseUrl;

    // if (!baseUrl) {
        // TODO surement delete !
        // fs.readFile('./conf/docker-ip', 'utf8', function (err, data) {
        //     if (err) {
        //         return next(err);
        //     }
        //     req.headers.baseUrl = 'http://' + data.trim() + ':8080';
        //     console.log('middleware set baseUrl : ' + req.headers.baseUrl);
        req.headers.baseUrl = 'http://localhost:8080';
            return next();
        // });
    // }
    // console.log('baseUrl already fetched : ' + baseUrl);
    // return next();
};

module.exports = {checkBaseUrl: checkBaseUrl};