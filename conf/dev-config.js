const conf = {
	http: {
		port: 8080
	},
		
	signalCli: {
		command: 'docker',
		args: ['run', 'signal-web', '-v']
	}
};

module.exports = conf;
