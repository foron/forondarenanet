var net = require('net');
var sys = require("sys");

var ws = require("websocket-server");
var redis = require("redis");

var puertoredis = 6379;
var hostredis = 'localhost';

var server = ws.createServer({debug: true});

var client = redis.createClient(puertoredis,hostredis);
var conexion;

var mensaje;

client.on("error", function (err) {
	sys.log("Redis  error en la conexion a: " + client.host + " en el puerto: " + client.port + " - " + err);
});


server.addListener("connection", function(conn){
	var graficomostrado = "";
	var servidores = [];

	sys.log("Conexion abierta: " + conn.id);

	client.hkeys("datos", function (err, replies) {
		replies.forEach(function (reply, i) {
			sys.log("Respuesta: " + reply);
			servidores.push(reply);
		});
		graficomostrado = servidores[0];
		mensaje = {"titulo": graficomostrado, "todos": servidores};
		conn.send(JSON.stringify(mensaje));
	});

	conn.addListener("message", function(message){
		var dato = JSON.parse(message);
		if (dato) {
			if (dato.orden == "changeGraphic") {
				graficomostrado = dato.grafico;
				conn.send(JSON.stringify({changedGraphic: graficomostrado}));
				client.hget("datos", graficomostrado, function (err, reply) {
					mensaje = {"inicio":[(new Date()).getTime(), reply]};
					conn.send(JSON.stringify(mensaje));
				});
			} else if (dato.orden == "getData") {
				client.hget("datos", graficomostrado, function (err, reply) {
					mensaje = {"actualizacion":[(new Date()).getTime(), reply]};
					conn.send(JSON.stringify(mensaje));
				});
			}
		}
	});
});

server.addListener("error", function(){
	sys.log("Error de algun tipo en la conexion");
});

server.addListener("disconnected", function(conn){
	sys.log("Desconectada la sesion " + conn.id);
});


server.listen(80);
