var http = require('http'),
    httpProxy = require('http-proxy'),
    sys = require('sys'),
    geoip = require('geoip'),
    winston = require('winston');

var Country = geoip.Country;
var country = new Country('/usr/local/GeoIP.dat');

winston.add(winston.transports.File, { filename: 'solr-proxy.log' });
winston.remove(winston.transports.Console);

httpProxy.createServer(function (req, res, proxy) {
	winston.log('info', "Nueva conexion");
	var autorizada = 1;

	autorizada -= (req.headers.referer && req.headers.referer.match(/forondarena.net/))?0:1;
	autorizada -= (req.method === 'GET')?0:1;
	autorizada -= (req.url.match(/^\/solr\/select/))?0:1;

	var origenIP = req.connection.remoteAddress;

	if (origenIP) {
		// El autor recomienda la opcion sincrona.
		var objetoIP = country.lookupSync(origenIP);

		if (objetoIP) { 
			if (objetoIP.continent_code) {
				if ( (objetoIP.continent_code === 'EU') || (objetoIP.continent_code === 'NA') ) {
					winston.log ('info', "Autorizada " + origenIP + " desde: " + objetoIP.country_code);
				} else {
					winston.log('info', "No autorizada " + origenIP + " desde: " + objetoIP.country_code);
					autorizada -= 1;
				}
			} else {
				winston.log ('info', "GeoIP no ha devuelto un continent_code para " + origenIP);
				autorizada -= 1;
			}
		} else {
			winston.log('info', "GeoIP no ha devuelto un objeto para " + origenIP);
			autorizada -= 1;
		}

		if (autorizada == 1) {
			proxy.proxyRequest(req, res, {
				host: '127.0.0.1',
				port: 8983
			});
		} else {
			winston.log('info', "No se pasa al proxy " + origenIP);
			res.writeHead(404);
			res.end();
		}
	} else {
		winston.log('info', "No se sabe cual es la IP");
		res.writeHead(404);
		res.end();
	}
}).listen(10080);
